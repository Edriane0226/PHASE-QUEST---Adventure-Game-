extends RefCounted
## Composes existing owned terrain; never paints support across original puzzle gaps.
const SUPPORT=preload("res://Scripts/World/terrain_support_profiles.gd")
var models: Array=[]
var access: RefCounted
var region_models: Dictionary={}
var room_solids: Array=[]
func bind(values: Array,policy: RefCounted) -> void:
	models=values;access=policy
	for m in models:
		m.prefix=6
		for r in m.data.regions:region_models[r.id]=m
func region_at(point: Vector2) -> String:return access.region_at(point)
func height_record(point: Vector2) -> Dictionary:
	var result: Dictionary={}
	for m in models:
		var h: Dictionary=m.height_record(point)
		if not h.is_empty() and (result.is_empty() or h.height>result.height):result=h
	return result
func height_mainland(point: Vector2) -> float:
	var m: RefCounted=region_models.get(region_at(point))
	return m.height_mainland(point) if m else 0.0
func supported_box(box: Rect2,body_path:="") -> bool:
	var candidates: Array=[]
	for m in models:
		var seen: Dictionary={}
		for key in m.cells(box):
			for id in m.floor_bins.get(key,[]):
				if seen.has(id):continue
				seen[id]=true;var f: Dictionary=m.floors[id]
				if f.conditional and not m.science_open:continue
				if not body_path.is_empty() and f.body_path!=body_path:continue
				if f.bounds.intersects(box):candidates.append(f.polygon)
	return SUPPORT.rectangle_supported(box,candidates)
func standable(point: Vector2,cargo:=false,landing:=false,permission:=true) -> bool:
	if not point.is_finite():return false
	var box:=SUPPORT.cargo_clearance_rect(point) if cargo else SUPPORT.foot_rect(point)
	if permission and not access.box_allowed(box):return false
	var path: String=str(height_record(point).get("body_path","")) if landing else ""
	if not supported_box(box,path):return false
	for m in models:
		if m.blocked_box(box,11,path):return false
	for record in room_solids:
		if not is_instance_valid(record.owner) or not record.owner.is_inside_tree() or record.owner.is_queued_for_deletion():continue
		if not Geometry2D.intersect_polygons(PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]),record.polygon).is_empty():return false
	return true
