extends RefCounted
## R3 003 opt-in terrain geometry. No campaign state, scene mutation or resource I/O.
## Art bounds, ground support, projected cargo clearance and physics blockers are separate.
const VERSION := 1
const GRID := Vector2(80,40)
const STEP := 20.0
const PLAYER_FOOT := Vector2(20,22)
const LAYER_SOLID := 1
const LAYER_LOW := 2
const LAYER_PLAYER := 4
const LAYER_GATE := 8
const EPSILON := 0.0001
const DIAMOND := [[0,-20],[40,0],[0,20],[-40,0]]
const BRIDGE_NE := [[-140,30],[-60,70],[140,-30],[60,-70]]
const BRIDGE_SE := [[-60,-70],[-140,-30],[60,70],[140,30]]
const CAVE := [[-32,-32],[32,-32],[32,32],[-32,32]]
const NONE := []
const DEFINITIONS := {
	"flat80x40":{"support":DIAMOND,"collider":"none","height":"flat","stable_while_occupied":true},
	"joined_ground80x40":{"support":DIAMOND,"collider":"none","height":"flat","stable_while_occupied":true},
	"edge80x40":{"support":DIAMOND,"collider":"exposed_edges","layer":LAYER_SOLID,"height":"flat","stable_while_occupied":true},
	"cliff80x40":{"support":DIAMOND,"collider":"exposed_edges","layer":LAYER_SOLID,"height":"flat","stable_while_occupied":true},
	"side_only":{"support":NONE,"collider":"none","height":"none","stable_while_occupied":false},
	"corner_overlay":{"support":NONE,"collider":"none","height":"none","stable_while_occupied":false},
	"water80x40":{"support":NONE,"collider":"none","height":"none","stable_while_occupied":false},
	"shore_water":{"support":NONE,"collider":"none","height":"none","stable_while_occupied":false},
	"shore80x40":{"support":DIAMOND,"collider":"exposed_edges","layer":LAYER_SOLID,"height":"flat","stable_while_occupied":true},
	"ramp_NE20":{"support":DIAMOND,"collider":"none","height":"ramp","direction":"NE","rise":20.0,"stable_while_occupied":true},
	"ramp_SE20":{"support":DIAMOND,"collider":"none","height":"ramp","direction":"SE","rise":20.0,"stable_while_occupied":true},
	"ramp_SW20":{"support":DIAMOND,"collider":"none","height":"ramp","direction":"SW","rise":20.0,"stable_while_occupied":true},
	"ramp_NW20":{"support":DIAMOND,"collider":"none","height":"ramp","direction":"NW","rise":20.0,"stable_while_occupied":true},
	"stairs_NE20":{"support":DIAMOND,"collider":"none","height":"stairs","direction":"NE","rise":20.0,"treads":4,"stable_while_occupied":true},
	"stairs_SE20":{"support":DIAMOND,"collider":"none","height":"stairs","direction":"SE","rise":20.0,"treads":4,"stable_while_occupied":true},
	"stairs_SW20":{"support":DIAMOND,"collider":"none","height":"stairs","direction":"SW","rise":20.0,"treads":4,"stable_while_occupied":true},
	"stairs_NW20":{"support":DIAMOND,"collider":"none","height":"stairs","direction":"NW","rise":20.0,"treads":4,"stable_while_occupied":true},
	"bridge_NE":{"support":BRIDGE_NE,"collider":"none","height":"flat","stable_while_occupied":true},
	"bridge_SE":{"support":BRIDGE_SE,"collider":"none","height":"flat","stable_while_occupied":true},
	"cave_threshold":{"support":CAVE,"collider":"portal_sides","layer":LAYER_SOLID,"height":"flat","stable_while_occupied":true},
	"fog_edge":{"support":NONE,"collider":"none","height":"none","stable_while_occupied":false},
	"access_barrier":{"support":NONE,"collider":"gate","layer":LAYER_GATE,"height":"none","stable_while_occupied":false,"defer_activation_while_occupied":true}
}

