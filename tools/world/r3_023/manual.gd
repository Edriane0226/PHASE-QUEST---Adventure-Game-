extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var driver=load("res://review_driver.gd").new();root.add_child(driver)
	if not driver.bind(current_scene):push_error("Fixture adapter bind failed");quit(1);return
	print("MANUAL023: 1 control / 2 pipe / 3 part / 4 socket then E or touch Use; I interior / O exterior; L lesson; F1/F2 size; F5 save/F9 Continue; K death; T failed save; C authored completion; F8 four-mode fixture. Real WASD/Run/Jump/Fire retained. Disposable profile only.")
