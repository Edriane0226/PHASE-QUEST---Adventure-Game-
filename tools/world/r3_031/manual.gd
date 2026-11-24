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
		push_error("Sunlit fixture failed: " + current_scene.last_error)
		quit(1)
		return
	print("SUNLIT031 READY. P Professor; 1 canopy, 2 shutter, R reflector, 3 fill tray, 4 evaporation aim, 5 float, 6 fill boiler, 7 guard, 8 boiling aim, 9 wheel, M melt aim, L fill support, F freeze aim, S secure, H span west bank, X exit. F5/F9 save/Continue; K fall; B return boat.")
	if "--smoke" in OS.get_cmdline_user_args():
		quit()
