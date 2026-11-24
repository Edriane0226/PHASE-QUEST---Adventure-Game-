extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	var world = current_scene
	var profile = root.get_node("PlayerSave")
	print("Device fixture: ", profile.device_state())
	for station in world.models[0].data.stations:
		if station.subregion != "Z1L5" or not station.id.contains(".court"):
			continue
		var at: Vector2 = world.models[0].v(station.ground_xy)
		print(station.id, " ", at, " ", station.required_groups)
		for y in range(-100, 101, 10):
			var line := ""
			for x in range(-120, 121, 10):
				var point := at + Vector2(x, y)
				var h: Dictionary = world.raised_surface(point)
				line += "." if not world.valid_landing(point) else str(int(h.height / 20))
			print(y, " ", line)
	print("WORKSHOP028 PASS placement probe")
	quit()
