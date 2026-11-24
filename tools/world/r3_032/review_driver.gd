extends Node

var world: Node
var orchard: Node
var profile: Node
const KEYS := {KEY_P:"professor",KEY_1:"spread",KEY_2:"sun",KEY_3:"air",KEY_4:"dry",KEY_5:"inspect",
	KEY_6:"take",KEY_7:"fit",KEY_F:"fill",KEY_G:"guard",KEY_B:"heat",KEY_V:"route",KEY_C:"cloth",KEY_W:"wheel",KEY_X:"exit"}

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	orchard = world.chunks["Z2L2.shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(orchard):
		return false
	if world.active_subregion_id == "Z2L1" and world.access.allowed("Z2L2"):
		if not world.activate("Z2L2",orchard.points.C0) or not profile.enter_world_subregion(world,"Z2L2"):
			return false
		orchard.refresh_binding()
	return world.active_subregion_id == "Z2L2" and orchard.active()

func pose(id: String, require_action := true) -> bool:
	var heat := id == "heat"
	var part: String = "boiler" if heat else ("professor" if id == "professor" else orchard.contract.actions[id].component.get_slice("/",0))
	var at: Vector2 = orchard.points[part]
	for radius in ([78,90,100] if heat else [30,38,40,22]):
		for i in 16:
			var pos := at + Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate("Z2L2",pos):
				continue
			if heat:
				aim()
				if orchard.targets[orchard.PARTS.TARGET_ID].geometry_reason(world.player.device_muzzle()).is_empty():
					return true
			elif orchard._near(part) and (not require_action or orchard.world_context().get("key") == "Z2L2:"+id):
				return true
	return false

func aim() -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	emitter.facing = (orchard.targets[orchard.PARTS.TARGET_ID].global_position-world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		world.restore_saved_world(world.access)
	elif world.input_adapter.modal.is_empty():
		if event.physical_keycode == KEY_F5: profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if event.physical_keycode == KEY_J: world.activate("Z2L2",orchard.points.curb + Vector2(-105,0))
		if event.physical_keycode == KEY_H: world.activate("Z2L2",orchard.points.plinth + Vector2(0,104))
		if KEYS.has(event.physical_keycode): pose(KEYS[event.physical_keycode],false)
