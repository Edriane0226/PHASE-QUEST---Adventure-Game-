extends SceneTree
var checks := 0
var failures: Array = []
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func vec(p: Array) -> Vector2:return Vector2(p[0],p[1])
func polygon(points: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in points:poly.append(vec(p))
	return poly
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var d=JSON.parse_string(FileAccess.get_file_as_string(path))
	var old=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("archive/box-layout-v1/world-layout.json")))
	var coast := polygon(d.landscape.mainland)
	check(d.regions.size()==18 and d.zones.size()==3 and d.stations.size()==221,"stable 3zones/18places/221station records")
	check(d.landscape.mainland.size()>20 and d.landscape.trails.size()>17,"one broad mainland and branching trail graph")
	check(d.world_bounds[2]*d.world_bounds[3]<old.world_bounds[2]*old.world_bounds[3],"more compact than rejected layout")
	var ids := {};var index := {};var polygons: Array=[]
	for i in range(18):
		var r=d.regions[i];index[r.id]=i;polygons.append(polygon(r.permission_polygon))
		check(r.id==old.regions[i].id and r.completion_key==old.regions[i].completion_key and r.zone_id==old.regions[i].zone_id,"unchanged identity "+r.id)
		check(r.requires_completed==old.regions[i].requires_completed,"unchanged authoritative prerequisite closure "+r.id)
		check(Geometry2D.is_point_in_polygon(vec(r.center),coast),"landmark on mainland "+r.id)
		check(Geometry2D.is_point_in_polygon(vec(r.center),polygons[i]),"landmark in its organic permission area "+r.id)
		check(r.bounds_role.begins_with("Camera/debug"),"AABB not geography "+r.id)
		if i<2:
			check(r.source_anchors.size()==old.regions[i].source_anchors.size(),"all source anchors retained "+r.id)
			for anchor in r.source_anchors:check(vec(anchor.world_xy).is_equal_approx(vec(anchor.local_xy)+vec(r.translation_only)),"translation only "+anchor.path)
			var b=r.source_floor_bounds
			var rect := Rect2(b[0]+r.translation_only[0],b[1]+r.translation_only[1],b[2],b[3])
			for p in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:check(Geometry2D.is_point_in_polygon(p,polygons[i]),"legacy whole source AABB stays accessible "+r.id)
	for s in d.stations:
		check(not ids.has(s.id),"unique station "+s.id);ids[s.id]=true
		var i: int=index[s.subregion]
		check(Geometry2D.is_point_in_polygon(vec(s.ground_xy),coast),"station on mainland "+s.id)
		if i>=2:
			var f=s.footprint;var r := Rect2(f[0],f[1],f[2],f[3])
			check(f[2]>=96 and f[3]>=96,"working clearance "+s.id)
			for p in [r.position,r.end,Vector2(r.position.x,r.end.y),Vector2(r.end.x,r.position.y)]:check(Geometry2D.is_point_in_polygon(p,polygons[i]),"reserved footprint in owned organic territory "+s.id)
			for other in d.stations:
				if other.id>=s.id:continue
				if s.id.ends_with(".C0") and other.id==s.subregion+".entry" or other.id.ends_with(".C0") and s.id==other.subregion+".entry":continue
				if other.kind=="catalog reservation":continue
				var b=other.footprint
				check(not r.intersects(Rect2(b[0],b[1],b[2],b[3])),"scattered station nonoverlap "+s.id+" "+other.id)
	var adjacency: Dictionary={}
	for r in d.regions:adjacency[r.id]=[]
	for road in d.landscape.trails:
		check(road.a!=road.b and road.clear_width>=96,"usable trail "+road.id)
		adjacency[road.a].append(road.b);adjacency[road.b].append(road.a)
		check(road.access_territories.has(road.a) and road.access_territories.has(road.b),"trail records endpoint permission areas "+road.id)
		for p in road.sampled_points:
			check(Geometry2D.is_point_in_polygon(vec(p),coast),"actual cubic trail on mainland "+road.id)
		for crossing in road.water_crossings:check(crossing.clear_width>=96 and crossing.has("support"),"explicit river crossing support "+road.id)
		if road.role=="curriculum connection":
			var dest: int=index[road.b]
			for area in road.access_territories:check(index[area]<=dest,"no prerequisite deadlock through future territory "+road.id+" / "+area)
	var visited := {d.regions[0].id:true};var queue: Array=[d.regions[0].id]
	while not queue.is_empty():
		var id: String=queue.pop_front()
		for next in adjacency[id]:
			if not visited.has(next):visited[next]=true;queue.append(next)
	check(visited.size()==18,"connected whole-landscape trail graph")
	var cycles: int=d.landscape.trails.size()-18+1
	check(cycles>=6,"multiple routes/loops instead of 18-room chain")
	# Every currently earned prefix can reach its newly eligible next location via the actual gated trail graph.
	for prefix in range(18):
		var reached := {d.regions[0].id:true};var pending: Array=[d.regions[0].id]
		while not pending.is_empty():
			var current: String=pending.pop_front()
			for road in d.landscape.trails:
				if current not in [road.a,road.b]:continue
				var valid := true
				for area in road.access_territories:
					if index[area]>prefix:valid=false
				if not valid:continue
				var next: String=road.b if road.a==current else road.a
				if not reached.has(next):reached[next]=true;pending.append(next)
		check(reached.has(d.regions[prefix].id),"earned-territory traversal feasible at prefix "+str(prefix))
		for id in reached:check(index[id]<=prefix,"alternate road cannot bypass a locked territory")
	# Sample broad ground AWAY from roads: permission masks cover the landscape, not thin walkway strips.
	var land_samples := 0
	for x in range(1000,19500,600):
		for y in range(1000,8800,600):
			var p := Vector2(x,y)
			if not Geometry2D.is_point_in_polygon(p,coast):continue
			land_samples+=1;var count := 0
			for poly in polygons:
				if Geometry2D.is_point_in_polygon(p,poly):count+=1
			check(count>=1,"off-road terrain belongs to an earned/unearned area")
	check(land_samples>200,"broad terrain sampled, not only route lines")
	var population=load("res://verify-population.gd").new().verify(d,path)
	FileAccess.open(path.get_base_dir().path_join("evidence/population-results.json"),FileAccess.WRITE).store_string(JSON.stringify(population,"\t"))
	checks+=population.checks;failures.append_array(population.failures)
	var result := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"landmarks":18,"stations":d.stations.size(),"trails":d.landscape.trails.size(),"cycles":cycles,"offroad_samples":land_samples,"population":population,"scope":"organic populated mainland, actual cubic roads, permission graph/no deadlocks, scattered footprints, source route translations and exploration density; not a constructed world physics test"}
	FileAccess.open(path.get_base_dir().path_join("evidence/organic-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ORGANIC VERIFY ",result.status," / ",checks," checks / ",failures.size()," failures")
	for failure in failures:print(failure)
	quit(0 if failures.is_empty() else 1)
