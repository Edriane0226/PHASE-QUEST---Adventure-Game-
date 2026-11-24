extends Node

const CIRCUIT = preload("res://Scripts/World/Zone3/reversible_frost_world.gd")
const PARTS = CIRCUIT.PARTS
const BEAMS := {"source_ice":PARTS.SOURCE,"deposit_a":PARTS.FIRST,"return_a":PARTS.RETURN,"deposit_b":PARTS.FINAL}
const KEYS := {KEY_P:"professor",KEY_1:"source_valve",KEY_2:"source_gauge",KEY_3:"source_ice",
	KEY_4:"a_gauge",KEY_5:"deposit_a",KEY_6:"a_valve",KEY_7:"return_a",KEY_8:"b_gauge",KEY_9:"deposit_b",
	KEY_Q:"question",KEY_X:"exit"}
var world: Node
var room: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	room = world.chunks[CIRCUIT.REGION+".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	return is_instance_valid(room) and (world.active_subregion_id == "Z3L3" or room.active())

func pose(id: String, require_action := true) -> bool:
	var beam := BEAMS.has(id)
	var part := id
	if beam:
		part = room.contract.targets[BEAMS[id]].component.get_slice("/",0)
	elif room.contract.actions.has(id):
		part = room.contract.actions[id].component.get_slice("/",0)
	var at: Vector2 = room.points[part]
	for radius in ([60,68,77,54] if beam else [25,31,38,41,20]):
		for i in 16:
			var position := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(CIRCUIT.REGION,position): continue
			if beam:
				var target: Node2D = room.targets[BEAMS[id]]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
						not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif room._near(part) and (not require_action or room.world_context().get("key") == CIRCUIT.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var target: Node2D = room.targets[BEAMS[id]]
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
		if event.physical_keycode == KEY_B:
			var route := crossing()
			if world.active_subregion_id == "Z3L3": world.activate("Z3L3",route[0])
			elif world.active_subregion_id == CIRCUIT.REGION: world.activate(CIRCUIT.REGION,route.back())
		if world.active_subregion_id != CIRCUIT.REGION: return
		if KEYS.has(event.physical_keycode):
			pose(KEYS[event.physical_keycode],false)

func crossing() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
	for row in entries.routes:
		if row.id != "Z3L3--Z3L4": continue
		for point in row.points:
			points.append(Vector2(point[0],point[1]))
		break
	# The authored route includes approach samples before the walkable entry.
	while points.size() > 1 and (world.access.region_at(points.front()) != "Z3L3" or not world.valid_landing(points.front())):
		points.pop_front()
	while points.size() > 1 and (world.access.region_at(points.back()) != CIRCUIT.REGION or not world.valid_landing(points.back())):
		points.pop_back()
	return points
