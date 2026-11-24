extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	var world: Node=current_scene
	if not world.last_error.is_empty() or world.active_chunk()==null:
		push_error("Zone 1 fixture could not start: "+world.last_error)
		quit(1)
		return
	print("ZONE030 READY. Use the on-screen joystick, mode slots, Run, Jump, Fire and context Hand. The isolated profile resumes from disk when reopened.")
	if "--smoke" in OS.get_cmdline_user_args():quit()
