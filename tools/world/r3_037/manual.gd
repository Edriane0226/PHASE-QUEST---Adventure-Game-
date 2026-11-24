extends SceneTree

const WORLD := "res://World/Navigation/ConnectedWorld.tscn"
const ROUTES := "res://World/Data/navigation-routes.json"
const TRAIL_KEYS = preload("res://trail_keys.gd")
var driver: Node
var bound_id := ""
var trail := []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540)
	root.content_scale_size = root.size
	scene_changed.connect(_scene_ready)
	change_scene_to_file(WORLD)
	await scene_changed
	await physics_frame
	var world := current_scene
	if world.active_subregion_id not in ["Z1L6","Z2L1","Z2L2","Z2L3","Z2L4","Z2L5","Z2L6","Z3L1"]:
		push_error("Unexpected 037 manual location: "+world.active_subregion_id)
		quit(1)
		return
	if world.active_subregion_id.begins_with("Z2") and (not is_instance_valid(driver) or bound_id != world.active_subregion_id):
		push_error("037 district inspection keys did not bind.")
		quit(1)
		return
	print("ZONE037 READY")
	if "--smoke" in OS.get_cmdline_user_args(): quit()

func _scene_ready() -> void:
	if current_scene.scene_file_path != WORLD: return
	current_scene.subregion_changed.connect(_bind_district)
	call_deferred("_bind_district",current_scene.active_subregion_id)
	var keys := TRAIL_KEYS.new()
	keys.owner_tree = self
	current_scene.add_child(keys)

func _bind_district(id: String) -> void:
	if current_scene == null or current_scene.scene_file_path != WORLD: return
	if is_instance_valid(driver):
		if bound_id == id and driver.get_parent() == current_scene: return
		driver.set_process_input(false)
		driver.queue_free()
	bound_id = ""
	trail = []
	if not id.begins_with("Z2"): return
	var script: GDScript = load("res://Checks/%s/review_driver.gd" % id.right(1))
	driver = script.new()
	current_scene.add_child(driver)
	if not driver.bind(current_scene):
		driver.set_process_input(false)
		driver.queue_free()
		return
	bound_id = id
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	for route in data.routes:
		if route.id.begins_with(id+"--"):
			trail = route.points
			print("Trail ",route.id," begins at ",route.points[0]," and ends at ",route.points[-1])
