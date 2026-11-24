extends Node

const PARTS = preload("res://Scripts/World/Zone2/stream_circuit_assembly.gd")
const KEYS := {KEY_P:"professor",KEY_1:"heat",KEY_2:"supply",KEY_3:"sun",KEY_4:"lift_fitting",KEY_5:"fit",
	KEY_6:"seal",KEY_7:"capture",KEY_8:"compare",KEY_9:"cool",KEY_0:"drain",KEY_M:"measure"}
var world: Node
var stream: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	stream = world.chunks["Z2L4.shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(stream):
		return false
	if world.active_subregion_id == "Z2L3" and world.access.allowed(PARTS.REGION):
		if not world.activate(PARTS.REGION,stream.points.C0) or not profile.enter_world_subregion(world,PARTS.REGION):
			return false
		stream.refresh_binding()
	return world.active_subregion_id == PARTS.REGION and stream.active()

func pose(id: String, require_action := true) -> bool:
	var beam := id in ["heat","cool"]
	var part: String = "inlet" if id == "heat" else ("plate" if id == "cool" else ("professor" if id == "professor" else stream.contract.actions[id].component.get_slice("/",0)))
	var at: Vector2 = stream.points[part]
	for radius in ([64,70,56] if beam else [31,39,35,42,25]):
		for i in 16:
			var pos := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(PARTS.REGION,pos): continue
			if beam:
				var target: Node2D = stream.targets[PARTS.INLET if id == "heat" else PARTS.COLLECTOR]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
					not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif stream._near(part) and (not require_action or stream.world_context().get("key") == PARTS.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	var target: Node2D = stream.targets[PARTS.INLET if id == "heat" else PARTS.COLLECTOR]
	var direction: Vector2 = target.get_meta("ground_xy")-world.player.position
	world.player.set_device_aim(direction)
	emitter.facing = (target.global_position-world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		world.restore_saved_world(world.access)
	elif world.input_adapter.modal.is_empty():
		if event.physical_keycode == KEY_F5: profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if not world.player.carrying:
			if event.physical_keycode == KEY_L: world.activate(PARTS.REGION,stream.points.lift-Vector2(83,0))
			if KEYS.has(event.physical_keycode): pose(KEYS[event.physical_keycode],false)
