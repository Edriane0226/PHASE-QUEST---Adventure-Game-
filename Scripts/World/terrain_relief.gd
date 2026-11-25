extends RefCounted
## Deterministic, additive landforms. Authored routes/source floors remain authoritative.
const CUBE_STEP_PX := 20
const CUBE_UNIT_PX := 20
const MAX_HEIGHT := 3
## Landforms are whole blocks of 3x3 cells: no single bumps, and edges run at least three cells.
const BLOCK := 3
## From the centre of a block to its farthest corner.
const BLOCK_REACH := 60.0
const TILE_SIZE := Vector2i(40, 20)
const SEED := 19017
const BIN := 256.0
var columns: Dictionary = {}
var foundations: Dictionary = {}
var regions: Dictionary = {}
var features: Array = []
var _reserves: Dictionary = {}
var _noise := FastNoiseLite.new()

static func center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x-cell.y)*20, (cell.x+cell.y)*10)

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x/40.0+point.y/20.0), roundi(point.y/20.0-point.x/40.0))

static func block_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x/float(BLOCK)),floori(cell.y/float(BLOCK)))

## Hills and slopes change level on groups of 2x2 blocks, so ledges are long and few.
static func ledge_center(at: Vector2) -> Vector2:
	var block := block_of(cell_at(at))
	return center(Vector2i(floori(block.x/2.0),floori(block.y/2.0))*BLOCK*2+Vector2i(3,3))

static func block_center(block: Vector2i) -> Vector2:
	return center(block*BLOCK+Vector2i.ONE)

func _reserve(a: Vector2, b: Vector2, radius: float) -> void:
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(radius+80)
	var record := {"a":a, "b":b, "radius":radius}
	for x in range(floori(box.position.x/BIN), floori(box.end.x/BIN)+1):
		for y in range(floori(box.position.y/BIN), floori(box.end.y/BIN)+1):
			var key := Vector2i(x,y)
			if not _reserves.has(key): _reserves[key] = []
			_reserves[key].append(record)

func _line(points: Array, radius: float) -> void:
	for i in range(1, points.size()):
		_reserve(Vector2(points[i-1][0],points[i-1][1]), Vector2(points[i][0],points[i][1]), radius)

func clearance(at: Vector2) -> float:
	var distance := 1000.0
	for r in _reserves.get(Vector2i(floori(at.x/BIN),floori(at.y/BIN)), []):
		distance = minf(distance, at.distance_to(Geometry2D.get_closest_point_to_segment(at,r.a,r.b))-r.radius)
	return distance

