extends RefCounted

const ROUTES := "res://World/Data/navigation-routes.json"
const BOAT := "Z1L6--Z2L1"
const TOUCH = preload("res://touch_route.gd")

static func prepare(tree: SceneTree, world: Node, level: int, check: Callable) -> bool:
	var profile := tree.root.get_node("PlayerSave")
	var target := "Z2L%d" % level
	var start: String = world.active_subregion_id
	if not check.call(profile.total_stars() == 5+level and world.access.allowed(target),
			"earned prerequisite chain at "+target):
		return false
	if level == 1 and "--profile=migrated" in OS.get_cmdline_user_args():
		if not check.call(profile.classic_verified,"classic binary preserves Dock and earned records across migration"):
			return false
	var touch := TOUCH.new(tree,world)
	if start != target:
		if level == 1 and start == "Z1L6":
			if not await ride(touch,BOAT,false,check): return false
		elif start == "Z2L%d" % (level-1):
			if not await walk_connection(touch,start,target,check): return false
		else:
			return check.call(false,"unexpected saved start "+start+" for "+target)
		await touch.ticks()
	if not check.call(world.active_subregion_id == target and world.learning_provider().active()
			and profile.WORLD_SAVE.region_for_run(profile.data.active_run) == target,
			"live provider and saved attempt at "+target):
		return false
	var provider: Node = world.learning_provider()
	var lesson: Dictionary = provider.lesson("professor")
	var actor: Node2D = world.professors[1]
	if not check.call(lesson.role == "professor_z2" and lesson.name == "Professor Marisol Reed"
			and actor.position.distance_to(provider.points.professor) < 1.0,
			"Professor Marisol Reed at authored "+target+" anchor"):
		return false
	var next := "Z2L%d" % (level+1) if level < 6 else "Z3L1"
	return locked_border(world,next,check)

static func ride(touch: RefCounted, id: String, reverse: bool, check: Callable) -> bool:
	var world: Node = touch.world
	var route: Dictionary = world.connection(id)
	var from: String = route.destination if reverse else route.source
	var to: String = route.source if reverse else route.destination
	var anchor: Array = route.destination_anchor if reverse else route.source_anchor
	if not check.call(world.active_subregion_id == from and world.activate(from,Vector2(anchor[0],anchor[1])),
			"supported transport approach "+from):
		return false
	await touch.ticks()
	world.input_adapter.refresh()
	var context: Dictionary = world.active_chunk().context_record()
	var keys := [id + (".return" if reverse else ".forward")]
	if id == BOAT and not reverse:
		keys.append("Z1L6:exit")
	if not check.call(context.get("key") in keys
			and context.get("enabled",false),"earned transport Hand "+id):
		return false
	touch.tap(world.hud.controls.context.get_global_rect().get_center())
	await touch.wait(2.2)
	return check.call(world.active_subregion_id == to and world._transit.is_empty(),"transport arrived "+to)

static func walk_connection(touch: RefCounted, from: String, to: String, check: Callable) -> bool:
	var world: Node = touch.world
	var routes: Array = JSON.parse_string(FileAccess.get_file_as_string(ROUTES)).routes
	var desired := from+"--"+to
	var matches := routes.filter(func(row): return row.id == desired)
	if not check.call(matches.size() == 1,"authored route "+desired):
		return false
	var path: Array = matches[0].points
	var start := Vector2(path[0][0],path[0][1])
	if not check.call(world.access.region_at(start) == from and world.activate(from,start),"walk approach "+desired):
		return false
	await touch.ticks()
	var ids := [world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]
	var falls: int = world.fall_count
	var distance := 0.0
	for xy in path:
		var goal := Vector2(xy[0],xy[1])
		var previous: Vector2 = world.player.position
		if not await touch._walk_segment(goal,4.0):
			# Live apparatus can occupy a point from the earlier terrain-only route.
			# The existing collision-aware walker searches a supported detour.
			if not await touch.go(goal):
				return check.call(false,"cannot walk "+desired+" to "+str(goal))
		distance += previous.distance_to(world.player.position)
	touch.stop()
	await touch.ticks()
	print("WALK037 ",desired," ", "%.1f" % distance," wu")
	return check.call(world.active_subregion_id == to and world.fall_count == falls
		and ids == [world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()],
		"joystick crossing keeps actor, camera and HUD "+desired)

static func locked_border(world: Node, id: String, check: Callable) -> bool:
	var row: Dictionary = world.REGISTRY.definition(id)
	var at := Vector2(row.entry[0],row.entry[1])
	var bodies: Array = world.permissions.get(id,[])
	var cell: Vector2i = world.discovery.key_at(at)
	var mask: Color = world.map_provider.permission_image.get_pixelv(cell)
	return check.call(not world.access.allowed(id) and not world.access.point_allowed(at)
		and not world.activate(id,at) and not bodies.is_empty()
		and bodies.all(func(body): return body.collision_layer == 8) and mask.r < .1
		and not world.discovery.known(at),"next region blocked by permission, physics and fog "+id)
