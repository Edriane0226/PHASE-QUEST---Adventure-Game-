extends SceneTree
var world: Node
var selected:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene
	var profile=root.get_node("PlayerSave");profile.fire_probe=true;profile.set_completed_prefix(18);await physics_frame;visit(false)
	print("MANUAL022: 1/2/3 room; I inside / O doorway; F1/F2 desktop/phone; F3 isolated Fire mode; C cargo; F5 save / F9 Continue; T checkpoint-order fixture; K checkpoint death; +/- isolated unlock prefix. WASD/Run/Jump/Fire/HUD retained. Disposable profile only.")
func visit(inside: bool) -> void:
	var room=world.room_cutaway.rooms[selected]
	world.activate(room.subregion_id,room.point(Vector2(room.size_cubes.x-3,3.5) if inside else Vector2(room.size_cubes.x+2,3.5)))
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or world==null:return
	var profile=root.get_node("PlayerSave")
	match event.keycode:
		KEY_1: selected=0;visit(false)
		KEY_2: selected=1;visit(false)
		KEY_3: selected=2;visit(false)
		KEY_I:visit(true)
		KEY_O:visit(false)
		KEY_C:world.player.carrying=not world.player.carrying
		KEY_F1:root.size=Vector2i(1280,720);root.content_scale_size=root.size
		KEY_F2:root.size=Vector2i(640,360);root.content_scale_size=root.size
		KEY_F3:
			var modes: Array=["thermal","cryo","vacuum","pressure"];profile.probe_mode=modes[(modes.find(profile.probe_mode)+1)%4];profile.changed.emit();print("Isolated noncommitting Fire probe: ",profile.probe_mode)
		KEY_F5:profile.save_world_location(world)
		KEY_F9:profile.load_profile();world.restore_saved_world(world.access)
		KEY_K:world.dead=true;world.recover_world_checkpoint(world.access)
		KEY_T:
			if profile.enter_world_subregion(world,world.active_subregion_id):
				profile.data.active_run.state.checkpoint_progress={"version":1,"unlock_sequence":["C0","C2","C1"]};profile.save_profile();print("Fixture unlock C0 -> C2 -> C1; K must restore C1")
		KEY_MINUS:profile.set_completed_prefix(maxi(0,profile.data.completed.size()-1))
		KEY_EQUAL:profile.set_completed_prefix(mini(18,profile.data.completed.size()+1))
