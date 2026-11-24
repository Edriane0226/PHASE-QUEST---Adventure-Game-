extends Node

var world: Node
var sunlit: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	sunlit = world.chunks["Z2L1.shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	return is_instance_valid(sunlit) and world.active_subregion_id == "Z2L1"

func pose(id: String, aiming := false, require_context := true) -> bool:
	var target: Node2D = sunlit.targets.get(id) if aiming else null
	var at: Vector2
	if aiming:
		if target == null:
			return false
		at = target.get_meta("ground_xy")
	elif id in ["professor","exit"]:
		at = sunlit.points[id]
	else:
		at = sunlit.component(sunlit.contract.actions[id].component).position
	var reasons := {}
	for radius in ([66,80,93] if aiming else [22,29,34]):
		for i in 16:
			var point := at + Vector2.LEFT.rotated(i * TAU / 16) * float(radius)
			if not world.activate("Z2L1", point):
				continue
			if aiming:
				face(target)
				var reason: String = target.geometry_reason(world.player.device_muzzle())
				if reason.is_empty():
					return true
				reasons[reason] = true
			elif (not require_context and sunlit._near(at)) or sunlit.world_context().get("key") == "Z2L1:" + id:
				return true
	print("SUNLIT pose unavailable ", id, " target=", at, " owner=", world.access.region_at(at), " actor=", world.player.position, " active=", sunlit.active(), " near=", sunlit._near(at), " contact=", world.world_contact_allowed(world.player.position,at), " rooms=", world.room_cutaway.ray_fraction(world.player.position,at), " reasons=", reasons)
	return false

func face(target: Node2D) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	emitter.facing = (target.global_position - world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F5: print("SUNLIT SAVE ", profile.save_world_location(world))
		KEY_F9:
			world.input_adapter.close_panel()
			profile.load_profile()
			print("SUNLIT CONTINUE ", world.restore_saved_world(world.access))
		KEY_F1, KEY_F2:
			get_window().size = Vector2i(640,360) if event.physical_keycode == KEY_F2 else Vector2i(960,540)
			get_window().content_scale_size = get_window().size
	if not world.input_adapter.modal.is_empty():
		return
	var keys := {
		KEY_P:"professor", KEY_1:"open_canopy", KEY_2:"open_shutter", KEY_3:"fill_tray", KEY_4:"sunny_tray_evaporation",
		KEY_5:"set_float", KEY_6:"fill_boiler", KEY_7:"close_cover", KEY_8:"sunlit_chamber_boiling", KEY_9:"set_turbine",
		KEY_M:"sunlit_crate_melting", KEY_L:"fill_support", KEY_F:"sunlit_support_freezing", KEY_S:"lock_support", KEY_X:"exit",
	}
	var id: String = keys.get(event.physical_keycode, "")
	if event.physical_keycode == KEY_R:
		id = "aim_reflector_" + sunlit._phase(sunlit._state, "reflector")
	if event.physical_keycode == KEY_K:
		world.traversal_fall()
	if event.physical_keycode == KEY_B:
		var boat: Dictionary = sunlit.travel.ends[0]
		world.activate("Z2L1", boat.ground)
	if event.physical_keycode == KEY_H:
		world.activate("Z2L1", sunlit.points.span + Vector2(-87,0))
	if sunlit.targets.has(id) or sunlit.contract.actions.has(id) or id in ["professor","exit"]:
		pose(id, sunlit.targets.has(id), false)
