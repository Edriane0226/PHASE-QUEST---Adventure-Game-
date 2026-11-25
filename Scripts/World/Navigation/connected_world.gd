extends "res://Scripts/World/Runtime/phase_world.gd"
## One retained actor/HUD across all18 shells. Normal campaign readiness is deliberately unchanged.
const ACCESS=preload("res://Scripts/World/Navigation/world_access.gd")
const GEOMETRY=preload("res://Scripts/World/Navigation/world_geometry.gd")
const DISCOVERY=preload("res://Scripts/World/Navigation/world_discovery.gd")
const MAP=preload("res://Scripts/World/Navigation/world_map.gd")
const TRAVEL=preload("res://Scripts/World/Navigation/travel_provider.gd")
const DOCK=preload("res://Scripts/World/Zone1/frozen_dock_world.gd")
const SKYBRIDGE=preload("res://Scripts/World/Zone2/skybridge_engine_world.gd")
const OPTIONAL_ACTIVITY=preload("res://Scripts/World/Learning/optional_activity.gd")
const ZONE1_PROVIDERS := {
	"Z1L1":["melting_garden_world","bind_garden"],
	"Z1L2":["frozen_mill_world","bind_mill"],
	"Z1L3":["stillwater_world","bind_crossing"],
	"Z1L4":["canal_world","bind_canal"],
	"Z1L5":["workshop_world","bind_workshop"],
}
const CONNECTIONS="res://World/Data/world-connections.json"
var access: RefCounted
var geometry: RefCounted
var discovery: RefCounted
var map_provider: Node2D
var models: Array=[]
var art_layers: Array=[]
var professors: Array=[]
var props: Array=[]
var permissions: Dictionary={}
var source_bodies: Dictionary={}
var gate_bodies: Array=[]
var portal_art: Array=[]
var kits: Array=[]
var catalogs: Array=[]
var connections: Array=[]
var all_bodies: Array=[]
var last_ground:=Vector2.ZERO
var _discovery_clock:=0.0
var _save_clock:=0.0
var _transit: Dictionary={}
var _composing:=false
var _carry_region:=""
func _ready() -> void:
	development_preview=true;initialize_common_world()
	var profile:=get_node("/root/PlayerSave")
	if not fixture_session() or not profile.get_meta("r3_019_permissions",false):
		input_adapter.feedback="Connected geography awaits campaign integration.";input_adapter.refresh();return
	_composing=true
	access=ACCESS.new();access.bind(profile,true)
	connections=JSON.parse_string(FileAccess.get_file_as_string(CONNECTIONS)).connections
	for number in range(1,4):
		var model=load("res://Scripts/World/Zone%d/zone%d_geometry.gd"%[number,number]).new()
		if not model.load_data():last_error="Missing owned terrain.";return
		model.prefix=6;models.append(model)
	geometry=GEOMETRY.new();geometry.bind(models,access)
	for number in range(1,4):_compose_zone(number)
	if FileAccess.file_exists("res://World/Data/navigation-routes.json"):
		var routes=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"));var matching:=routes is Dictionary
		if matching:
			for n in range(1,4):
				if routes.source_hashes.get("zone%d-shells.json"%n)!=FileAccess.get_sha256("res://World/Data/zone%d-shells.json"%n):matching=false
		if matching:
			for n in range(1,4):art_layers[n-1].routes=routes.routes.filter(func(r):return r.id.begins_with("Z%d"%n));art_layers[n-1].queue_redraw()
	_build_boundaries();_build_rooms();_bind_travel()
	discovery=DISCOVERY.new()
	discovery.bind_profile(profile)
	sync_permissions()
	for chunk in chunks.values():
		_mount_learning_provider(chunk)
	if profile.get_meta("r3_030_zone1",false) or profile.get_meta("r3_031_sunlit",false):sync_permissions()
	map_provider=MAP.new();map_provider.name="AtmosphericFog";add_child(map_provider);map_provider.bind(self)
	profile.changed.connect(sync_permissions);profile.restored.connect(sync_permissions)
	_composing=false
	activate("Z1L1",Vector2(REGISTRY.definition("Z1L1").entry[0],REGISTRY.definition("Z1L1").entry[1]))
	if profile.get_meta("r3_020_restore",false):restore_saved_world(access)
	_update_discovery();input_adapter.refresh()