static func ids() -> Array:
	return DEFINITIONS.keys()

static func definition(id: String) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(id,{}).duplicate(true)
	if not result.is_empty(): result.id = id
	return result

static func points(value: Array, origin := Vector2.ZERO) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in value: result.append(origin+Vector2(float(point[0]),float(point[1])))
	return result

static func polygon_for(id: String, origin := Vector2.ZERO) -> PackedVector2Array:
	return points(DEFINITIONS.get(id,{}).get("support",[]),origin)

static func support_record(id: String, origin := Vector2.ZERO, elevation := 0.0, enabled := true) -> Dictionary:
	var spec := definition(id)
	return {"profile_id":id,"origin":origin,"polygon":polygon_for(id,origin),"elevation":elevation,"minimum_height":elevation,"maximum_height":elevation+float(spec.get("rise",0.0)),"enabled":enabled,"support_active":not spec.get("support",[]).is_empty(),"stable_while_occupied":spec.get("stable_while_occupied",false)}

static func height_at(id: String, at: Vector2, origin := Vector2.ZERO, base := 0.0) -> float:
	var spec := definition(id)
	if spec.is_empty() or spec.get("height") == "none": return NAN
	var rule: String = spec.get("height","flat")
	if rule == "flat": return base
	var p := at-origin
	var factor := 0.0
	match spec.get("direction",""):
		"NE": factor = p.x/80.0-p.y/40.0+0.5
		"SE": factor = p.x/80.0+p.y/40.0+0.5
		"SW": factor = -p.x/80.0+p.y/40.0+0.5
		"NW": factor = -p.x/80.0-p.y/40.0+0.5
	factor = clampf(factor,0,1)
	if rule == "stairs":
		factor = 0.0 if factor <= EPSILON else ceilf(factor*float(spec.get("treads",4))-EPSILON)/float(spec.get("treads",4))
	return base+factor*float(spec.get("rise",0))

static func surface_change_allowed(id: String, occupied: bool, requested_active: bool, current_active := true) -> bool:
	var spec := definition(id)
	if spec.is_empty(): return false
	if occupied and current_active and not requested_active and spec.get("stable_while_occupied",false): return false
	if occupied and not current_active and requested_active and spec.get("defer_activation_while_occupied",false): return false
	return true

static func collision_polygons(id: String, edge_mask := 0, origin := Vector2.ZERO) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var spec := definition(id)
	match spec.get("collider",""):
		"exposed_edges":
			var top := points(DIAMOND,origin)
			for index in 4:
				if edge_mask & (1 << index) == 0: continue
				var start := top[index]
				var end := top[(index+1)%4]
				var normal := (end-start).orthogonal().normalized()*1.0
				result.append(PackedVector2Array([start+normal,end+normal,end-normal,start-normal]))
		"portal_sides":
			result.append(points([[-96,-32],[-32,-32],[-32,32],[-96,32]],origin))
			result.append(points([[32,-32],[96,-32],[96,32],[32,32]],origin))
		"gate": result.append(points([[-48,-3],[48,-3],[48,3],[-48,3]],origin))
	return result

static func foot_rect(at: Vector2, size := PLAYER_FOOT, margin := 0.0) -> Rect2:
	return Rect2(at-size*0.5,size).grow(maxf(0,margin))

static func cargo_clearance_rect(at: Vector2, cargo := "workshop_parts", margin := 0.0) -> Rect2:
	# Conservative projected body+held envelope, not a replacement physics collider.
	# 96 carry frame metadata hand anchors x77..114/y108..117 at .2923077,
	# actor home(1,-14), held sprite fitted <=15x14wu above bottom-center grip.
	var bounds := Rect2(-13,-25,27,36) if cargo == "workshop_parts" else Rect2(-10,-11,20,22)
	return Rect2(at+bounds.position,bounds.size).grow(maxf(0,margin))

static func full_foot_supported(at: Vector2, surfaces: Array, size := PLAYER_FOOT, required_height := 0.0, margin := 0.0) -> bool:
	return rectangle_supported(foot_rect(at,size,margin),surfaces,required_height)

