extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var driver=load("res://review_driver.gd").new();root.add_child(driver)
	if not driver.bind(current_scene):push_error("Garden manual fixture bind failed");quit(1);return
	print("MANUAL024 READY: real movement/Jump/Fire/context;1 first barrier inspection pose;2 fuel;3 heater;4 blades;5 fan;6/7/8 mirrors. F1/F2 viewport;L lesson;F5 save/F9 Continue;K checkpoint;T save failure. Disposable manual.save only. Route acceptance remains030.")
func _process(_delta: float) -> bool:
	if "--smoke" in OS.get_cmdline_user_args() and get_frame()>180:quit()
	return false