func build(model: RefCounted, read_review_routes:=true) -> void:
	columns.clear(); foundations.clear(); regions.clear(); features.clear(); _reserves.clear()
	_noise.seed = SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = .0016
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 2
	for s in model.data.stations:
		var at: Vector2 = model.v(s.ground_xy); _reserve(at,at,190)
	for s in model.data.exploration_stops:
		var at: Vector2 = model.v(s.ground_xy); _reserve(at,at,145)
	for e in model.data.get("equipment",[]):
		var at: Vector2 = model.v(e.at); _reserve(at,at,170)
	for branch in model.data.local_branches: _line(branch.points,140)
	for trail in model.data.trails: _line(trail.sampled_points,160)
	for source in model.data.get("sources",[]):
		for portal in source.portal_routes: _line(portal.points,190)
	for chamber in model.data.get("chambers",[]): _line(chamber.service_loop,170)
	if read_review_routes:
		for path in ["res://World/Data/navigation-routes.json", "res://World/Data/zone%s-routes.json" % str(model.data.regions[0].id).substr(1,1)]:
			if not FileAccess.file_exists(path): continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				for route in data.get("routes",[]): _line(route.points,160)
	else:
		for route in model.data.get("review_routes",[]): _line(route.points,160)
	for r in model.data.regions:
		var at: Vector2 = model.v(r.entry); _reserve(at,at,230)
	for reserve in model.data.get("travel_reserves",[]):
		var at: Vector2 = model.v(reserve.local_anchor); _reserve(at,at,250)
	var blocks: Dictionary = {}
	for r in model.data.regions:
		var polygon: PackedVector2Array = model.polygon(r.permission_polygon)
		var box: Rect2 = model.box_of(polygon)
		var corners := [cell_at(box.position),cell_at(box.end),cell_at(Vector2(box.end.x,box.position.y)),cell_at(Vector2(box.position.x,box.end.y))]
		var bounds := Rect2(Vector2(block_of(corners[0])),Vector2.ZERO)
		for c: Vector2i in corners: bounds = bounds.expand(Vector2(block_of(c)))
		var owned: Array = []
		for x in range(floori(bounds.position.x)-1,ceili(bounds.end.x)+2):
			for y in range(floori(bounds.position.y)-1,ceili(bounds.end.y)+2):
				var block := Vector2i(x,y); var point := block_center(block)
				if not box.has_point(point) or not Geometry2D.is_point_in_polygon(point,polygon): continue
				# Flat interior base: no raised cube skirts at coasts or ownership seams.
				var edge := INF
				for j in range(polygon.size()): edge = minf(edge,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[j],polygon[(j+1)%polygon.size()])))
				if edge < 370+BLOCK_REACH or clearance(point) < 85+BLOCK_REACH: continue
				var footprint := Rect2(point-Vector2(TILE_SIZE)*BLOCK*.5,Vector2(TILE_SIZE)*BLOCK)
				var support: Array = []; var seen: Dictionary = {}; var unsafe := false
				for bin in model.cells(footprint):
					for id in model.floor_bins.get(bin,[]):
						if seen.has(id): continue
						seen[id] = true
						var f: Dictionary = model.floors[id]
						if not f.bounds.intersects(footprint): continue
						if f.kind != "mainland": unsafe = true; break
						support.append(f.polygon)
					if unsafe: break
				if unsafe or not model.SUPPORT.rectangle_supported(footprint,support): continue
				# Original protected envelopes stay empty, including their overhead silhouette.
				for source in model.data.get("sources",[]):
					if not Geometry2D.intersect_polygons(model.rect_poly(footprint.grow(200)),model.polygon(source.protected_envelope)).is_empty(): unsafe = true; break
				if unsafe: continue
				blocks[block] = {"region":str(r.id),"base":model.base_height_mainland(point),"height":0}
				owned.append(block)
		regions[r.id] = owned
	# Steps from the flat land. Every rise is one cube per block, so it stays walkable.
	var distance: Dictionary = {}; var queue: Array = []
	var neighbors := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	for block: Vector2i in blocks:
		for offset: Vector2i in neighbors:
			if not blocks.has(block+offset): distance[block] = 0; queue.append(block); break
	var cursor := 0
	while cursor < queue.size():
		var block: Vector2i = queue[cursor]; cursor += 1
		for offset: Vector2i in neighbors:
			var next := block+offset
			if blocks.has(next) and not distance.has(next): distance[next] = distance[block]+1; queue.append(next)
	# Ridges and valleys follow the noise, not the outline of the free ground.
	for block: Vector2i in blocks:
		var p := ledge_center(block_center(block))
		var ridge := _noise.get_noise_2d(p.x,p.y*2.0)
		var limit := int(distance.get(block,0))
		# The lowest limit of the group, so a group never breaks into single blocks.
		var group := Vector2i(floori(block.x/2.0),floori(block.y/2.0))*2
		for dx in 2:
			for dy in 2: limit = mini(limit,int(distance.get(group+Vector2i(dx,dy),0)))
		blocks[block].height = mini(clampi(roundi(.8+ridge*3.2),0,MAX_HEIGHT),limit)
	_bowl(blocks,distance)
	for block: Vector2i in blocks:
		for dx in BLOCK:
			for dy in BLOCK: columns[block*BLOCK+Vector2i(dx,dy)] = blocks[block].duplicate()
	for cell: Vector2i in columns:foundations[cell]=columns[cell].base
	for cell: Vector2i in columns:
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			if not foundations.has(cell+offset):foundations[cell+offset]=model.base_height_mainland(center(cell+offset))

## At most one broad depression in a zone, in its largest free ground. Solid floor, never a trap.
func _bowl(blocks: Dictionary, distance: Dictionary) -> void:
	var best := Vector2i.ZERO; var depth := 0
	for block: Vector2i in blocks:
		if int(distance.get(block,0)) > depth: best = block; depth = distance[block]
	if depth < 3: return
	var at := block_center(best); var radius := minf(300,depth*70.0)
	features.append({"region":blocks[best].region,"kind":"terraced bowl","center":at,"radius":radius})
	for block: Vector2i in blocks:
		if blocks[block].region != blocks[best].region: continue
		var offset := block_center(block)-at
		var d := Vector2(offset.x,offset.y*2.0).length()/radius
		if d > 1.6: continue
		var rim := 2.0*smoothstep(.3,.8,d)*(1.0-smoothstep(1.1,1.6,d))
		blocks[block].height = mini(roundi(rim),int(distance[block]))

func height_at(point: Vector2) -> float:
	var column: Dictionary = columns.get(cell_at(point),{})
	return float(column.base)+int(column.height)*CUBE_STEP_PX if not column.is_empty() else -INF

func clustered_decorations(model: RefCounted) -> Array:
	# Reuse owned art. Noise patches replace uniform scatter density; no interactive props.
	var result: Array = []
	var zone: String = str(model.data.regions[0].id).substr(1,1)
	var assets: Array = ["snow_shrub","snow_tuft"] if zone == "1" else ["flowers"] if zone == "2" else []
	if assets.is_empty(): return result
	for cell: Vector2i in columns:
		var column: Dictionary = columns[cell]
		if column.height > 3 or posmod(cell.x*73+cell.y*137,37) != 0: continue
		var point := center(cell)+Vector2(11,-3)
		if _noise.get_noise_2d(point.x+4200,point.y-900) < .05: continue
		if not model.blocked_box(Rect2(point-Vector2(35,35),Vector2(70,70))):
			result.append({"asset":assets[posmod(cell.x+cell.y,assets.size())],"at":point})
	return result
