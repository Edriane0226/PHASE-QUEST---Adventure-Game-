extends Node
## Real support cuts and permanent rails within reserved crossing courts.
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const OPEN_WATER := Color("457589")
const ISOLATED_WATER := Color("648fa0")
const SOLID := Color("b6dce3")
var model: RefCounted
var spans: Dictionary = {}
var region := ""
var _rail_prefix := ""
var _original_floors: Array = []
var _anchors: Array[Node2D] = []
var _bodies: Array[StaticBody2D] = []

func install(world: Node2D, chunk: Node2D, points: Dictionary, centers: Dictionary = {}) -> bool:
	region = chunk.subregion_id
	model = world.geometry.region_models[region]
	_rail_prefix = region + ":CrossingRail:"
	var sites := centers if not centers.is_empty() else {"side":points.court2, "bridge":points.court3}
	for id in sites:
		var center: Vector2 = sites[id]
		var gap := Rect2(center + Vector2(-54, -37), Vector2(128, 74))
		var height: float = world.raised_surface(center).get("height", -1)
		for offset in [Vector2(-72, -22), Vector2(-72, 22), Vector2(88, -22), Vector2(88, 22), Vector2.ZERO]:
			var point: Vector2 = center + offset
			if not world.geometry.standable(point, false, true, false) or world.raised_surface(point).get("height") != height:
				return false
		spans[id] = {"gap":gap, "height":height, "center":center, "solid":false}
	_original_floors = model.floors.filter(func(record): return record.region == region)
	for id in spans:
		var span: Dictionary = spans[id]
		_build_span(world, chunk, id, span)
	var floors: Array = []
	for record in model.floors:
		if record.region != region:
			floors.append(record)
			continue
		var fragments: Array = [record.polygon]
		for span in spans.values():
			var next: Array = []
			for fragment in fragments:
				next.append_array(_cut(fragment, span.gap))
			fragments = next
		for polygon in fragments:
			var piece: Dictionary = record.duplicate()
			piece.polygon = polygon
			piece.bounds = model.box_of(polygon)
			floors.append(piece)
	_index_floors(floors)
	return true

func _cut(polygon: PackedVector2Array, gap: Rect2) -> Array:
	var bounds: Rect2 = model.box_of(polygon)
	if not bounds.intersects(gap) or Geometry2D.intersect_polygons(polygon, model.rect_poly(gap)).is_empty():
		return [polygon]
	# Partition the outside of the rectangle. A polygon subtraction that
	# returns a hole contour would put phantom support back into the water.
	var x0 := maxf(bounds.position.x, gap.position.x)
	var x1 := minf(bounds.end.x, gap.end.x)
	var bands := [
		Rect2(bounds.position, Vector2(x0 - bounds.position.x, bounds.size.y)),
		Rect2(Vector2(x1, bounds.position.y), Vector2(bounds.end.x - x1, bounds.size.y)),
		Rect2(Vector2(x0, bounds.position.y), Vector2(x1 - x0, gap.position.y - bounds.position.y)),
		Rect2(Vector2(x0, gap.end.y), Vector2(x1 - x0, bounds.end.y - gap.end.y)),
	]
	var result: Array = []
	for band: Rect2 in bands:
		if band.size.x > .001 and band.size.y > .001:
			for piece in Geometry2D.intersect_polygons(polygon, model.rect_poly(band)):
				if piece.size() >= 3:
					result.append(piece)
	return result

func _index_floors(records: Array) -> void:
	model.floors = []
	model.floor_bins = {}
	for record in records:
		model.index_record(record, model.floors, model.floor_bins)

func _build_span(world: Node2D, chunk: Node2D, id: String, span: Dictionary) -> void:
	var center: Vector2 = span.center
	var bed = ANCHOR.new()
	bed.position = center
	bed.elevation = span.height
	bed.z_index = -1
	world.get_node("GroundSort").add_child(bed)
	_anchors.append(bed)
	var water := Polygon2D.new()
	water.polygon = model.rect_poly(Rect2(span.gap.position - center, span.gap.size))
	water.color = OPEN_WATER
	bed.visuals.add_child(water)
	span.water = water
	# Side rails and back rail enclose the far controls. Layer 8 stays solid
	# during an ordinary jump. The open west end is the only entrance.
	for local: Rect2 in [Rect2(-64, -41, 170, 6), Rect2(-64, 35, 170, 6), Rect2(100, -41, 6, 82)]:
		var area := Rect2(center + local.position, local.size)
		model.add_blocker(model.rect_poly(area), region, 8, false, _rail_prefix + id)
		var body := StaticBody2D.new()
		body.position = area.get_center() - chunk.ground_origin
		body.collision_layer = 8
		body.collision_mask = 4
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = area.size
		collision.shape = shape
		body.add_child(collision)
		chunk.add_child(body)
		_bodies.append(body)
		var rail = ANCHOR.new()
		rail.position = area.get_center()
		rail.elevation = span.height
		world.get_node("GroundSort").add_child(rail)
		_anchors.append(rail)
		var beam := Polygon2D.new()
		beam.polygon = model.rect_poly(Rect2(-local.size / 2 - Vector2(0, 8), local.size + Vector2(0, 8)))
		beam.color = Color("576c70")
		rail.visuals.add_child(beam)

func present(id: String, supported: bool, color: Color) -> void:
	var span: Dictionary = spans[id]
	span.water.color = color
	if span.solid == supported:
		return
	span.solid = supported
	if supported:
		model.add_floor(model.rect_poly(span.gap), region, "bridge", span.height)
		model.floors[-1].canal_span = id
	else:
		_index_floors(model.floors.filter(func(record): return record.region != region or record.get("canal_span") != id))

func _exit_tree() -> void:
	if not _original_floors.is_empty():
		var retained: Array = model.floors.filter(func(record): return record.region != region)
		retained.append_array(_original_floors)
		_index_floors(retained)
		var blockers: Array = model.blockers.filter(func(record): return not str(record.source_path).begins_with(_rail_prefix))
		model.blockers = []
		model.blocker_bins = {}
		for record in blockers:
			model.index_record(record, model.blockers, model.blocker_bins)
	for anchor in _anchors:
		if is_instance_valid(anchor):
			anchor.queue_free()
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
