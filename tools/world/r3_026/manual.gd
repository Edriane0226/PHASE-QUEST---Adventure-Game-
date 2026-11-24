extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var driver=load("res://review_driver.gd").new();root.add_child(driver)
	if not driver.bind(current_scene):push_error("Stillwater manual bind failed");quit(1);return
	print("MANUAL026 READY: WASD/touch, Run, Jump, Fire, context. Inspection poses:1 Professor;2 first tray;3 supply;4 valve;5 heater;6 left;7 right;8 latch;J secured left platform;X exit;Q question. F5 save/F9 Continue;K death;T save failure;F1/F2 viewport. Poses grant no progress. Disposable profile only.")
func _process(_delta: float) -> bool:
	if "--smoke" in OS.get_cmdline_user_args() and get_frame()>180:quit()
	return false
