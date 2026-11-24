extends SceneTree
const PARTS = preload("res://Scripts/World/Zone1/canal_assembly.gd")
const ROOM = preload("res://Scripts/World/Runtime/modular_room.gd")
const SUPPORT = preload("res://Scripts/World/terrain_support_profiles.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn")
	await scene_changed
	await physics_frame
	var world = current_scene
	var profile = root.get_node("PlayerSave")
	print("Device fixture: ", profile.device_state())
	var points: Dictionary = {}
	for station in world.models[0].data.stations:
		if station.subregion != "Z1L4" or not station.id.contains(".court"):
			continue
		var at: Vector2 = world.models[0].v(station.ground_xy)
		points[station.id.get_slice(".", 1)] = at
		print(station.id, " ", at, " ", station.required_groups)
		for y in range(-100, 101, 10):
			var line := ""
			for x in range(-120, 121, 10):
				var point := at + Vector2(x, y)
				var h: Dictionary = world.raised_surface(point)
				line += "." if not world.valid_landing(point) else str(int(h.height / 20))
			print(y, " ", line)
	points.court1 += Vector2(24, -51)
	points.court2 += Vector2(23, 0)
	points.court3 += Vector2(0, -38)
	for site in PARTS.definition(points).assemblies:
		var origin := Vector2(site.origin_ground[0], site.origin_ground[1])
		var height: float = world.raised_surface(origin).get("height", -1)
		for spec in site.components:
			var size := Vector2(spec.footprint_cubes[0], spec.footprint_cubes[1])
			var mark := origin + ROOM.project(Vector2(spec.offset_cubes[0], spec.offset_cubes[1]))
			for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), size * .5]:
				var at := mark + ROOM.project(corner - size * .5)
				var actual: float = world.raised_surface(at).get("height", -1)
				if actual != height or not world.geometry.supported_box(SUPPORT.foot_rect(at)):
					print(site.id, "/", spec.id, " at ", at, " expected ", height, " saw ", actual)
	print("CANAL027 PASS placement probe")
	quit()
