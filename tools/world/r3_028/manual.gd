extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	var driver = load("res://review_driver.gd").new()
	root.add_child(driver)
	if not driver.bind(current_scene):
		push_error("Workshop bind failed: " + str(driver.provider.last_error if driver.provider else current_scene.last_error))
		quit(1)
		return
	print("WORKSHOP028 READY. 1/2 mirrors, 3 latch, 4 gate, 5 valve, 6 freeze aim, 7 rack, 8 melt aim, 9 drain, B drafting bench, X exit. F5/F9 save/Continue, K fall, T save failure, F1/F2 size.")
	if "--smoke" in OS.get_cmdline_user_args():
		quit()
