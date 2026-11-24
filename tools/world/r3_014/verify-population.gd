extends RefCounted
var checks := 0
var failures: Array = []
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func v(p: Array) -> Vector2:return Vector2(p[0],p[1])
func rect(f: Array) -> Rect2:return Rect2(f[0],f[1],f[2],f[3])
func poly(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:result.append(v(p))
	return result
func wet(p: Vector2, d: Dictionary) -> bool:
	for river in d.landscape.waterways:
		for j in range(1,river.points.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,v(river.points[j-1]),v(river.points[j])))<river.width/2.0:return true
	for lake in d.landscape.lakes:
		var delta := p-v(lake.center)
		if pow(delta.x/lake.radii[0],2)+pow(delta.y/lake.radii[1],2)<1:return true
	return false
func covered_by_span(p: Vector2, spans: Array) -> bool:
	for span in spans:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,v(span.from),v(span.to)))<=60:return true
	return false
func verify(d: Dictionary, path: String) -> Dictionary:
	var prior=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("archive/organic-mainland-v2/world-layout.json")))
	var ids := {};var owners := {};var legacy: Array=[];var required := {};var moved := 0
	for s in d.stations:required[s.id]=s
	for r in d.regions:owners[r.id]=poly(r.permission_polygon)
	for r in d.regions.slice(0,2):
		var b=r.source_floor_bounds;legacy.append(Rect2(b[0]+r.translation_only[0],b[1]+r.translation_only[1],b[2],b[3]))
	for old in prior.stations:
		check(required.has(old.id),"retained requirement "+old.id)
		var current: Dictionary=required[old.id]
		for key in old:
			if key in ["ground_xy","visual_xy","footprint","authority"]:continue
			check(current[key]==old[key],"stable station semantics "+old.id+" / "+key)
		if old.subregion in ["Z1L1","Z1L2"]:check(current==old,"every legacy interaction unchanged "+old.id)
		elif old.kind in ["puzzle court","optional minigame"]:
			check(current.ground_xy!=old.ground_xy,"requirement actually distributed "+old.id);moved+=1
			var box := rect(current.footprint)
			for x in [box.position.x,box.get_center().x,box.end.x]:
				for y in [box.position.y,box.get_center().y,box.end.y]:check(not wet(Vector2(x,y),d),"dry worksite pad "+old.id)
	check(d.connections==prior.connections,"main road anchors, curriculum gates, water crossings and prerequisites unchanged")
	var stops: Array=d.landscape.exploration_stops
	check(stops.size()>=54,"at least three exploration stops per learning area")
	for s in stops:
		check(not ids.has(s.id) and not required.has(s.id),"unique optional stop "+s.id);ids[s.id]=s
		check(s.optional and s.repeatable and s.rewards.is_empty(),"free repeatable stop, no new rewards "+s.id)
		check(s.completion_effect=="none" and s.progression_effect=="none","no objective or unlock effects "+s.id)
		check(s.permission_owner==s.subregion,"correct stop permission owner "+s.id)
		var owner: Dictionary={}
		for r in d.regions:
			if r.id==s.subregion:owner=r;break
		check(s.requires_completed==owner.requires_completed,"stop inherits exact prerequisites "+s.id)
		var box := rect(s.footprint)
		for x in [box.position.x,box.get_center().x,box.end.x]:
			for y in [box.position.y,box.get_center().y,box.end.y]:
				check(Geometry2D.is_point_in_polygon(Vector2(x,y),owners[s.subregion]),"stop inside own boundaries "+s.id)
				check(not wet(Vector2(x,y),d),"stop on dry terrain "+s.id)
		for other in stops+d.stations:
			if other.id==s.id or other.get("kind")=="catalog reservation":continue
			check(not box.grow(24).intersects(rect(other.footprint)),"stop preserves existing clearance "+s.id+" / "+other.id)
		if s.subregion in ["Z1L1","Z1L2"]:check(not box.intersects(legacy[0 if s.subregion=="Z1L1" else 1].grow(128)),"stop outside protected source envelope "+s.id)
		if s.kind=="free practice":check(required.has(s.practice_reference) and required[s.practice_reference].kind=="optional minigame" and s.practice_reference.left(2)==s.subregion.left(2),"practice reuses same-zone minigame assets/demonstrations "+s.id)
	var adjacency := {}
	for route in d.landscape.local_branches:
		check((ids.has(route.from) or required.has(route.from)) and (ids.has(route.to) or required.has(route.to)),"valid branch endpoints "+route.id)
		for id in [route.from,route.to]:
			if not adjacency.has(id):adjacency[id]=[]
		adjacency[route.from].append(route.to);adjacency[route.to].append(route.from)
		check(route.clear_width>=96,"branch carry/walking clearance "+route.id)
		for p in route.sampled_points:
			check(Geometry2D.is_point_in_polygon(v(p),owners[route.subregion]),"branch stays in earned boundary "+route.id)
			if wet(v(p),d):check(covered_by_span(v(p),route.water_crossings),"water sample has explicit bridge span "+route.id)
			if route.subregion in ["Z1L1","Z1L2"]:check(not legacy[0 if route.subregion=="Z1L1" else 1].grow(48).has_point(v(p)),"new paths never fill original route gaps "+route.id)
	for r in d.regions:
		var local: Array=[]
		for s in stops:
			if s.subregion==r.id:local.append(s.id)
		check(local.size()>=3,"populated area "+r.id)
		var visited := {local[0]:true};var pending: Array=[local[0]]
		while not pending.is_empty():
			var id: String=pending.pop_front()
			for next in adjacency.get(id,[]):
				if not visited.has(next):visited[next]=true;pending.append(next)
		for id in local:check(visited.has(id),"all local exploration stops connected "+id)
		if r.id not in ["Z1L1","Z1L2"]:
			for s in d.stations:
				if s.subregion==r.id and s.kind in ["puzzle court","optional minigame","professor","entry","exit","assessor"]:check(visited.has(s.id),"worksite reachable from local network "+s.id)
	var max_gap := 0.0
	# Independent grid offset/step checks density; water and protected source routes excluded.
	for r in d.regions:
		var b=r.bounds
		for x in range(int(b[0])+211,int(b[0]+b[2]),420):
			for y in range(int(b[1])+173,int(b[1]+b[3]),420):
				var p := Vector2(x,y)
				if not Geometry2D.is_point_in_polygon(p,owners[r.id]) or wet(p,d):continue
				if r.id in ["Z1L1","Z1L2"] and legacy[0 if r.id=="Z1L1" else 1].grow(128).has_point(p):continue
				var nearest := INF
				for s in stops+d.stations:
					if s.subregion==r.id and s.kind!="catalog reservation":nearest=minf(nearest,p.distance_to(v(s.ground_xy)))
				max_gap=maxf(max_gap,nearest)
				check(nearest<=1500,"no large sampled empty dry-ground pocket "+r.id+" / "+str(p))
	return {"checks":checks,"failures":failures,"distributed_worksites":moved,"optional_stops":stops.size(),"local_branches":d.landscape.local_branches.size(),"independent_sample_max_gap_world":snappedf(max_gap,1),"status":"PASS" if failures.is_empty() else "FAIL","scope":"source/semantic preservation, actual worksite redistribution, dry owned nonoverlapping pads, no reward/progression effects, same-zone practice reuse, connected branches, explicit wet-span support, legacy-envelope protection, independently sampled content spacing; not runtime physics"}
