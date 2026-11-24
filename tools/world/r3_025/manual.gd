extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var driver=load("res://review_driver.gd").new();root.add_child(driver)
	if not driver.bind(current_scene):push_error("Mill manual bind failed");quit(1);return
	print("MANUAL025 READY: shared WASD/touch/Run/Jump/Fire/context.1/2/3 bells;4/5/6 casing inspection;7/8/9 trays;B/N heavy/light;J takeoff;R return lever;P pin;I housing;X exit. H free help/Q optional question;F5 save/F9 Continue;K death;T save failure;F1/F2 sizes. Poses grant no progress. Disposable profile only.")
func _process(_delta: float) -> bool:
	if "--smoke" in OS.get_cmdline_user_args() and get_frame()>180:quit()
	return false