func initialize_common_world() -> void:
	super._ready()
	process_physics_priority=-100
func _compose_zone(number: int) -> void:
	var model: RefCounted=models[number-1]
	for level_number in range(1,7):
		var chunk=load("res://World/Zone%d/Z%dL%dShell.tscn"%[number,number,level_number]).instantiate();chunk.configure_geometry(model)
		if not mount_chunk(chunk):last_error="Cannot mount "+chunk.subregion_id;chunk.free();return
		chunk.tutorial="";chunk.quests=[{"text":str(REGISTRY.definition(chunk.subregion_id).name),"state":"active"},{"text":"Terrain review · learning integration pending","state":"blocked"}]
		for body in chunk.find_children("*","StaticBody2D",true,false):
			if body.has_meta("source_path"):
				source_bodies[chunk.subregion_id+":"+str(body.get_meta("source_path"))]=body
				if body.get_meta("science_gate",false):gate_bodies.append({"region":chunk.subregion_id,"body":body,"layer":body.collision_layer,"source_path":str(body.get_meta("source_path"))})
	# Off-tree authored contributors add art, never extra actors/HUD/cameras or controller _ready.
	var contributor=load("res://Scripts/World/Zone%d/zone%d_shell_world.gd"%[number,number]).new()
	var sort:=Node2D.new();sort.name="GroundSort";sort.y_sort_enabled=true;contributor.add_child(sort);contributor.geometry=model
	var kit=load("res://assets/zones/zone_%d/world_v1/kit_atlas.tres"%number);kits.append(kit);contributor.set("_kit",kit)
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_%d/world_v1/kit_catalog.json"%number));var entries: Dictionary={}
	for e in catalog.entries:
		if not entries.has(e.group):entries[e.group]=e
		entries[e.id]=e
	contributor.set("_kit_entries",entries);contributor.build_art()
	catalogs.append(entries)
	professors.append(contributor.professor);props.append_array(contributor.props)
	for child in sort.get_children():child.reparent($GroundSort)
	contributor.free()
	var art=load("res://Scripts/World/Zone%d/zone%d_ground_art.gd"%[number,number]).new();art.name="Zone%dTerrain"%number;add_child(art);art.configure(model)
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/zone%d-routes.json"%number))
	art.routes=routes.routes;art_layers.append(art)
	for b in model.blockers:
		b["original_layer"]=b.layer
		if b.source_path=="SourcePortalSeal":
			var body:=_body(b.polygon,8,"SourcePortal");var entry:=false
			for source in model.data.sources:
				if source.subregion!=b.region:continue
				var r: Dictionary=REGISTRY.definition(b.region)
				for portal in source.portal_routes:
					var at: Vector2=model.v(portal.points[-1]).lerp(model.v(portal.points[0]),.2)
					if at.distance_to(b.bounds.get_center())<2:entry=model.v(portal.points[0]).distance_to(Vector2(r.entry[0],r.entry[1]))<1
			gate_bodies.append({"region":b.region,"body":body,"layer":8,"portal_entry":entry,"record":b})
		elif b.source_path.is_empty():
			var body := _body(b.polygon,b.layer,"LandscapeSolid")
			if b.has("station"):b.body=body
	for r in model.data.regions:
		for s in model.data.stations:
			if s.subregion==r.id and s.kind=="professor":professors[number-1].position=model.v(s.ground_xy);professors[number-1].elevation=float(model.height_record(model.v(s.ground_xy)).get("height",0));break
func _edge(a: Vector2,b: Vector2,width: float) -> PackedVector2Array:
	var n: Vector2=(b-a).normalized().orthogonal()*width
	return PackedVector2Array([a+n,b+n,b-n,a-n])
