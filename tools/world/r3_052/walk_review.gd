extends RefCounted
## Use the previously measured route to drive the HUD. Runtime map layout is scene-owned.
static func walk(touch: RefCounted, from: String, to: String) -> bool:
	var world: Node = touch.world
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
	var path: Array = []
	for route in source.routes:
		if route.id==from+"--"+to:
			path=route.points
			break
		if route.id==to+"--"+from:
			path=route.points.duplicate()
			path.reverse()
			break
	if path.is_empty():return false
	var origin := Vector2(path[0][0],path[0][1])
	var profile := world.get_node("/root/PlayerSave")
	if not world.activate(from,origin) or not profile.enter_world_subregion(world,from):return false
	await touch.ticks()
	var falls: int = world.fall_count
	for xy in path:
		var at := Vector2(xy[0],xy[1])
		if not await touch._walk_segment(at,4.0) and not await touch.go(at):return false
	return world.active_subregion_id==to and falls==world.fall_count
