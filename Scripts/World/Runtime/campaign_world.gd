extends "res://Scripts/World/Navigation/connected_world.gd"
## The staged campaign binds its directly owned districts to the shared world services.
const DISTRICT = preload("res://Scripts/World/Runtime/authored_district.gd")
const GEOMETRY_MODELS := [
	preload("res://Scripts/World/Zone1/zone1_geometry.gd"),
	preload("res://Scripts/World/Zone2/zone2_geometry.gd"),
	preload("res://Scripts/World/Zone3/zone3_geometry.gd")
]
const GROUND = preload("res://Scripts/World/cube_ground_art.gd")
const PROVIDERS := {
	"Z1L1":["melting_garden_world","bind_garden"],
	"Z1L2":["frozen_mill_world","bind_mill"],
	"Z1L3":["stillwater_world","bind_crossing"],
	"Z1L4":["canal_world","bind_canal"],
	"Z1L5":["workshop_world","bind_workshop"],
	"Z1L6":["frozen_dock_world","bind_dock"],
	"Z2L1":["sunlit_landing_world","bind_sunlit"],
	"Z2L2":["drying_orchard_world","bind_orchard"],
	"Z2L3":["dewglass_world","bind_dewglass"],
	"Z2L4":["returning_stream_world","bind_stream"],
	"Z2L5":["steamworks_garden_world","bind_steamworks"],
	"Z2L6":["skybridge_engine_world","bind_skybridge"],
	"Z3L1":["vanishing_ice_lab_world","bind_vanishing_lab"],
	"Z3L2":["sample_sorting_world","bind_sorting_room"],
	"Z3L3":["frostprint_world","bind_frostprint"],
	"Z3L4":["reversible_frost_world","bind_reversible_frost"],
	"Z3L5":["observatory_world","bind_observatory"],
	"Z3L6":["phaseworks_core_world","bind_core"]
}
const REGION_MARGIN := 1200.0
var entry_authorized := false
var district_bounds: Dictionary = {}
var nearby_districts: Dictionary = {}
var last_activation_position := Vector2(INF, INF)
var draw_terrain := true

func _ready() -> void:
	draw_terrain = DisplayServer.get_name() != "headless"
	initialize_common_world()
	if get_node("/root/PlayerSave").world_entry_request.is_empty():
		_entry_unavailable.call_deferred()

func _apply_menu_entry() -> void:
	var profile := get_node("/root/PlayerSave")
	var resume := take_menu_entry()
	var id := str(resume.get("subregion", ""))
	if demonstration_mode or development_preview or not REGISTRY.can_enter_campaign(profile, id):
		_entry_unavailable()
		return
	restoration_pending = true
	_composing = true
	var continuing: bool = resume.continue_campaign
	if continuing:profile.begin_campaign_continue(resume)
	if not _bind_authored_map(profile):
		if continuing:profile.finish_campaign_continue(false)
		_entry_unavailable()
		return
	sync_permissions()
	# Location authority is available only once the real title request has been consumed.
	entry_authorized = true
	var restored := restore_saved_world(access, not continuing, id if continuing else "")
	if continuing:profile.finish_campaign_continue(restored)
	if not restored:
		entry_authorized = false
		_entry_unavailable()
		return
	discovery = DISCOVERY.new()
	discovery.bind_profile(profile)
	map_provider = MAP.new()
	map_provider.name = "AtmosphericFog"
	add_child(map_provider)
	map_provider.bind(self)
	profile.changed.connect(sync_permissions)
	profile.restored.connect(sync_permissions)
	_composing = false
	_update_discovery()
	input_adapter.refresh()

func _bind_authored_map(profile: Node) -> bool:
	var polygons := {}
	for index in GEOMETRY_MODELS.size():
		var model: RefCounted = GEOMETRY_MODELS[index].new()
		model.data = {"regions":[],"stations":[],"equipment":[],"exploration_stops":[],
			"sources":[],"trails":[],"local_branches":[],"review_routes":[],"chambers":[]}
		models.append(model)
		var zone := get_node("GroundSort/Zone%d" % (index+1))
		professors.append(zone.get_node("SharedProfessorZ%d" % (index+1)))
	for id in REGISTRY.CAMPAIGN_DISTRICTS:
		var district := get_node_or_null(REGISTRY.CAMPAIGN_DISTRICTS[id])
		if not district is DISTRICT or district.owner != self or district.subregion_id != id or not district.frame_valid():
			last_error = "Missing authored district " + id
			return false
		var model: RefCounted = models[int(id.substr(1,1))-1]
		district.append_geometry(model)
		var polygon: PackedVector2Array = district.permission_polygon()
		polygons[id] = polygon
		district_bounds[id] = model.box_of(polygon)
		chunks[district.chunk_id] = district
		var live_art := Node2D.new()
		live_art.name = "LiveArt"
		live_art.y_sort_enabled = true
		live_art.position = -district.ground_origin
		district.add_child(live_art)
		source_bodies.merge(district.source_bodies)
		gate_bodies.append_array(district.gate_bodies)
		permissions[id] = district.permission_bodies
		props.append_array(district.get_node("Scenery").get_children())
	access = ACCESS.new()
	access.bind(profile, false, polygons)
	geometry = GEOMETRY.new()
	geometry.bind(models, access)
	for index in models.size():
		DISTRICT.prepare_terrain(models[index])
		_load_zone_kit(index)
	_bind_ground()
	_read_connections()
	for district in chunks.values():
		for room in district.get_children().filter(func(child):return child.has_meta("room")):
			room.bind_authored()
			room_cutaway.add_room(room)
			for polygon in room.walls:geometry.room_solids.append({"owner":room,"polygon":polygon})
		_bind_chunk_travel(district)
		_mount_learning_provider(district)
		if not is_instance_valid(district.runtime_provider):
			last_error = "Cannot bind authored provider " + district.subregion_id
			return false
	return true

