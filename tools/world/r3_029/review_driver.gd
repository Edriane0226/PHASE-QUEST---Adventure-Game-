extends Node
const REGION := "Z1L6"
var world: Node
var dock: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	dock = world.chunks[REGION + ".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dock == null:
		return false
	if world.active_subregion_id in [REGION, "Z2L1"]:
		return true
	return world.activate(REGION, dock.points.entry) and profile.enter_world_subregion(world, REGION)

func pose(id: String, aim := false) -> bool:
	var target: Node2D = dock.targets.get(id) if aim else null
	var at: Vector2
	if aim:
		if target == null:
			return false
		at = target.get_meta("ground_xy")
	elif id in ["finn","professor","exit"]:
		at = dock.points[id]
	else:
		at = dock.component(dock.contract.actions[id].component).position
	var fallback := Vector2.INF
	for radius in ([64, 79, 93] if aim else [22, 28, 34]):
		for i in range(16):
			var point: Vector2 = at + Vector2.LEFT.rotated(i * TAU / 16) * float(radius)
			if not world.activate(REGION, point):
				continue
			if aim:
				if not target.geometry_reason(world.player.device_muzzle()).is_empty():
					continue
				if not fallback.is_finite():
					fallback = point
				face(target)
				if world.input_adapter.emitter.selected == target:
					return true
			elif dock._near(at, id):
				if dock.world_context().get("key") == REGION + ":" + id:
					return true
				if not fallback.is_finite():
					fallback = point
	if fallback.is_finite() and world.activate(REGION, fallback):
		if aim:
			face(target)
		return true
	return false

func face(target: Node2D) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	emitter.facing = (target.global_position - world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_T:
		profile.fail_commit = not profile.fail_commit
		print("DOCK SAVE FAILURE ", profile.fail_commit)
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		print("DOCK CONTINUE ", world.restore_saved_world(world.access))
	if not world.input_adapter.modal.is_empty():
		return
	var keys := {
		KEY_1:"ramp", KEY_2:"thaw_plank1", KEY_3:"thaw_plank2", KEY_4:"thaw_plank3",
		KEY_5:"fill_walkway", KEY_6:"freeze_walkway", KEY_7:"latch_walkway", KEY_8:"isolate_heat",
		KEY_9:"thaw_rudder", KEY_J:"fill_jig", KEY_B:"freeze_jig", KEY_M:"release_jig",
		KEY_R:"recipe", KEY_L:"test", KEY_N:"finn", KEY_X:"exit", KEY_P:"professor",
	}
	var id: String = keys.get(event.physical_keycode, "")
	if not id.is_empty():
		pose(id, dock.targets.has(id))
	match event.physical_keycode:
		KEY_F5: print("DOCK SAVE ", profile.save_world_location(world))
		KEY_K: world.traversal_fall()
		KEY_F1, KEY_F2:
			get_window().size = Vector2i(640, 360) if event.physical_keycode == KEY_F2 else Vector2i(960, 540)
			get_window().content_scale_size = get_window().size
