extends RefCounted
## Keep review commands on the same supported HUD movement path as player input.
const TOUCH = preload("res://tools/world/r3_030/touch_route.gd")

class RouteWalker extends TOUCH:
	func _supported(point: Vector2) -> bool:
		if world.player.carrying and world.access.region_at(point) != world.active_subregion_id:return false
		return world.valid_landing(point)

static func block_save(profile: Node, block: bool) -> void:
	var path: String = profile.save_path + ".tmp"
	var result := DirAccess.make_dir_absolute(path) if block else DirAccess.remove_absolute(path)
	assert(result == OK,"Could not set up the disposable write-failure test.")

static func reach(tree: SceneTree, world: Node, district: String, point: Vector2) -> bool:
	if district != world.active_subregion_id:
		return false
	if not world.valid_landing(point) or world.access.region_at(point) != district:
		return false
	if world.player.position.distance_to(point) < 5:
		return true
	var driver := RouteWalker.new(tree,world)
	return await driver.go(point) and world.active_subregion_id == district

static func cross(tree: SceneTree, world: Node, district: String) -> bool:
	var driver := RouteWalker.new(tree,world)
	return await driver.boundary(world.active_subregion_id,district)

static func leave_platform(tree: SceneTree, world: Node, direction: Vector2) -> bool:
	var driver := RouteWalker.new(tree,world)
	var origin: Vector2 = world.player.position
	var previous: Variant = world.raised_surface(origin).get("body_path")
	return await driver.jump(origin,direction) and world.raised_surface(world.player.position).get("body_path") != previous

static func leave_stream_deck(tree: SceneTree, world: Node) -> bool:
	if world.active_subregion_id != "Z2L4":return false
	var player_at: Vector2 = world.player.position
	if world.raised_surface(player_at).get("body_path") != "StreamExitDeck":return true
	var driver := RouteWalker.new(tree,world)
	var lift: Vector2 = world.learning_provider().points.lift
	if not await driver.jump(lift+Vector2(222,0),Vector2.LEFT) or world.raised_surface(world.player.position).get("body_path") != "StreamUpperLanding":return false
	if await driver._walk_segment(lift-Vector2(82,0),4):return true
	return await use_checkpoint(driver,"C1")

static func use_checkpoint(driver: RefCounted, checkpoint: String) -> bool:
	var world: Node = driver.world
	var id: String = world.active_subregion_id
	await driver.acknowledge()
	driver.tap(world.hud.rects.pause.get_center())
	await driver.ticks()
	var pause_items: Array = world.panels.buttons.filter(func(button):return button.name=="Intent_travel")
	if pause_items.is_empty() or not await driver.panel_button(pause_items[0]):return false
	var rows: Array = world.panels.model.get("rows",[])
	var index := rows.find_custom(func(row):return row.get("id")==checkpoint and row.get("enabled",false))
	var destinations: Array = world.panels.buttons.filter(func(button):return button.text=="Open")
	if index < 0 or index >= destinations.size() or not await driver.panel_button(destinations[index]):return false
	return world.input_adapter.modal.is_empty() and world.active_subregion_id==id \
		and world.player.position.distance_to(world.checkpoint_anchor(id,checkpoint))<5

static func board(tree: SceneTree, world: Node, id: String, reverse := false) -> bool:
	var route: Dictionary = world.connection(id)
	if route.is_empty():return false
	var district: String = route.destination if reverse else route.source
	var anchor: Array = route.destination_anchor if reverse else route.source_anchor
	var driver := RouteWalker.new(tree,world)
	var key := id + (".return" if reverse else ".forward")
	var wanted := func() -> bool:
		var action: Dictionary = world.active_chunk().context_record()
		return action.get("enabled",false) and (action.get("key") == key or (not reverse and action.get("key") == district + ":exit"))
	if world.active_subregion_id != district or not await driver.approach(Vector2(anchor[0],anchor[1]),wanted,[8,18,25,32,40]):
		return false
	world.input_adapter.refresh()
	driver.tap(world.hud.controls.context.get_global_rect().get_center())
	await driver.ticks()
	return not world._transit.is_empty()
