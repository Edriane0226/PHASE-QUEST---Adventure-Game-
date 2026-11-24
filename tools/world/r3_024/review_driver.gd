extends Node
const PROVIDER=preload("res://Scripts/World/Zone1/melting_garden_world.gd")
var world: Node
var provider: Node
func bind(host: Node) -> bool:
	process_mode=Node.PROCESS_MODE_ALWAYS;world=host
	var store=get_node("/root/PlayerSave")
	if not store.enter_world_subregion(world,"Z1L1"):return false
	provider=PROVIDER.new();world.chunks["Z1L1.shell"].add_child(provider)
	return provider.bind_garden(world)
func position_for(id: String) -> bool:
	if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
	for radius in [28,32,36,45,55,65,75,85]:
		for step in 32:
			var point: Vector2=provider.pieces[id].position+Vector2.from_angle(step*TAU/32)*radius
			if not world.valid_landing(point) or not world.activate("Z1L1",point):continue
			var emitter=world.input_adapter.emitter
			emitter.facing=(provider.pieces[id].position-world.player.position).normalized()
			emitter.release();emitter._aim()
			if id=="ice0" and provider.targets.has(provider.FIRST_ID) and emitter.selected==provider.targets[provider.FIRST_ID]:return true
			if id!="ice0" and provider.action_allowed(id):return true
	return false
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or world==null:return
	var store=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_F1:get_window().size=Vector2i(960,540);get_window().content_scale_size=get_window().size
		KEY_F2:get_window().size=Vector2i(640,360);get_window().content_scale_size=get_window().size
		KEY_1:print("First barrier pose: ",position_for("ice0"))
		KEY_2:position_for("wood")
		KEY_3:position_for("brazier1")
		KEY_4:position_for("blades")
		KEY_5:position_for("vent")
		KEY_6:position_for("mirror")
		KEY_7:position_for("mirror2")
		KEY_8:position_for("mirror3")
		KEY_L:world.input_adapter.open_lesson("melting")
		KEY_F5:print("Fixture save: ",store.save_world_location(world))
		KEY_F9:
			if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
			store.load_profile();print("Fixture Continue: ",world.restore_saved_world(world.access))
		KEY_K:print("Newest checkpoint recovery: ",world.recover_world_checkpoint(world.access))
		KEY_T:store.fail_commit=not store.fail_commit;print("Fixture save failure: ",store.fail_commit)
