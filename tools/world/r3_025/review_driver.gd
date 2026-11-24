extends Node
const PROVIDER=preload("res://Scripts/World/Zone1/frozen_mill_world.gd")
var world: Node
var provider: Node
func bind(host: Node) -> bool:
	process_mode=Node.PROCESS_MODE_ALWAYS;world=host
	var profile=get_node("/root/PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L2")
	var at: Vector2=world.player.position if world.active_subregion_id=="Z1L2" else Vector2(row.entry[0],row.entry[1])
	if not world.activate("Z1L2",at) or not profile.enter_world_subregion(world,"Z1L2"):return false
	provider=PROVIDER.new();world.chunks["Z1L2.shell"].add_child(provider)
	return provider.bind_mill(world)
func pose(id: String,aiming:=false) -> bool:
	if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
	var at: Vector2=provider.points[id]
	if aiming and id.begins_with("runtime_"):
		var index: int=provider.PARTS.find(id.trim_prefix("runtime_"))
		if index>=0 and provider._state.legacy.workshop_parts[index]>0:aiming=false
	for radius in ([55,65,75,85] if aiming else [28,34,39]):
		for step in range(24):
			var point: Vector2=at+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(point) or not world.activate("Z1L2",point):continue
			if aiming:
				var emitter=world.input_adapter.emitter;emitter.facing=(at-world.player.position).normalized();emitter.release();emitter._aim()
				if is_instance_valid(emitter.selected) and emitter.selected.definition().id.begins_with("mill_"):return true
			elif provider.action_allowed(id):return true
	return false
func recover() -> void:
	world.dead=true
	for i in range(3):await get_tree().process_frame
	print("Mill checkpoint recovery: ",world.recover_world_checkpoint(world.access))
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or world==null:return
	var profile=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_F1:get_window().size=Vector2i(960,540);get_window().content_scale_size=get_window().size
		KEY_F2:get_window().size=Vector2i(640,360);get_window().content_scale_size=get_window().size
		KEY_1:pose("MillDock")
		KEY_2:pose("HeatRouteStation")
		KEY_3:pose("HeaterCartridge")
		KEY_4:pose("runtime_gear",true)
		KEY_5:pose("runtime_crank",true)
		KEY_6:pose("runtime_brake_shoe",true)
		KEY_7:pose("runtime_tray_gear")
		KEY_8:pose("runtime_tray_crank")
		KEY_9:pose("runtime_tray_brake_shoe")
		KEY_B:pose("ReflectorA")
		KEY_N:pose("ReflectorB")
		KEY_R:pose("WalkbackLever")
		KEY_P:pose("MillCrankRecovery")
		KEY_I:pose("CrankSocket")
		KEY_X:pose("exit")
		KEY_J:
			var point: Vector2=world.models[0].v(provider._jump.from)+world.active_chunk().ground_origin
			print("J2 takeoff inspection: ",world.activate("Z1L2",point))
		KEY_H:world.input_adapter.open_lesson("resonance" if not provider._state.legacy.clear else ("melting" if not provider._state.legacy.latch_thawed else "balance"))
		KEY_Q:provider.open_question()
		KEY_F5:print("Mill fixture save: ",profile.save_world_location(world))
		KEY_F9:
			if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
			profile.load_profile();print("Mill Continue: ",world.restore_saved_world(world.access))
		KEY_K:recover()
		KEY_T:profile.fail_commit=not profile.fail_commit;print("Mill save failure: ",profile.fail_commit)
