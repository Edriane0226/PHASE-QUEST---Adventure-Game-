extends Node
var world: Node
var prefix:=0
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var store:=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_EQUAL,KEY_KP_ADD:prefix=mini(18,prefix+1);store.set_completed_prefix(prefix)
		KEY_MINUS,KEY_KP_SUBTRACT:prefix=maxi(0,prefix-1);store.set_completed_prefix(prefix)
		KEY_1,KEY_2,KEY_3:
			var id:="Z%dL1"%(event.physical_keycode-KEY_1+1)
			if world.activate(id,store.WORLD_SAVE.anchor(id,"C0")):store.enter_world_subregion(world,id)
		KEY_F5:
			if store.data.active_run.is_empty():store.enter_world_subregion(world,world.active_subregion_id)
			var ok: bool=store.save_world_location(world);print("SAVE ",ok," ",store.last_error)
		KEY_F9:store.load_profile();print("RESTORE ",world.restore_saved_world(world.access)," ",store.active_world_zone())
		KEY_R:print("CHECKPOINT ",world.recover_world_checkpoint(world.access))
		KEY_T:
			if store.enter_world_subregion(world,world.active_subregion_id):
				store.data.active_run.state.checkpoint_progress={"version":1,"unlock_sequence":["C0","C2","C1"]}
				store.save_profile();print("FIXTURE unlock C0 -> C2 -> C1; expected respawn C1")
		KEY_O:
			var id: String=world.active_subregion_id
			if world.activate(id,store.WORLD_SAVE.anchor(id,"C0")):store.save_world_location(world);print("Visited old C0; newest remains C1 after T")
		KEY_C:world.player.carrying=not world.player.carrying
		KEY_J:world.player.request_jump()
		KEY_K:store.fail_commit=not store.fail_commit;print("SIMULATED COMMIT FAILURE ",store.fail_commit)
		KEY_F1:get_window().size=Vector2i(1280,720)
		KEY_F2:get_window().size=Vector2i(640,360)
