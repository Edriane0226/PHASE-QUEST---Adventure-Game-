extends RefCounted
## Prerequisites own permissions. Discovery and presentation never enter this decision.
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const SUPPORT=preload("res://Scripts/World/terrain_support_profiles.gd")
var profile: Node
var fixture:=false
var campaign:=false
var rows: Array=[]
var polygons: Dictionary={}
var permissions: Dictionary={}
var revision:=0
var _box_revision:=-1
var _box_rect:=Rect2()
var _box_result:=false
func bind(store: Node,isolated: bool,authored: Dictionary={}) -> void:
	profile=store;fixture=isolated;campaign=not authored.is_empty();rows=REGISTRY.definitions()
	for r in rows:
		if authored.has(r.id):
			polygons[r.id]=authored[r.id]
			continue
		var p:=PackedVector2Array()
		for point in r.permission_polygon:p.append(Vector2(point[0],point[1]))
		polygons[r.id]=p
	refresh()
func refresh() -> Array:
	var changed: Array=[]
	for r in rows:
		var ready: bool=fixture or REGISTRY.definition(r.id).world_ready
		var allowed: bool=REGISTRY.can_enter_campaign(profile,r.id) if campaign else ready and profile.is_level_unlocked(r.zone_id,r.level)
		if not permissions.has(r.id) or permissions[r.id]!=allowed:changed.append(r.id)
		permissions[r.id]=allowed
	if not changed.is_empty():revision+=1
	return changed
func allowed(id: String) -> bool:return permissions.get(id,false)==true
func completed(id: String) -> bool:
	var r:=REGISTRY.definition(id)
	return not r.is_empty() and allowed(id) and profile.is_level_complete(r.zone_id,r.level)
func region_at(point: Vector2) -> String:
	for r in rows:
		if Geometry2D.is_point_in_polygon(point,polygons[r.id]):return r.id
	return ""
func point_allowed(point: Vector2) -> bool:return point.is_finite() and allowed(region_at(point))
func segment_clear(from: Vector2,to: Vector2) -> bool:
	for r in rows:
		if allowed(r.id):continue
		var p: PackedVector2Array=polygons[r.id]
		if Geometry2D.is_point_in_polygon(from,p) or Geometry2D.is_point_in_polygon(to,p):return false
		for i in range(p.size()):
			if Geometry2D.segment_intersects_segment(from,to,p[i],p[(i+1)%p.size()])!=null:return false
	return true
func box_allowed(box: Rect2) -> bool:
	# Input/player/emitter ask for the same full foot repeatedly each frame.
	# Permissions revision invalidates both positive and negative answers immediately.
	if _box_revision==revision and _box_rect==box:return _box_result
	var permitted: Array=[]
	for r in rows:
		if allowed(r.id):permitted.append(polygons[r.id])
	_box_result=SUPPORT.rectangle_supported(box,permitted);_box_rect=box;_box_revision=revision
	return _box_result
func ray_fraction(from: Vector2,to: Vector2) -> float:
	if not point_allowed(from):return 0.0
	var length:=from.distance_to(to)
	if length<.001:return 1.0
	var fraction:=1.0
	for r in rows:
		if allowed(r.id):continue
		var p: PackedVector2Array=polygons[r.id]
		for i in range(p.size()):
			var hit=Geometry2D.segment_intersects_segment(from,to,p[i],p[(i+1)%p.size()])
			if hit!=null:fraction=minf(fraction,from.distance_to(hit)/length)
	return maxf(0,fraction-.001) if fraction<1 else fraction
func missing(id: String) -> String:
	var r:=REGISTRY.definition(id)
	if r.is_empty():return "Unknown destination."
	for key in r.requires_completed:
		if profile.data.completed.get(str(key),false)!=true:
			for previous in rows:
				if previous.completion_key==key:return "Complete "+str(previous.name)+" to continue."
	return "Destination awaits campaign integration." if not allowed(id) else ""
