extends Node
const CANAL = preload("res://Scripts/World/Zone1/canal_world.gd")
var world
var provider
var profile

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	var row: Dictionary = world.REGISTRY.definition("Z1L4")
	if world.active_subregion_id != "Z1L4":
		if not world.activate("Z1L4", Vector2(row.entry[0], row.entry[1])) or not profile.enter_world_subregion(world, "Z1L4"):
			return false
	return bind_provider()

func bind_provider() -> bool:
	provider = CANAL.new()
	world.chunks["Z1L4.shell"].add_child(provider)
	return provider.bind_canal(world)

func pose(id: String, aim := false) -> bool:
	var at: Vector2
	if aim:
		at = provider.targets[id].get_meta("ground_xy")
	elif id in ["drive", "release"]:
		return false # Reach far-side controls by walking across their span.
	elif id == "exit":
		at = provider.points.exit
	else:
		at = provider.component(provider.contract.actions[id].component).position
	var emitter = world.input_adapter.emitter
	var fallback := Vector2.INF
	for radius in ([60, 72, 88] if aim else [20, 28, 36]):
		for i in range(16):
			var point: Vector2 = at + Vector2.LEFT.rotated(i * TAU / 16) * float(radius)
			if not world.valid_landing(point) or not world.activate("Z1L4", point):
				continue
			if aim:
				var target = provider.targets[id]
				if not target.geometry_reason(world.player.device_muzzle()).is_empty():
					continue
				if not fallback.is_finite():
					fallback = point
				_face(emitter, target)
				if emitter.selected == target:
					return true
			elif provider._near(at):
				return true
	if aim and fallback.is_finite() and world.activate("Z1L4", fallback):
		_face(emitter, provider.targets[id])
		return true
	return false

func _face(emitter: Node, target: Node2D) -> void:
	emitter.release()
	emitter.facing = (target.global_position - world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func bank(id: String) -> bool:
	return world.activate("Z1L4", provider.crossings.spans[id].center + Vector2(-76, 0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not world.input_adapter.modal.is_empty() and event.physical_keycode not in [KEY_F1, KEY_F2, KEY_F9]:
		return
	match event.physical_keycode:
		KEY_1: pose("thaw_intake", true)
		KEY_2: pose("divert")
		KEY_3: pose("isolate")
		KEY_4: pose("freeze_side", true)
		KEY_5: bank("side")
		KEY_6: pose("thaw_lock", true)
		KEY_7: pose("pickup")
		KEY_8: pose("seat")
		KEY_9: pose("refreeze_lock", true)
		KEY_0: pose("latch")
		KEY_B: bank("bridge")
		KEY_X: pose("exit")
		KEY_F1, KEY_F2:
			get_window().size = Vector2i(640, 360) if event.physical_keycode == KEY_F2 else Vector2i(960, 540)
			get_window().content_scale_size = get_window().size
		KEY_F5: print("CANAL SAVE ", profile.save_world_location(world))
		KEY_F9:
			world.input_adapter.close_panel()
			profile.load_profile()
			print("CANAL CONTINUE ", world.restore_saved_world(world.access))
		KEY_K: world.traversal_fall()
		KEY_T:
			profile.fail_commit = not profile.fail_commit
			print("CANAL SAVE FAILURE ", profile.fail_commit)