func district_art_parent(district: Node) -> Node2D:
	return district.get_node("LiveArt")

func _load_zone_kit(index: int) -> void:
	var number := index+1
	var base := "res://assets/zones/zone_%d/world_v1/" % number
	kits.append(load(base+"kit_atlas.tres"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+"kit_catalog.json"))
	var entries := {}
	for entry in catalog.entries:
		if not entries.has(entry.group): entries[entry.group] = entry
		entries[entry.id] = entry
	catalogs.append(entries)

## One painter draws all three zones, so their borders blend and nearer ground covers farther ground.
func _bind_ground() -> void:
	var ground: Node2D = GROUND.new()
	ground.name = "Terrain"
	add_child(ground)
	if draw_terrain:
		ground.configure_all(models,GROUND.BIOMES,models.map(func(model):return model.data.review_routes))
		ground.follow_effects(get_node("/root/PlayerSave"))
	art_layers.append(ground)

func _read_connections() -> void:
	for line in $Connections.get_children():
		var record: Dictionary = line.get_meta("connection").duplicate()
		var path: PackedVector2Array = line.global_transform*line.points
		var start: Vector2 = line.get_node("Source").global_position
		var destination: Vector2 = line.get_node("Destination").global_position
		path[0] = start
		path[-1] = destination
		record.source_anchor = DISTRICT.coordinates(start)
		record.destination_anchor = DISTRICT.coordinates(destination)
		record.polyline = DISTRICT.points(path)
		connections.append(record)

func _learning_provider_spec(id: String) -> Array:
	var spec: Array = PROVIDERS.get(id, [])
	return [] if spec.is_empty() else ["res://Scripts/World/Zone%s/%s.gd" % [id.substr(1,1),spec[0]],spec[1]]

func _zone1_provider_spec(id: String) -> Array:
	return PROVIDERS.get(id, []) if id.begins_with("Z1") else []

func _skybridge_enabled() -> bool:
	return entry_authorized

func writes_navigation() -> bool:
	return entry_authorized and not development_preview and not demonstration_mode

func registered_district(id: String) -> bool:
	return REGISTRY.can_enter_campaign(get_node("/root/PlayerSave"), id)

func mount_chunk(_chunk: Node2D) -> bool:
	return false

func unmount_chunk(_id: String) -> bool:
	return false

func checkpoint_anchor(id: String, checkpoint: String) -> Vector2:
	var path: NodePath = REGISTRY.CAMPAIGN_DISTRICTS.get(id, NodePath())
	if path.is_empty():return super.checkpoint_anchor(id, checkpoint)
	var marker := get_node_or_null(str(path) + "/Layout/Checkpoints/" + checkpoint) as Marker2D
	return marker.global_position if marker else Vector2(INF, INF)

func _physics_process(delta: float) -> void:
	if entry_authorized and not restoration_pending:
		if player.position.distance_to(last_activation_position) >= 80.0:
			_update_nearby(player.position)
		super._physics_process(delta)

func activate(id: String, at: Vector2) -> bool:
	if not access.allowed(id):return false
	_update_nearby(at)
	if super.activate(id, at):return true
	_update_nearby(player.position)
	return false

func _update_nearby(at: Vector2) -> void:
	last_activation_position=at
	for id in district_bounds:
		var nearby: bool = district_bounds[id].grow(REGION_MARGIN).has_point(at)
		if nearby_districts.get(id) == nearby:continue
		nearby_districts[id] = nearby
		chunks[id+".shell"].set_nearby(nearby)
	for index in art_layers.size():
		art_layers[index].visible = draw_terrain

func save_and_menu() -> bool:
	if not get_node("/root/PlayerSave").world_navigation_source(self, active_subregion_id):return false
	if discovery and not discovery.save_ledger():
		input_adapter.feedback = "Map discovery could not be saved. Stay here and try again."
		input_adapter.refresh()
		return false
	return super.save_and_menu()
