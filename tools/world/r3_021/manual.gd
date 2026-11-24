extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn");await scene_changed
	var driver:=Node.new();driver.set_script(load("res://manual_driver.gd"));root.add_child(driver)
	print("MANUAL021: real title controls; F1/F2 viewport;1/2/3 saved-zone menu fixtures;R fresh no-Continue fixture. All storage isolated. Future-zone Continue remains blocked at world entry.")
