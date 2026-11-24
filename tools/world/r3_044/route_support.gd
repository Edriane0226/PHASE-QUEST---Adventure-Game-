extends RefCounted

const TOUCH = preload("res://touch_route.gd")
const HANDOFF = preload("res://handoff.gd")
const ROUTES := HANDOFF.ROUTES
const WORLD := "res://World/Navigation/ConnectedWorld.tscn"
const LIFT := "Z2L6--Z3L1"

static func prepare(world: Node, level: int, check: Callable) -> bool:
	var profile := world.get_node("/root/PlayerSave")
	var previous := "Z3L%d" % maxi(1,level-1)
	var location := "Z3L%d" % level
	if not check.call(world.active_subregion_id == previous and profile.total_stars() == 11+level
			and world.access.allowed(location) and not world.access.completed(location),
			"cold earned entry saves and unlocks only the current district"):
		return false
	if level < 6:
		return HANDOFF.locked_border(world,"Z3L%d" % (level+1),check)
	return check.call(world.connections.size() == 17 and profile.ZONES.size() == 3,"three-zone terminal district")

static func points(world: Node, source: String, destination: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	for row in data.routes:
		if row.id == source+"--"+destination or row.id == destination+"--"+source:
			for xy in row.points:
				result.append(Vector2(xy[0],xy[1]))
			if row.id.begins_with(destination+"--"):
				result.reverse()
			break
	while result.size() > 1 and (world.access.region_at(result.front()) != source or not world.valid_landing(result.front())):
		result.pop_front()
	while result.size() > 1 and (world.access.region_at(result.back()) != destination or not world.valid_landing(result.back())):
		result.pop_back()
	return result

static func walk_connection(tree: SceneTree, world: Node, source: String, destination: String, check: Callable) -> bool:
	var trail := points(world,source,destination)
	if not check.call(trail.size() > 1 and world.active_subregion_id == source and world.activate(source,trail.front()),
			"supported return trail from "+source):
		return false
	var touch := TOUCH.new(tree,world)
	var actor: Node = world.player
	var hud: Node = world.hud
	var falls: int = world.fall_count
	for at in trail.slice(1):
		if not await touch._walk_segment(at,4.0) and not await touch.go(at):
			if not await touch.go(trail.back()):
				return check.call(false,"walk return trail past "+str(at))
			break
	await touch.ticks(5)
	print("ZONE044 WALK ",source," → ",destination," ","%.1f" % touch.walked," wu")
	var profile := world.get_node("/root/PlayerSave")
	return check.call(world.active_subregion_id == destination and profile.world_record().active_subregion == destination
		and world.player == actor and world.hud == hud and world.fall_count == falls,"walk return to "+destination)
