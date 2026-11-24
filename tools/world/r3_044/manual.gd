extends SceneTree

const ROUTE = preload("res://route_support.gd")
var driver: Node
var bound_id := ""

class ReviewTravel extends Node:
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo: return
		var world := get_parent()
		if not world.input_adapter.modal.is_empty() or world.player.carrying or not world._transit.is_empty(): return
		var from: String = world.active_subregion_id
		if event.physical_keycode == KEY_F6 and from in ["Z3L1","Z2L6"]:
			var lift: Dictionary = world.connection(ROUTE.LIFT)
			var xy: Array = lift.destination_anchor if from == "Z3L1" else lift.source_anchor
			world.activate(from,Vector2(xy[0],xy[1]))
		elif event.physical_keycode in [KEY_F7,KEY_F8] and from.begins_with("Z3"):
			var level := int(from.right(1))
			var next: int = level + (1 if event.physical_keycode == KEY_F8 else -1)
			if next not in range(1,7): return
			var destination := "Z3L%d" % next
			var trail := ROUTE.points(world,from,destination)
			if trail.size() < 2 or not world.access.allowed(destination): return
			if world.activate(from,trail.front()):
				print("Trail ",from," to ",destination," waypoints ",trail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540)
	root.content_scale_size = root.size
	scene_changed.connect(scene_ready)
	change_scene_to_file(ROUTE.WORLD)
	await scene_changed
	await physics_frame
	await process_frame
	if current_scene.active_subregion_id.begins_with("Z3") and is_instance_valid(driver):
		if "--smoke" in OS.get_cmdline_user_args() and current_scene.active_subregion_id == "Z3L6":
			if not await smoke_rebind():
				push_error("Manual review controls failed to rebind after travel.")
				quit(1)
				return
		print("ZONE044 READY")
		if "--smoke" in OS.get_cmdline_user_args(): quit()
	elif current_scene.active_subregion_id == "Z2L6" and "--smoke" not in OS.get_cmdline_user_args():
		print("ZONE044 READY at Skybridge")
	else:
		push_error("Could not bind the Zone 3 manual fixture.")
		quit(1)

func scene_ready() -> void:
	if current_scene.scene_file_path != ROUTE.WORLD: return
	bound_id = ""
	current_scene.subregion_changed.connect(bind_district,CONNECT_DEFERRED)
	current_scene.add_child(ReviewTravel.new())
	call_deferred("bind_district",current_scene.active_subregion_id)

func smoke_rebind() -> bool:
	var profile := root.get_node("PlayerSave")
	var previous := "Z3L5"
	if not current_scene.activate(previous,profile.WORLD_SAVE.anchor(previous,"C0")):
		return false
	if not profile.enter_world_subregion(current_scene,previous):
		return false
	await process_frame
	await physics_frame
	return bound_id == previous and is_instance_valid(driver) and driver.room.active()

func bind_district(id: String) -> void:
	if current_scene == null or current_scene.scene_file_path != ROUTE.WORLD: return
	if is_instance_valid(driver):
		if bound_id == id and driver.get_parent() == current_scene: return
		driver.set_process_input(false)
		driver.queue_free()
	bound_id = ""
	if not id.begins_with("Z3"): return
	var script: GDScript = load("res://Checks/%s/review_driver.gd" % id.right(1))
	driver = script.new()
	current_scene.add_child(driver)
	if not driver.bind(current_scene):
		driver.set_process_input(false)
		driver.queue_free()
		return
	bound_id = id
