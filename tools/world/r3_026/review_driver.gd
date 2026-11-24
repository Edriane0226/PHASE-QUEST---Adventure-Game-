extends Node
const PROVIDER=preload("res://Scripts/World/Zone1/stillwater_world.gd")
var world
var provider
func bind(host: Node) -> bool:
	process_mode=Node.PROCESS_MODE_ALWAYS;world=host
	var profile=get_node("/root/PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L3")
	var at: Vector2=world.player.position if world.active_subregion_id=="Z1L3" else Vector2(row.entry[0],row.entry[1])
	if not world.activate("Z1L3",at) or not profile.enter_world_subregion(world,"Z1L3"):return false
	provider=PROVIDER.new();world.chunks["Z1L3.shell"].add_child(provider);return provider.bind_crossing(world)
func pose(id: String,aiming:=false) -> bool:
	if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
	var at: Vector2=provider.targets[id].get_meta("ground_xy") if aiming else provider.points[id]
	for radius in ([60,75,85,95] if aiming else [28,34,39]):
		for step in range(24):
			var point: Vector2=at+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(point) or not world.activate("Z1L3",point):continue
			if aiming:
				var emitter=world.input_adapter.emitter;emitter.facing=(provider.targets[id].global_position-world.player.device_muzzle().global_position).normalized();emitter.release();emitter._aim()
				if emitter.selected==provider.targets[id]:return true
			elif provider.action_allowed(id):return true
	return false
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var profile=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_F1:get_window().size=Vector2i(960,540);get_window().content_scale_size=get_window().size
		KEY_F2:get_window().size=Vector2i(640,360);get_window().content_scale_size=get_window().size
		KEY_1:pose("professor")
		KEY_2:pose("first_ice",true)
		KEY_3:pose("melt_supply",true)
		KEY_4:pose("valve")
		KEY_5:pose("heater")
		KEY_6:pose("left_ice",true)
		KEY_7:pose("right_ice",true)
		KEY_8:pose("latch")
		KEY_J:world.activate("Z1L3",provider.points.court3+Vector2(-56,0))
		KEY_X:pose("exit")
		KEY_Q:pose("question")
		KEY_F5:print("STILLWATER SAVE ",profile.save_world_location(world))
		KEY_F9:
			if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
			profile.load_profile();print("STILLWATER CONTINUE ",world.restore_saved_world(world.access))
		KEY_K:world.traversal_fall()
		KEY_T:profile.fail_commit=not profile.fail_commit;print("STILLWATER SAVE FAILURE ",profile.fail_commit)