func _build_rooms() -> void:
	# Shared base owns occupancy; this shell fixture contributes existing room records.
	for chunk in chunks.values():_mount_rooms(chunk)
func _mount_rooms(chunk: Node2D) -> void:
	var path:="res://World/Data/modular-rooms.json"
	if not FileAccess.file_exists(path):return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for record in data.rooms:
		if record.subregion!=chunk.subregion_id:continue
		# Initial composition and later chunk mounting share this path. One owner per room.
		if chunk.get_node_or_null(NodePath(record.id.validate_node_name()))!=null:continue
		var room=preload("res://Scripts/World/Runtime/modular_room.gd").new();room.name=record.id.validate_node_name()
		# Chunk owns bodies/lifetime; artwork uses common world ground sorting.
		chunk.add_child(room);room.position=-chunk.ground_origin;room.configure(record,$GroundSort);room_cutaway.add_room(room)
		for polygon in room.walls:geometry.room_solids.append({"owner":room,"polygon":polygon})
		for art in props.duplicate():
			if not is_instance_valid(art):continue
			var replace: bool=str(art.name)==record.get("replaces_node","")
			if replace:
				props.erase(art);art.queue_free()
func mount_chunk(chunk: Node2D) -> bool:
	var result:=super.mount_chunk(chunk)
	if result and not _composing:
		# Rebind physical source identities after streaming, not only cold composition.
		for body in chunk.find_children("*","StaticBody2D",true,false):
			if not body.has_meta("source_path"):continue
			var path: String=str(body.get_meta("source_path"));source_bodies[chunk.subregion_id+":"+path]=body
			if not body.get_meta("science_gate",false):continue
			var found:=false
			for record in gate_bodies:
				if record.region==chunk.subregion_id and record.get("source_path")==path:record.body=body;found=true;break
			if not found:gate_bodies.append({"region":chunk.subregion_id,"body":body,"layer":body.collision_layer,"source_path":path})
		if is_instance_valid(room_cutaway):_mount_rooms(chunk)
		if not _learning_provider_spec(chunk.subregion_id).is_empty():
			_bind_chunk_travel(chunk)
			_mount_learning_provider(chunk)
	return result
func unmount_chunk(id: String) -> bool:
	var result:=super.unmount_chunk(id)
	if result:
		var region: String=id.get_slice(".",0)
		for key in source_bodies.keys():
			if str(key).begins_with(region+":"):source_bodies.erase(key)
		geometry.room_solids=geometry.room_solids.filter(func(record):return is_instance_valid(record.owner) and record.owner.is_inside_tree() and not record.owner.is_queued_for_deletion())
		refresh_room_presentation()
	return result
func _body(points: PackedVector2Array,layer: int,hint: String) -> StaticBody2D:
	var origin:=points[0];var local:=PackedVector2Array()
	for p in points:local.append(p-origin)
	if Geometry2D.triangulate_polygon(local).is_empty():return null
	var body:=StaticBody2D.new();body.name=hint;body.position=origin;body.collision_layer=layer;body.collision_mask=4
	var shape:=CollisionPolygon2D.new();shape.polygon=local;body.add_child(shape);$GroundSort.add_child(body);all_bodies.append(body);return body
