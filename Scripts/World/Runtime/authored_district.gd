extends "res://Scripts/World/Runtime/world_chunk.gd"
## Index scene-owned polygons and anchors for the shared terrain and puzzle systems.
const TERRACES = preload("res://Scripts/World/puzzle_terraces.gd")
const RELIEF = preload("res://Scripts/World/terrain_relief.gd")
var geometry: RefCounted
var source_bodies: Dictionary = {}
var gate_bodies: Array = []
var permission_bodies: Array = []
var anchors: Dictionary = {}

func permission_polygon() -> PackedVector2Array:
	return world_polygon($Layout/Boundary)

func append_geometry(model: RefCounted) -> void:
	geometry = model
	var boundary := permission_polygon()
	model.region_polygons.append(boundary)
	model.data.regions.append({"id":subregion_id,"entry":coordinates($Layout/Checkpoints/C0.global_position),
		"permission_polygon":points(boundary),"elevation":$Layout/Boundary.get_meta("elevation")})
	for marker in $Layout/Stations.get_children():
		var station: Dictionary = marker.get_meta("station").duplicate()
		station.ground_xy = coordinates(marker.global_position)
		model.data.stations.append(station)
		marker.set_meta("kind",station.kind)
		anchors[station.id] = marker
	for marker in $Layout/Equipment.get_children():
		var equipment: Dictionary = marker.get_meta("equipment").duplicate()
		equipment.at = coordinates(marker.global_position)
		model.data.equipment.append(equipment)
	for marker in $Layout/Exploration.get_children():
		model.data.exploration_stops.append({"id":str(marker.name),"ground_xy":coordinates(marker.global_position)})
	model.data.local_branches.append_array(read_routes($Layout/Routes/Trails))
	model.data.review_routes.append_array(read_routes($Layout/Routes/Reviewed))
	for chamber in read_routes($Layout/Routes/Chambers):
		model.data.chambers.append({"service_loop":chamber.points})
	if has_node("Layout/ProtectedSource"):
		model.data.sources.append(legacy_layout())
	for floor in $Layout/Floors.get_children():
		var polygon := world_polygon(floor)
		var kind: String = floor.get_meta("kind")
		model.add_floor(polygon, subregion_id, kind, floor.get_meta("height",0.0), floor.get_meta("conditional",false), floor.get_meta("body_path",""))
		if kind == "bridge":model.bridges.append(polygon)
	for body in $Collision.find_children("*", "StaticBody2D", true, false):
		if body.get_meta("permission_edge", false):
			permission_bodies.append(body)
		else:
			index_collision(body)
	$Layout.hide()

static func prepare_terrain(model: RefCounted) -> void:
	model.terraces = TERRACES.new()
	model.terraces.configure(model)
	model.relief = RELIEF.new()
	model.relief.build(model, false)

func legacy_layout() -> Dictionary:
	var jumps: Array = []
	for jump in $Layout/JumpPractice.get_children():
		var takeoff := world_polygon(jump.get_node("Takeoff"))
		var landing := world_polygon(jump.get_node("Landing"))
		jumps.append({"id":str(jump.name),"takeoff":points(takeoff,-ground_origin),"landing":points(landing,-ground_origin),
			"from":coordinates(jump.get_node("From").global_position-ground_origin),
			"toward":coordinates(jump.get_node("Toward").global_position-ground_origin)})
	var conditional: Array = []
	for floor in $Layout/ConditionalSupport.get_children():
		conditional.append({"source_path":floor.get_meta("source_path"),"polygon":points(world_polygon(floor),-ground_origin)})
	return {"subregion":subregion_id,"protected_envelope":points(world_polygon($Layout/ProtectedSource)),
		"portal_routes":read_routes($Layout/Routes/Portals),"jumps":jumps,"conditional_floors":conditional}

func index_collision(body: StaticBody2D) -> void:
	var path: String = body.get_meta("source_path","")
	var gate: bool = body.get_meta("science_gate",false)
	if not path.is_empty() and not body.has_meta("portal_entry"):
		source_bodies[subregion_id + ":" + path] = body
	for shape in body.get_children():
		if not shape is CollisionPolygon2D or shape.disabled:continue
		geometry.add_blocker(world_polygon(shape),subregion_id,body.collision_layer,gate,path)
		var record: Dictionary = geometry.blockers.back()
		record.original_layer = body.collision_layer
		if body.has_meta("station"):
			record.station = body.get_meta("station")
			record.body = body
		if gate:
			gate_bodies.append({"region":subregion_id,"body":body,"layer":body.collision_layer,
				"portal_entry":body.get_meta("portal_entry",false),"record":record})

func height_record(local: Vector2, _margin:=0.0) -> Dictionary:
	var at := local + ground_origin
	return geometry.height_record(at) if geometry and geometry.region_at(at)==subregion_id else {}

func ground_polygons() -> Array:
	var result: Array = []
	for floor in geometry.floors:
		if floor.region==subregion_id and (not floor.conditional or geometry.science_open):result.append(floor.polygon)
	return result

func set_nearby(nearby: bool) -> void:
	visible = nearby
	process_mode = Node.PROCESS_MODE_INHERIT if nearby else Node.PROCESS_MODE_DISABLED

static func world_polygon(node: Node2D) -> PackedVector2Array:
	return node.global_transform * node.polygon

static func read_routes(group: Node2D) -> Array:
	var records: Array = []
	for line in group.get_children():
		records.append({"id":str(line.name),"points":points(line.global_transform * line.points)})
	return records

static func points(polygon: PackedVector2Array, offset := Vector2.ZERO) -> Array:
	var result: Array = []
	for point in polygon:result.append(coordinates(point+offset))
	return result

static func coordinates(point: Vector2) -> Array:
	return [point.x, point.y]
