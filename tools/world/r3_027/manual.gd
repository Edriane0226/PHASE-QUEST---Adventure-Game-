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
		push_error("Canal bind failed: " + str(driver.provider.last_error if driver.provider else current_scene.last_error))
		quit(1)
		return
	print("CANAL027 READY. 1 intake, 2 diverter, 3 divider, 4 side aim, 5 side bank, 6 wrong lock, 7 pickup, 8 socket, 9 refreeze, 0 latch, B bridge bank, X exit. F5/F9 save/Continue, K fall, T save failure, F1/F2 size.")
	if "--smoke" in OS.get_cmdline_user_args():
		quit()