func _build_boundaries() -> void:
	for r in access.rows:
		var p: PackedVector2Array=access.polygons[r.id];var bodies: Array=[]
		for i in range(p.size()):
			var a: Vector2=p[i];var b: Vector2=p[(i+1)%p.size()];bodies.append(_body(_edge(a,b,5),8,"Permission_"+r.id))
			var n: Vector2=(b-a).normalized().orthogonal()*10;var at: Vector2=(a+b)/2
			if access.region_at(at+n).is_empty() or access.region_at(at-n).is_empty():
				var edge:=_edge(a,b,3);_body(edge,1,"MainlandCoast");geometry.region_models[r.id].add_blocker(edge,r.id,1)
		permissions[r.id]=bodies
	var bridges: Array=[]
	for m in models:bridges.append_array(m.bridges)
	for values in models[0].data.water:
		var p: PackedVector2Array=models[0].polygon(values)
		for i in range(p.size()):
			var a: Vector2=p[i];var b: Vector2=p[(i+1)%p.size()];var id: String=access.region_at((a+b)/2)
			if id.is_empty():continue
			var pieces: Array=[_edge(a,b,2)]
			for bridge in bridges:
				var next: Array=[]
				for piece in pieces:next.append_array(Geometry2D.clip_polygons(piece,bridge))
				pieces=next
			for piece in pieces:
				if piece.size()<3:continue
				var body:=_body(piece,1,"WaterBank")
				if body:geometry.region_models[id].add_blocker(piece,id,1)
func _bind_travel() -> void:
	for chunk in chunks.values():
		_bind_chunk_travel(chunk)
func _bind_chunk_travel(chunk: Node2D) -> void:
	var provider=TRAVEL.new();provider.world=self;provider.chunk=chunk;chunk.add_child(provider);chunk.context_provider=provider
	for c in connections:
		if c.kind=="walk" or chunk.subregion_id not in [c.source,c.destination]:continue
		var reverse: bool=chunk.subregion_id==c.destination;var a: Array=c.destination_anchor if reverse else c.source_anchor
		var ground:=Vector2(a[0],a[1]);var height: float=float(geometry.height_record(ground).get("height",0))
		var marker:=Marker2D.new();marker.name="Transit_"+c.id.validate_node_name();marker.position=ground-chunk.ground_origin-Vector2(0,height);marker.set_meta("ground_xy",ground);chunk.add_child(marker)
		provider.ends.append({"connection":c,"reverse":reverse,"anchor":marker,"ground":ground})
func _zone1_provider_spec(id: String) -> Array:
	if not fixture_session():
		return []
	var profile := get_node("/root/PlayerSave")
	var zone1: bool = profile.get_meta("r3_030_zone1",false)
	if id==DOCK.REGION and (zone1 or profile.get_meta("r3_029_frozen_dock",false)):
		return ["frozen_dock_world","bind_dock"]
	return ZONE1_PROVIDERS.get(id,[]) if zone1 else []
func _learning_provider_spec(id: String) -> Array:
	if id=="Z3L2" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_039_sorting_room",false):
		return ["res://Scripts/World/Zone3/sample_sorting_world.gd","bind_sorting_room"]
	if id=="Z3L3" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_040_frostprint",false):
		return ["res://Scripts/World/Zone3/frostprint_world.gd","bind_frostprint"]
	if id=="Z3L4" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_041_reversible_frost",false):
		return ["res://Scripts/World/Zone3/reversible_frost_world.gd","bind_reversible_frost"]
	if id=="Z3L5" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_042_observatory",false):
		return ["res://Scripts/World/Zone3/observatory_world.gd","bind_observatory"]
	if id=="Z3L6" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_043_phaseworks_core",false):
		return ["res://Scripts/World/Zone3/phaseworks_core_world.gd","bind_core"]
	if id=="Z3L1" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_038_vanishing_lab",false):
		return ["res://Scripts/World/Zone3/vanishing_ice_lab_world.gd","bind_vanishing_lab"]
	if id==SKYBRIDGE.REGION and _skybridge_enabled():
		return ["res://Scripts/World/Zone2/skybridge_engine_world.gd","bind_skybridge"]
	if id=="Z2L5" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_035_steamworks",false):
		return ["res://Scripts/World/Zone2/steamworks_garden_world.gd","bind_steamworks"]
	if id=="Z2L4" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_034_stream",false):
		return ["res://Scripts/World/Zone2/returning_stream_world.gd","bind_stream"]
	if id=="Z2L3" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_033_dewglass",false):
		return ["res://Scripts/World/Zone2/dewglass_world.gd","bind_dewglass"]
	if id=="Z2L2" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_032_orchard",false):
		return ["res://Scripts/World/Zone2/drying_orchard_world.gd","bind_orchard"]
	if id=="Z2L1" and fixture_session() and get_node("/root/PlayerSave").get_meta("r3_031_sunlit",false):
		return ["res://Scripts/World/Zone2/sunlit_landing_world.gd","bind_sunlit"]
	var spec := _zone1_provider_spec(id)
	return [] if spec.is_empty() else ["res://Scripts/World/Zone1/%s.gd" % spec[0],spec[1]]
