extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	var driver = preload("res://review_driver.gd").new()
	root.add_child(driver)
	if not driver.bind(current_scene):
		push_error("Dock preview bind failed: " + current_scene.last_error)
		quit(1)
		return
	print("DOCK029 READY. 1 ramp, 2–4 plank aim, 5 fill span, 6 freeze span aim, 7 latch, 8 shutter, 9 rudder aim, J fill jig, B freeze jig aim, R recipe, M melt jig aim, L launch, N Finn, X dock, P Professor. F5/F9 save/Continue, T save failure, K fall.")
	if "--smoke" in OS.get_cmdline_user_args():
		quit()
