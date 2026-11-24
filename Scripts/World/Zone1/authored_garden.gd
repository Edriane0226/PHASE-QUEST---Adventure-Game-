extends "res://Scripts/World/Runtime/world_chunk.gd"
## Read the editable Garden nodes into the existing geometry queries and terrain renderer.
const GARDEN_GEOMETRY = preload("res://Scripts/World/Zone1/zone1_geometry.gd")
const TERRACES = preload("res://Scripts/World/puzzle_terraces.gd")
const RELIEF = preload("res://Scripts/World/terrain_relief.gd")
var geometry: RefCounted
var source_bodies: Dictionary = {}
var gate_bodies: Array = []

func permission_polygon() -> PackedVector2Array:
	return _world_polygon($Layout/Boundary)

func build_geometry() -> RefCounted:
	geometry = GARDEN_GEOMETRY.new()
	var boundary := permission_polygon()
	var stations: Array = []
	for marker in $Layout/Stations.get_children():
		var station: Dictionary = marker.get_meta("station").duplicate()
		station.ground_xy = _coordinates(marker.global_position)
		stations.append(station)
	var stops: Array = []
	for marker in $Layout/Exploration.get_children():
		stops.append({"id":str(marker.name),"ground_xy":_coordinates(marker.global_position)})
	var source := {
		"subregion":subregion_id,
		"protected_envelope":_points(_world_polygon($Layout/ProtectedSource)),
		"portal_routes":_routes($Layout/Routes/Portals),
		"jumps":[]
	}
	for jump in $Layout/JumpPractice.get_children():
		var takeoff := _world_polygon(jump.get_node("Takeoff"))
		var landing := _world_polygon(jump.get_node("Landing"))
		for index in takeoff.size():takeoff[index] -= ground_origin
		for index in landing.size():landing[index] -= ground_origin
		source.jumps.append({"id":str(jump.name),"takeoff":_points(takeoff),"landing":_points(landing)})
	geometry.data = {
		"regions":[{"id":subregion_id,"entry":_coordinates($Layout/Checkpoints/C0.global_position),"permission_polygon":_points(boundary),"elevation":$Layout/Boundary.get_meta("elevation")}],
		"stations":stations,
		"exploration_stops":stops,
		"sources":[source],
		"trails":[],
		"local_branches":_routes($Layout/Routes/Trails),
		"review_routes":_routes($Layout/Routes/Reviewed)
	}
	geometry.region_polygons.append(boundary)
	for floor in $Layout/Floors.get_children():
		var polygon := _world_polygon(floor)
		var kind: String = floor.get_meta("kind")
		geometry.add_floor(polygon, subregion_id, kind, floor.get_meta("height",0.0), floor.get_meta("conditional",false), floor.get_meta("body_path",""))
		if kind == "bridge":geometry.bridges.append(polygon)
	for body in $Collision.find_children("*", "StaticBody2D", true, false):
		_index_collision(body)
	geometry.terraces = TERRACES.new()
	geometry.terraces.configure(geometry)
	geometry.relief = RELIEF.new()
	geometry.relief.build(geometry, false)
	return geometry

func _index_collision(body: StaticBody2D) -> void:
	var path: String = body.get_meta("source_path","")
	var gate: bool = body.get_meta("science_gate",false)
	var entry: bool = body.get_meta("portal_entry",false)
	if not path.is_empty() and not body.has_meta("portal_entry"):
		source_bodies[subregion_id + ":" + path] = body
	for shape in body.get_children():
		if not shape is CollisionPolygon2D or shape.disabled:continue
		var polygon := _world_polygon(shape)
		geometry.add_blocker(polygon, subregion_id, body.collision_layer, gate, path)
		var record: Dictionary = geometry.blockers.back()
		record.original_layer = body.collision_layer
		if gate:
			gate_bodies.append({"region":subregion_id,"body":body,"layer":body.collision_layer,"portal_entry":entry,"record":record})

func height_record(local: Vector2, _margin:=0.0) -> Dictionary:
	return geometry.height_record(local + ground_origin) if geometry else {}

func _world_polygon(node: Node2D) -> PackedVector2Array:
	return node.global_transform * node.polygon

func _routes(group: Node2D) -> Array:
	var records: Array = []
	for line in group.get_children():
		records.append({"id":str(line.name),"points":_points(line.global_transform * line.points)})
	return records

func _points(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for point in polygon:result.append(_coordinates(point))
	return result

func _coordinates(point: Vector2) -> Array:
	return [point.x, point.y]