func _mount_learning_provider(chunk: Node2D) -> void:
	var spec := _learning_provider_spec(chunk.subregion_id)
	if spec.is_empty():
		return
	var provider = load(spec[0]).new()
	chunk.add_child(provider)
	if not provider.call(spec[1],self):
		last_error=chunk.subregion_id+": "+str(provider.last_error)
		push_error(last_error)
		provider.queue_free()
		return
	if OPTIONAL_ACTIVITY.LAYOUT.DISPLAYS.has(chunk.subregion_id):
		var station:=OPTIONAL_ACTIVITY.new()
		station.name="OptionalActivity"
		chunk.add_child(station)
		if station.bind(self,chunk):chunk.optional_activity=station
		else:
			push_error(chunk.subregion_id+": "+station.last_error)
			station.queue_free()
func world_target_allowed(target: Node) -> bool:
	var chunk:=active_chunk()
	return super.world_target_allowed(target) or (chunk!=null and is_instance_valid(chunk.optional_activity) and chunk.optional_activity.owns_target(target))
func traversal_fall() -> void:
	var chunk:=active_chunk()
	if chunk and is_instance_valid(chunk.optional_activity):chunk.optional_activity.leave()
	super.traversal_fall()
func sync_permissions() -> void:
	if access==null:return
	input_adapter.stop_all("permissions_changed",true);input_adapter.feedback="";access.refresh()
	if not _transit.is_empty():_cancel_transit()
	_apply_boundaries()
	models[0].science_open=access.completed("Z1L2")
	for m in models:
		for b in m.blockers:
			if b.gate:b.layer=0 if access.completed(b.region) else b.get("original_layer",b.layer)
	for record in gate_bodies:
		if not is_instance_valid(record.body) or not record.body.is_inside_tree():continue
		var open: bool=access.allowed(record.region) if record.get("portal_entry",false) else access.completed(record.region)
		record.body.collision_layer=0 if open else record.layer
		if record.has("record"):record.record.layer=0 if open else record.layer
	for art in props:
		var id: String=art.get_meta("asset_id","");var region: String=access.region_at(art.global_position)
		if art.get_meta("fixture_gate_art",false):art.visible=not access.completed(region)
		if id in ["bell_bridge_intact","freight_lift_lowered"]:
			var replacement: String={"bell_bridge_intact":"bell_bridge_clear","freight_lift_lowered":"freight_lift_secured"}[id] if access.completed("Z1L2") else id
			art.visuals.get_node("Artwork").texture=kits[0].get_meta("tiles",{}).get(replacement)
		if id=="maintenance_gate":
			for gate in gate_bodies:
				if gate.has("record") and art.global_position.distance_to(gate.record.bounds.get_center())<2:art.visible=gate.body.collision_layer!=0
	# Apply committed subregion apparatus/support before validating the actor's
	# current floor. A profile write must not close its earned return underneath it.
	for chunk in chunks.values():
		if is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.has_method("sync_world_permissions"):chunk.runtime_provider.sync_world_permissions()
	for layer in art_layers:layer.queue_redraw()
	if map_provider:map_provider.refresh_masks()
	if not _composing and not geometry.standable(player.position,false,true):_recover_allowed()
	input_adapter.refresh()
func _apply_boundaries() -> void:
	if not player.carrying and not _carry_region.is_empty() and input_adapter.feedback.begins_with("Place carried cargo"):input_adapter.feedback=""
	_carry_region=active_subregion_id if player.carrying else ""
	for id in permissions:
		for body in permissions[id]:
			if is_instance_valid(body):body.collision_layer=8 if not access.allowed(id) or id==_carry_region else 0
