@tool
extends Node2D
## Scene-owned level settings. Positions live in child markers and Actors nodes.
@export var level_title := ""
@export var waypoint_names: Array[String] = []
@export var circuit_specialties: Array[String] = []


func propKind(prop: Node) -> String:
	if prop.has_meta("propKind"):
		return str(prop.get_meta("propKind"))
	return str(prop.get("kind"))


func cellAt(at: Vector2) -> Vector2i:
	return Vector2i(roundi(at.x / 80.0 + at.y / 40.0), roundi(at.y / 40.0 - at.x / 80.0))


func markerPosition(path: String) -> Vector2:
	return get_parent().to_local(get_node(path).global_position)


func propCells(level: Node, prefix: String) -> Array:
	var result: Array = []
	while level.props.has(prefix + str(result.size())):
		result.append(cellAt(level.props[prefix + str(result.size())].position))
	return result


func readLevel(level: Node) -> void:
	level.props.clear()
	level.scenery_cells.clear()
	for prop in level.get_node("Actors").get_children():
		if prop.has_meta("layout_id"):
			level.props[str(prop.get_meta("layout_id"))] = prop
			if propKind(prop) in ["tree", "pine", "flowers", "shrub", "rock", "rubble", "pillar"]:
				level.scenery_cells[cellAt(prop.position)] = true
	level.SPAWN = cellAt(markerPosition("Spawn"))
	level.PROFESSOR_CELL = cellAt(level.props.professor.position)
	level.EXIT = cellAt(level.props.exit.position)
	level.AREAS.clear()
	for region in $Regions.get_children():
		level.AREAS.append(cellAt(level.to_local(region.global_position)))
	level.WAYPOINTS = propCells(level, "waypoint")
	level.WAYPOINT_LANDINGS.clear()
	for landing in $Landings.get_children():
		level.WAYPOINT_LANDINGS.append(cellAt(level.to_local(landing.global_position)))
	level.WAYPOINT_NAMES = waypoint_names.duplicate()
	level.unlocked_waypoints.resize(level.WAYPOINTS.size())
	level.unlocked_waypoints.fill(false)
	level.unlocked_waypoints[0] = true
	level.cloud_reveals.resize(level.WAYPOINTS.size())
	level.cloud_reveals.fill(false)
	level.CRYSTALS = propCells(level, "crystal")
	level.NOTES = propCells(level, "note")
	if level.SAVE_LEVEL <= 2:
		level.BRAZIERS = propCells(level, "brazier")
		level.ICE = propCells(level, "ice")
		for pair in [
			["WOOD", "wood"],
			["BLADES", "blades"],
			["VENT", "vent"],
			["MIRROR", "mirror"],
			["RECEIVER", "receiver"]
		]:
			level.set(pair[0], cellAt(level.props[pair[1]].position))
		level.RELAY_MIRRORS = [
			cellAt(level.props.mirror2.position), cellAt(level.props.mirror3.position)
		]
		level.mirror_direction = level.props.mirror.direction
		level.relay_directions.assign(
			[level.props.mirror2.direction, level.props.mirror3.direction]
		)
		if level.SAVE_LEVEL == 2:
			level.VALVES = propCells(level, "valve")
	elif level.SAVE_LEVEL == 3:
		level.ICE = []
		level.BRAZIERS = []
		for pair in [
			["COOLERS", "cooler"],
			["SLUICES", "sluice"],
			["POOLS", "pool"],
			["SOCKETS", "socket"],
			["CORES", "core"]
		]:
			level.set(pair[0], propCells(level, pair[1]))
		level.DIVERTER = cellAt(level.props.diverter.position)
	else:
		level.ICE = []
		level.BRAZIERS = []
		level.centers.assign(level.AREAS)
		level.controls.assign(propCells(level, "sluice"))
		level.rewards.assign(propCells(level, "altar"))
		level.title = level_title
		level.specialties.assign(circuit_specialties)


func readTerrain(level: Node) -> void:
	level.cells.clear()
	level.paths.clear()
	_readSnowGround(level)
	var channels: Array = []
	for layer in level.get_node("Terrain").get_children():
		if not layer is TileMapLayer:
			continue
		var channel: Array = []
		for tile_cell: Vector2i in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(tile_cell)
			var cell := cellAt(level.to_local(layer.to_global(layer.map_to_local(tile_cell))))
			level.cells[cell] = int(data.get_custom_data("ground_kind"))
			if data.get_custom_data("trail"):
				level.paths[cell] = true
			if level.cells[cell] == 2:
				channel.append(cell)
		if layer.has_meta("channel_index"):
			var index: int = layer.get_meta("channel_index")
			while channels.size() <= index:
				channels.append([])
			channels[index] = channel
		var redraw := onTerrainChanged.bind(level)
		if not layer.changed.is_connected(redraw):
			layer.changed.connect(redraw)
	if level.SAVE_LEVEL >= 3:
		level.crossings = channels


func _readSnowGround(level: Node) -> void:
	# Authored snow rows replace ground tiles visually, but still define walkable cells.
	var snow := level.get_node_or_null("Terrain/SnowSurface")
	if snow == null: return
	for row in snow.get_children():
		if not row is Polygon2D or not str(row.name).begins_with("SnowRow_"): continue
		var polygon := PackedVector2Array()
		var low := Vector2i(2147483647,2147483647)
		var high := Vector2i(-2147483648,-2147483648)
		for vertex in row.polygon:
			var point: Vector2 = level.to_local(row.to_global(vertex+row.offset))
			polygon.append(point)
			var cell := cellAt(point)
			low = low.min(cell)
			high = high.max(cell)
		for x in range(low.x-1,high.x+2):
			for y in range(low.y-1,high.y+2):
				var cell := Vector2i(x,y)
				if Geometry2D.is_point_in_polygon(level.iso(cell),polygon):
					level.cells[cell] = 0


func onTerrainChanged(level: Node) -> void:
	if Engine.is_editor_hint() and is_instance_valid(level) and level.is_inside_tree():
		readTerrain(level)
		level.queue_redraw()


func bindActors(level: Node) -> void:
	level.ice_bodies.clear()
	for index in range(level.ICE.size()):
		for child in level.props["ice%d" % index].get_children():
			if child is StaticBody2D:
				level.ice_bodies.append(child)
	if level.demonstration_mode:
		for body in level.get_node("Actors").find_children("*", "StaticBody2D", true, false):
			body.collision_layer = 0


func nearestRegion(level: Node, cell: Vector2i) -> int:
	var best := 0
	var distance := INF
	for index in range(level.AREAS.size()):
		var next := Vector2(cell - level.AREAS[index]).length_squared()
		if next < distance:
			distance = next
			best = index
	return best