static func rectangle_supported(rect: Rect2, surfaces: Array, required_height := 0.0) -> bool:
	if rect.size.x <= 0 or rect.size.y <= 0: return false
	var polygons: Array[PackedVector2Array] = []
	for surface in surfaces:
		if surface is PackedVector2Array:
			if surface.size() >= 3: polygons.append(surface)
		elif surface is Dictionary:
			if not surface.get("enabled",true) or not surface.get("support_active",true): continue
			if required_height < float(surface.get("minimum_height",surface.get("elevation",0)))-EPSILON or required_height > float(surface.get("maximum_height",surface.get("elevation",0)))+EPSILON: continue
			var polygon: PackedVector2Array = surface.get("polygon",PackedVector2Array())
			if polygon.size() >= 3: polygons.append(polygon)
	return _rectangle_covered(rect,polygons)

static func clearance_is_open(at: Vector2, blocker_polygons: Array, cargo := "workshop_parts", margin := 0.0) -> bool:
	var rect := cargo_clearance_rect(at,cargo,margin)
	var box := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	for blocker in blocker_polygons:
		var polygon: PackedVector2Array = blocker
		if polygon.size() >= 3 and not Geometry2D.intersect_polygons(box,polygon).is_empty(): return false
	return true

static func _inside_or_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for index in polygon.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])) <= EPSILON: return true
	return false

static func _rectangle_covered(rect: Rect2, polygons: Array[PackedVector2Array]) -> bool:
	if polygons.is_empty(): return false
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for corner: Vector2 in corners:
		var covered := false
		for polygon in polygons:
			if _inside_or_edge(corner,polygon): covered = true; break
		if not covered: return false
	# Exact planar subdivision: vertical-slice ordering changes at vertices,
	# polygon-edge intersections and where an edge crosses rectangle top/bottom.
	# Every open slab therefore has the same coverage topology; a midpoint slice
	# detects even an interior seam/hole that center/corners alone would miss.
	var xs: Array[float] = [rect.position.x,rect.end.x]
	var segments: Array[PackedVector2Array] = []
	for polygon in polygons:
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index+1)%polygon.size()]
			segments.append(PackedVector2Array([a,b]))
			if a.x > rect.position.x and a.x < rect.end.x: xs.append(a.x)
			if not is_equal_approx(a.y,b.y):
				for y in [rect.position.y,rect.end.y]:
					var factor: float = (y-a.y)/(b.y-a.y)
					if factor > 0 and factor < 1:
						var x: float = lerpf(a.x,b.x,factor)
						if x > rect.position.x and x < rect.end.x: xs.append(x)
	for i in segments.size():
		for j in range(i+1,segments.size()):
			var intersection: Variant = Geometry2D.segment_intersects_segment(segments[i][0],segments[i][1],segments[j][0],segments[j][1])
			if intersection is Vector2 and intersection.x > rect.position.x and intersection.x < rect.end.x: xs.append(intersection.x)
	xs.sort()
	for index in range(xs.size()-1):
		if xs[index+1]-xs[index] <= EPSILON: continue
		if not _slice_covered((xs[index+1]+xs[index])*0.5,rect,polygons): return false
	return true

static func _slice_covered(x: float, rect: Rect2, polygons: Array[PackedVector2Array]) -> bool:
	var intervals: Array[Vector2] = []
	for polygon in polygons:
		var ys: Array[float] = []
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index+1)%polygon.size()]
			if (a.x <= x and x < b.x) or (b.x <= x and x < a.x): ys.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
		ys.sort()
		for index in range(0,ys.size()-1,2): intervals.append(Vector2(ys[index],ys[index+1]))
	intervals.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var covered_to := rect.position.y
	for interval in intervals:
		if interval.y < covered_to-EPSILON: continue
		if interval.x > covered_to+EPSILON: return false
		covered_to = maxf(covered_to,interval.y)
		if covered_to >= rect.end.y-EPSILON: return true
	return false