func activate(id: String,at: Vector2) -> bool:
	if access==null or not access.allowed(id):return false
	var previous:=active_chunk()
	var result:=super.activate(id,at)
	if result:
		if previous and is_instance_valid(previous.optional_activity):previous.optional_activity.leave()
		last_ground=at;_move_professor(id)
		if is_instance_valid(room_cutaway):room_cutaway.recompute()
	return result
func _recover_allowed() -> void:
	if geometry.standable(last_ground,false,true):activate(access.region_at(last_ground),last_ground);return
	for r in access.rows:
		var at:=Vector2(r.entry[0],r.entry[1])
		if access.allowed(r.id) and valid_landing(at):activate(r.id,at);return
	active_subregion_id="";_active_chunk_id=""
func refresh_room_presentation() -> void:
	if is_instance_valid(room_cutaway):room_cutaway.recompute()
func raised_surface(point: Vector2,_margin:=0.0) -> Dictionary:
	if geometry==null:return {}
	var h: Dictionary=geometry.height_record(point)
	if not h.is_empty() and not str(h.get("body_path","")).is_empty():h.body=source_bodies.get(h.region+":"+h.body_path)
	return h
func valid_landing(point: Vector2) -> bool:
	if geometry==null or not geometry.standable(point,false,true):return false
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=player.get_node("CollisionShape2D").shape;query.transform=Transform2D(0,point);query.collision_mask=11
	var h:=raised_surface(point)
	var exclusions: Array[RID] = [player.get_rid()]
	if is_instance_valid(h.get("body")):exclusions.append(h.body.get_rid())
	query.exclude = exclusions
	return player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func unsupported_fall(point: Vector2) -> bool:return geometry==null or not geometry.supported_box(Rect2(point-Vector2(10,11),Vector2(20,22)))
func player_controls_allowed() -> bool:return super.player_controls_allowed() and geometry!=null and _transit.is_empty() and access.box_allowed(Rect2(player.position-Vector2(10,11),Vector2(20,22)))
func world_contact_allowed(from: Vector2,to: Vector2) -> bool:
	return access!=null and access.point_allowed(from) and access.point_allowed(to) and access.ray_fraction(from,to)>=.999 and (not is_instance_valid(room_cutaway) or room_cutaway.ray_fraction(from,to)>=.999)
func world_emission_endpoint(ground: Vector2,origin: Vector2,end: Vector2) -> Vector2:
	if not access:return origin
	var fraction: float=access.ray_fraction(ground,ground+end-origin)
	if is_instance_valid(room_cutaway):fraction=minf(fraction,room_cutaway.ray_fraction(ground,ground+end-origin))
	return origin.lerp(end,fraction)
func footstep_surface(point: Vector2) -> String:
	var id: String=access.region_at(point) if access else ""
	return "cement" if id.begins_with("Z3") else "snow" if id.begins_with("Z1") else "cement"
func minimap_state() -> Dictionary:return map_provider.minimap_state() if is_instance_valid(map_provider) else {}
func _move_professor(id: String) -> void:
	if geometry==null:return
	var m: RefCounted=geometry.region_models[id];var index:=int(id.substr(1,1))-1
	for s in m.data.stations:
		if s.subregion==id and s.kind=="professor":professors[index].global_position=m.v(s.ground_xy);professors[index].elevation=float(m.height_record(m.v(s.ground_xy)).get("height",0));return
func _update_discovery() -> void:
	if discovery==null or not _transit.is_empty() or not player_controls_allowed():return
	if discovery.observe(player.position,access):map_provider.refresh_masks()
