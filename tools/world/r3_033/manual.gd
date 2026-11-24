extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540)
	root.content_scale_size = root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	await process_frame
	var driver = preload("res://review_driver.gd").new()
	root.add_child(driver)
	if not driver.bind(current_scene):
		push_error("Dewglass startup failed: "+current_scene.last_error)
		quit(1)
		return
	print("DEWGLASS033 READY")
	if "--smoke" in OS.get_cmdline_user_args(): quit()
