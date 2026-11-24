extends Node

const OBSERVATORY = preload("res://Scripts/World/Zone3/observatory_world.gd")
const PARTS = OBSERVATORY.PARTS
const BEAMS := {"melt":"melting","freeze":"freezing","evap":"evaporation","boil":"boiling",
	"condense":"condensation","sublime":"sublimation","deposit":"deposition"}
const KEYS := {KEY_P:"professor",KEY_1:"melt",KEY_2:"fill",KEY_3:"freeze",KEY_4:"release",KEY_5:"take",
	KEY_6:"dock",KEY_7:"spread",KEY_8:"evap",KEY_9:"guard",KEY_0:"boil",KEY_W:"wheel",KEY_C:"condense",
	KEY_L:"sublime_setup",KEY_V:"sublime",KEY_T:"route",KEY_U:"deposit_setup",KEY_O:"deposit",KEY_D:"blueprint",
	KEY_Q:"solid_liquid",KEY_E:"liquid_gas",KEY_R:"solid_gas",KEY_X:"exit"}
var world: Node
var room: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	room = world.chunks[OBSERVATORY.REGION+".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	return is_instance_valid(room) and (world.active_subregion_id == "Z3L4" or room.active())

func pose(id: String, require_action := true) -> bool:
	var beam := BEAMS.has(id)
	var part := id
	if beam:
		part = room.contract.targets[PARTS.target_id(BEAMS[id])].component.get_slice("/",0)
	elif room.contract.actions.has(id):
		part = room.contract.actions[id].component.get_slice("/",0)
	var at: Vector2 = room.points[part]
	for radius in ([60,68,77,54] if beam else [25,31,38,41,20]):
		for i in 16:
			var position := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(OBSERVATORY.REGION,position): continue
			if beam:
				var target: Node2D = room.targets[PARTS.target_id(BEAMS[id])]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
						not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif room._near(part) and (not require_action or room.world_context().get("key") == OBSERVATORY.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var target: Node2D = room.targets[PARTS.target_id(BEAMS[id])]
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	world.player.set_device_aim(target.get_meta("ground_xy")-world.player.position)
	emitter.facing = (target.global_position-world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		world.restore_saved_world(world.access)
	elif world.input_adapter.modal.is_empty():
		if event.physical_keycode == KEY_F5 and world._transit.is_empty(): profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if world.player.carrying: return
		if event.physical_keycode == KEY_B:
			var route := crossing()
			if world.active_subregion_id == "Z3L4": world.activate("Z3L4",route[0])
			elif world.active_subregion_id == OBSERVATORY.REGION: world.activate(OBSERVATORY.REGION,route.back())
		if world.active_subregion_id != OBSERVATORY.REGION: return
		if KEYS.has(event.physical_keycode):
			pose(KEYS[event.physical_keycode],false)

func crossing() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
	for row in entries.routes:
		if row.id != "Z3L4--Z3L5": continue
		for point in row.points:
			points.append(Vector2(point[0],point[1]))
		break
	# The authored route includes approach samples before the walkable entry.
	while points.size() > 1 and (world.access.region_at(points.front()) != "Z3L4" or not world.valid_landing(points.front())):
		points.pop_front()
	while points.size() > 1 and (world.access.region_at(points.back()) != OBSERVATORY.REGION or not world.valid_landing(points.back())):
		points.pop_back()
	return points