func _physics_process(delta: float) -> void:
	if geometry==null or not _transit.is_empty():return
	if _carry_region!=(active_subregion_id if player.carrying else ""):_apply_boundaries()
	if not access.box_allowed(Rect2(player.position-Vector2(10,11),Vector2(20,22))):input_adapter.stop_all("invalid_locked_position",true);_recover_allowed();return
	var id: String=access.region_at(player.position)
	if player.carrying and not active_subregion_id.is_empty() and id!=active_subregion_id:
		input_adapter.stop_all("local_cargo_return",true);player.position=last_ground;player.reset_physics_interpolation();input_adapter.feedback="Place carried cargo on its local return pad before crossing.";input_adapter.refresh();return
	if not id.is_empty() and id!=active_subregion_id:
		var previous_id:=active_subregion_id
		active_subregion_id=id;_active_chunk_id=id+".shell";var row:=REGISTRY.definition(id);SAVE_ZONE=row.zone_id;SAVE_LEVEL=row.level;_move_professor(id);subregion_changed.emit(id);input_adapter.refresh()
		var profile:=get_node("/root/PlayerSave")
		if writes_navigation() and not profile.enter_world_subregion(self,id):
			activate(previous_id,last_ground);input_adapter.feedback="Location could not be saved; try crossing again.";input_adapter.refresh();return
	if valid_landing(player.position):last_ground=player.position
	_discovery_clock+=delta;_save_clock+=delta
	if _discovery_clock>.3:_discovery_clock=0;_update_discovery()
	if _save_clock>2:
		_save_clock=0
		if not discovery.save_ledger():input_adapter.feedback="Map discovery could not be saved.";input_adapter.refresh()
func _process(delta: float) -> void:
	if geometry==null:return
	if not _transit.is_empty():_advance_transit(delta)
func connection(id: String) -> Dictionary:
	for c in connections:
		if c.id==id:return c
	return {}
func writes_navigation() -> bool:
	return fixture_session() and get_node("/root/PlayerSave").get_meta("r3_020_restore",false)
func _skybridge_enabled() -> bool:
	return fixture_session() and get_node("/root/PlayerSave").get_meta("r3_036_skybridge",false)
func can_transit(id: String,reverse:=false) -> bool:
	if not player_controls_allowed() or player.carrying or player.jump_elapsed>=0 or player.action_elapsed>=0:return false
	var c:=connection(id)
	if c.is_empty() or c.kind=="walk" or not access.allowed(c.source) or not access.allowed(c.destination):return false
	if id==DOCK.CONNECTION and not _zone1_provider_spec(DOCK.REGION).is_empty():
		var dock: Node=chunks[DOCK.REGION+".shell"].runtime_provider if chunks.has(DOCK.REGION+".shell") else null
		if not is_instance_valid(dock) or not dock.boat_earned():return false
	if id==SKYBRIDGE.CONNECTION and _skybridge_enabled():
		var skybridge: Node=chunks[SKYBRIDGE.REGION+".shell"].runtime_provider if chunks.has(SKYBRIDGE.REGION+".shell") else null
		if not skybridge is SKYBRIDGE or not skybridge.lift_earned():return false
	var from: Array=c.destination_anchor if reverse else c.source_anchor;var to: Array=c.source_anchor if reverse else c.destination_anchor
	if player.position.distance_to(Vector2(from[0],from[1]))>80 or active_subregion_id!=(c.destination if reverse else c.source):return false
	for p in c.polyline:
		var owner: String=access.region_at(Vector2(p[0],p[1]))
		if not owner.is_empty() and not access.allowed(owner):return false
	for i in range(1,c.polyline.size()):
		if not access.segment_clear(Vector2(c.polyline[i-1][0],c.polyline[i-1][1]),Vector2(c.polyline[i][0],c.polyline[i][1])):return false
	return valid_landing(Vector2(to[0],to[1]))
func start_transit(id: String,reverse:=false) -> bool:
	if not can_transit(id,reverse):return false
	var c:=connection(id);var points: Array=c.polyline.duplicate(true)
	if reverse:points.reverse()
	input_adapter.stop_all("transit",true);player.set_physics_process(false)
	var zone:=0 if c.kind=="crafted boat passage" else 2
	var asset: String="boat_assembly_launched" if zone==0 else "permanent_step"
	if id==SKYBRIDGE.CONNECTION and _skybridge_enabled():
		zone=1
		asset="water_lift_departing"
	var definition: Dictionary=catalogs[zone][asset]
	var carrier=preload("res://Scripts/World/Runtime/grounded_visual.gd").new();carrier.name="GeographicCarrier";carrier.position=player.position;carrier.elevation=player._display_floor;carrier.z_index=-1;$GroundSort.add_child(carrier)
	var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=kits[zone].get_meta("tiles",{}).get(definition.id);sprite.scale=Vector2.ONE*float(definition.world_scale);sprite.position=-Vector2(definition.pivot_px[0],definition.pivot_px[1])*float(definition.world_scale);carrier.visuals.add_child(sprite)
	_transit={"id":id,"reverse":reverse,"points":points,"elapsed":0.0,"origin":player.position,"source":active_subregion_id,"destination":c.source if reverse else c.destination,"from_height":player._display_floor,"to_height":float(geometry.height_record(Vector2(points[-1][0],points[-1][1])).get("height",0)),"carrier":carrier}
	return true
func _advance_transit(delta: float) -> void:
	var c:=connection(_transit.id)
	if not access.allowed(c.source) or not access.allowed(c.destination):_cancel_transit();return
	_transit.elapsed+=delta;var t:=clampf(_transit.elapsed/2.0,0,1);var points: Array=_transit.points
	var lengths: Array=[];var total:=0.0
	for i in range(1,points.size()):var length:=Vector2(points[i-1][0],points[i-1][1]).distance_to(Vector2(points[i][0],points[i][1]));lengths.append(length);total+=length
	var distance:=total*t
	for i in range(lengths.size()):
		if distance<=lengths[i] or i==lengths.size()-1:player.position=Vector2(points[i][0],points[i][1]).lerp(Vector2(points[i+1][0],points[i+1][1]),clampf(distance/maxf(.001,lengths[i]),0,1));break
		distance-=lengths[i]
	player._display_floor=lerpf(_transit.from_height,_transit.to_height,t);player.animated_sprite.position=player._visual_home-Vector2(0,player._display_floor)
	_transit.carrier.position=player.position;_transit.carrier.elevation=player._display_floor
	if t>=1:
		var journey:=_transit;var destination: String=journey.destination;var at:=Vector2(points[-1][0],points[-1][1]);journey.carrier.queue_free();_transit={};player.set_physics_process(true)
		if not activate(destination,at):_recover_allowed()
		elif journey.id==DOCK.CONNECTION:
			var profile:=get_node("/root/PlayerSave")
			if not _zone1_provider_spec(DOCK.REGION).is_empty() and not profile.enter_world_subregion(self,destination):
				activate(journey.source,journey.origin)
				input_adapter.feedback="Boat arrival could not be saved. Board again."
				input_adapter.refresh()
		elif journey.id==SKYBRIDGE.CONNECTION and _skybridge_enabled():
			if not get_node("/root/PlayerSave").enter_world_subregion(self,destination):
				activate(journey.source,journey.origin)
				input_adapter.feedback="Lift arrival could not be saved. Board again."
				input_adapter.refresh()
		_update_discovery()
func _cancel_transit() -> void:
	if _transit.is_empty():return
	var origin: Vector2=_transit.origin;var id: String=_transit.source;_transit.carrier.queue_free();_transit={};player.set_physics_process(true)
	if access.allowed(id) and valid_landing(origin):activate(id,origin)
	else:_recover_allowed()
func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if geometry!=null:_cancel_transit()
		if discovery!=null:discovery.save_ledger()
		if geometry!=null and is_instance_valid(input_adapter):
			var profile:=get_node("/root/PlayerSave")
			if writes_navigation():profile.save_world_location(self)
func _exit_tree() -> void:
	if discovery!=null:discovery.save_ledger()
	super._exit_tree()
