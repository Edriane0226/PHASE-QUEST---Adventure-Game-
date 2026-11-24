extends SceneTree
## Layout geometry only. Never loads campaign scenes or save services.
var data: Dictionary
var regions: Array
var placed: Array = []
var centers: Array[Vector2] = []
var weights: Array[float] = []
var coast := PackedVector2Array([Vector2(900,900),Vector2(2500,450),Vector2(4300,700),Vector2(5600,400),Vector2(7600,1000),Vector2(9000,1200),Vector2(10900,1100),Vector2(12600,700),Vector2(14300,500),Vector2(15900,850),Vector2(18000,1100),Vector2(19300,2300),Vector2(19800,4100),Vector2(19400,5400),Vector2(19700,6800),Vector2(18200,7800),Vector2(16500,8000),Vector2(15100,9000),Vector2(13300,9200),Vector2(11400,8700),Vector2(10200,9100),Vector2(8700,8500),Vector2(7400,7900),Vector2(6300,7700),Vector2(4900,7000),Vector2(3300,7100),Vector2(2100,6000),Vector2(1100,5000),Vector2(700,3400),Vector2(500,2100)])
var sites := [[2200,1800],[5150,2050],[7600,2800],[6400,4300],[4200,4800],[7100,5900],[8950,6050],[10400,4400],[11600,6100],[10000,7500],[13000,7600],[13800,5500],[14900,3900],[16000,2300],[17900,3200],[18400,5000],[16200,6200],[16900,4450]]
func _initialize() -> void: call_deferred("run")
func v(p: Array) -> Vector2: return Vector2(float(p[0]),float(p[1]))
func a(p: Vector2) -> Array: return [snappedf(p.x,0.01),snappedf(p.y,0.01)]
func array_poly(poly: PackedVector2Array) -> Array:
	var result: Array = []
	for p in poly: result.append(a(p))
	return result
func half_clip(poly: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if poly.is_empty(): return result
	var prev := poly[-1]
	var prev_d := normal.dot(prev)-limit
	for point in poly:
		var d := normal.dot(point)-limit
		if (d<=0)!=(prev_d<=0): result.append(prev+(point-prev)*(prev_d/(prev_d-d)))
		if d<=0: result.append(point)
		prev=point;prev_d=d
	return result
func cell(index: int) -> PackedVector2Array:
	var poly := coast
	for j in range(centers.size()):
		if j==index: continue
		poly=half_clip(poly,2*(centers[j]-centers[index]),centers[j].length_squared()-centers[index].length_squared()+weights[index]-weights[j])
	return poly
func poly_rect(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0],Vector2.ZERO)
	for p in poly: rect=rect.expand(p)
	return rect
func fits(point: Vector2, size: Vector2, polygon: PackedVector2Array) -> bool:
	var rect := Rect2(point-size/2,size).grow(16)
	for p in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
		if not Geometry2D.is_point_in_polygon(p,polygon): return false
	return true
func free_at(point: Vector2, size: Vector2, owner: String) -> bool:
	var rect := Rect2(point-size/2,size).grow(24)
	for s in placed:
		if s.kind=="catalog reservation": continue
		var other := Rect2(s.footprint[0],s.footprint[1],s.footprint[2],s.footprint[3])
		if rect.intersects(other): return false
	return true
func position_station(s: Dictionary, point: Vector2, size: Vector2) -> void:
	s.ground_xy=a(point);s.visual_xy=a(point-Vector2(0,float(s.elevation)))
	s.footprint=[snappedf(point.x-size.x/2,0.01),snappedf(point.y-size.y/2,0.01),size.x,size.y]
func place(s: Dictionary, desired: Vector2, size: Vector2, index: int) -> void:
	var poly := cell(index)
	var rng := RandomNumberGenerator.new();rng.seed=140140+index*1237+placed.size()*31
	var candidates: Array[Vector2] = [desired]
	for attempt in range(3000):
		var angle := rng.randf()*TAU
		var radius := rng.randf_range(100,1400)
		candidates.append(centers[index]+Vector2(cos(angle),sin(angle))*radius)
	for p in candidates:
		if fits(p,size,poly) and free_at(p,size,s.subregion):
			position_station(s,p,size);placed.append(s);return
	push_error("No valid natural-site station placement: "+s.id)
	quit(1)
func soft_route(from: Vector2, to: Vector2, bend := 110.0) -> Array:
	var delta := to-from
	var side := delta.normalized().orthogonal()
	return [a(from),a(from+delta*0.33+side*bend),a(from+delta*0.68-side*bend*0.45),a(to)]
func station(id: String) -> Dictionary:
	for s in data.stations:
		if s.id==id:return s
	return {}
func length_of(points: Array) -> float:
	var total := 0.0
	for j in range(1,points.size()):total+=v(points[j-1]).distance_to(v(points[j]))
	return snappedf(total,0.1)
func cubic(points: Array, t: float) -> Vector2:
	return v(points[0]).bezier_interpolate(v(points[1]),v(points[2]),v(points[3]),t)
func owner_at(point: Vector2) -> int:
	for i in range(18):
		if Geometry2D.is_point_in_polygon(point,cell(i)):return i
	return -1
func run() -> void:
	var path := OS.get_cmdline_user_args()[0]
	data=JSON.parse_string(FileAccess.get_file_as_string(path));regions=data.regions
	for index in range(18):
		centers.append(v(sites[index]));weights.append(350000.0 if regions[index].level==6 else 0.0)
	# Preserve the COMPLETE legacy floor AABBs, not only their town-center seed.
	var deltas := [Vector2(2200,1800),Vector2(4200,1900)]
	for pass_i in range(4):
		for i in range(2):
			var r: Dictionary=regions[i]
			var box := Rect2(r.source_floor_bounds[0],r.source_floor_bounds[1],r.source_floor_bounds[2],r.source_floor_bounds[3])
			box.position+=deltas[i];box=box.grow(120)
			for p in [box.position,box.end,Vector2(box.position.x,box.end.y),Vector2(box.end.x,box.position.y)]:
				for j in range(18):
					if j==i:continue
					weights[i]=maxf(weights[i],2*(centers[j]-centers[i]).dot(p)-centers[j].length_squared()+centers[i].length_squared()+weights[j]+1)
	for i in range(18):
		var r: Dictionary=regions[i];var poly := cell(i);var box := poly_rect(poly)
		r.center=a(centers[i]);r.permission_polygon=array_poly(poly)
		r.bounds=[box.position.x,box.position.y,box.size.x,box.size.y]
		r.bounds_role="Camera/debug AABB only; NOT terrain outline, room, visible wall or rectangular fog enclosure"
		r.terrain_policy="Shared mainland terrain continues across location boundaries; free exploration within all earned territory. Science outcome still requires actual station action."
		if i<2:
			var shift: Vector2 = deltas[i]-v(r.translation_only)
			r.translation_only=a(deltas[i]);r.entry=a(v(r.entry)+shift);r.exit=a(v(r.exit)+shift)
			for anchor in r.source_anchors:anchor.world_xy=a(v(anchor.local_xy)+deltas[i])
			for j in range(r.internal_route.size()):r.internal_route[j]=a(v(r.internal_route[j])+shift)
			for s in data.stations:
				if s.subregion==r.id:position_station(s,v(s.ground_xy)+shift,Vector2(s.footprint[2],s.footprint[3]));placed.append(s)
			for route in r.local_cargo_paths:
				for j in range(route.points.size()):route.points[j]=a(v(route.points[j])+shift)
		else:
			var incoming := (centers[i-1]-centers[i]).normalized()
			var outgoing := (centers[mini(i+1,17)]-centers[i]).normalized() if i<17 else Vector2(0,1)
			place(station(r.id+".entry"),centers[i]+incoming*540,Vector2(96,96),i)
			position_station(station(r.id+".C0"),v(station(r.id+".entry").ground_xy),Vector2(96,96))
			place(station(r.id+".professor"),v(station(r.id+".entry").ground_xy)-incoming*230+incoming.orthogonal()*150,Vector2(200,160),i)
			var order := 0
			for s in data.stations:
				if s.subregion!=r.id or s.kind not in ["puzzle court","optional minigame"]:continue
				var angle := deg_to_rad(i*43+order*137.5)
				var n: int=s.required_groups.size()
				var size := Vector2(420,320) if n>6 else (Vector2(320,240) if n>3 else Vector2(260,220))
				if s.kind=="optional minigame":size=Vector2(340,260)
				place(s,centers[i]+Vector2(cos(angle)*650,sin(angle)*560),size,i)
				s.authority="Organic landmark/station placement; reserve derived from group count and retained working/cargo clearances; later physical integration required"
				order+=1
			for id in ["C1","C2","C3","finn"]:
				var s := station(r.id+"."+id)
				if s.is_empty():continue
				place(s,centers[i]+Vector2(-220+order*85,150+order*35),Vector2(200,160) if id=="finn" else Vector2(96,96),i);order+=1
			place(station(r.id+".exit"),centers[i]+outgoing*540,Vector2(96,96),i)
			r.entry=station(r.id+".entry").ground_xy;r.exit=station(r.id+".exit").ground_xy
			r.internal_route=[];r.local_cargo_paths=[]
			var points: Array=[r.entry]
			for s in data.stations:
				if s.subregion==r.id and s.kind=="puzzle court":points.append(s.ground_xy)
			points.append(r.exit)
			r.internal_route=points
			for s in data.stations:
				if s.subregion!=r.id or s.kind not in ["puzzle court","optional minigame"]:continue
				var route := soft_route(v(s.ground_xy),centers[i],70)
				r.local_cargo_paths.append({"id":s.id+".return","points":route,"clear_width":96,"turning_pad":128,"support":"Permanent local ground/latched structures; explicit item/collision sweeps still required","permission":"Free roaming is not a solved receipt; station outcome governs cargo recovery and all forward unlocks","scope":"local","recovery":"Newest unlocked local checkpoint; unique item recovered once"})
		var prof: Dictionary={}
		for s in data.stations:
			if s.subregion==r.id and s.kind=="professor":prof=s;break
		r.learning_footprints.shared_ground_xy=prof.ground_xy;r.learning_footprints.shared_footprint=prof.footprint
		r.exploration="Open meadow/forest/shore/ridge ground plus branching trails. Terrain is not restricted to the road graph. Local source puzzle hazards/gates stay protected; no required science is awarded by walking around a station."
	# Preserve authoritative chapter connections while giving the landscape multiple earned routes.
	for i in range(17):
		var c: Dictionary=data.connections[i];var from: Dictionary=regions[i];var to: Dictionary=regions[i+1]
		c.source_anchor=from.exit;c.destination_anchor=to.entry
		c.polyline=soft_route(v(from.exit),v(to.entry),180)
		if i==5:c.polyline=[from.exit,[7750,6400],[8350,6480],to.entry]
		if i==11:c.polyline=soft_route(v(from.exit),v(to.entry),90)
		if i==15:c.polyline=[from.exit,[18400,6600],[16800,7050],to.entry] # southern pass avoids still-locked Core territory
		c.length_world=length_of(c.polyline);c.travel_seconds_estimate=snappedf(c.length_world/(100 if c.kind=="walk" else 360),0.1)
		c.border.erase("enclosure");c.border.permission_polygon=to.permission_polygon
		c.border.portal=to.entry;c.border.portal_role="Arrival marker inside open territory; exact natural-path/fog-edge intersections stored in landscape trail gates, not a room doorway"
		c.border.blocking="Organic unearned-territory fog/permission area; all off-road, jump, ray and checkpoint approaches checked. No rectangular enclosing room walls."
		c.camera="Shared continuous camera across landscape; no corridor scene or selection-screen transition"
	var roads: Array=[];var pairs := {}
	for c in data.connections:
		roads.append({"id":c.id,"a":c.source,"b":c.destination,"points":c.polyline,"kind":c.kind,"clear_width":96,"authority":"Both location prerequisites and transit receipt; never proximity unlock","role":"curriculum connection"});pairs[c.id]=true
	for i in range(18):
		var neighbors: Array=[]
		for j in range(18):
			if i!=j:neighbors.append({"j":j,"distance":centers[i].distance_to(centers[j])})
		neighbors.sort_custom(func(x,y):return x.distance<y.distance)
		for n in neighbors.slice(0,3):
			var j: int=n.j
			if n.distance>3400:continue
			var low := mini(i,j);var high := maxi(i,j);var id: String=regions[low].id+"--"+regions[high].id
			if pairs.has(id):continue
			pairs[id]=true
			roads.append({"id":"trail."+id,"a":regions[low].id,"b":regions[high].id,"points":soft_route(centers[low],centers[high],100+float(i%3)*70),"kind":"scenic walking trail","clear_width":96,"authority":"Both endpoint permissions AND every crossed territory must already be unlocked. Shortcut never skips a completion/prerequisite.","role":"alternate exploration/backtracking"})
	data.schema_version=2;data.revision="Organic mainland; replaces rejected box/room layout"
	data.world_bounds=[0,0,21000,10000];data.layout_model="ONE shared continuous mainland, three blended biomes, eighteen landmark/learning locations; free off-road exploration in earned territory. AABBs are debug/camera metadata only."
	data.landscape={"mainland":array_poly(coast),"trails":roads,"waterways":[{"id":"meltwater_river","width":210,"points":[[6800,1100],[7350,2200],[7600,3300],[7000,4100],[7500,5100],[7750,5900],[8550,6500],[10300,6750],[11300,7800],[11350,9000]]},{"id":"returning_stream","width":125,"points":[[14900,1700],[14200,3000],[13300,4200],[12300,5250],[11600,6400],[10500,7300],[10300,8800]]}],"lakes":[{"center":[7750,3250],"radii":[520,370]},{"center":[8900,6900],"radii":[600,300]}],"forest_centers":[[1500,3300],[2600,4100],[3500,1600],[5400,3300],[5600,5300],[8700,4200],[10100,3400],[11200,5100],[12600,6200],[12200,8300]],"ridge_spines":[[[1700,1100],[3400,850],[5100,1050],[6200,1650]],[[13000,1600],[14400,1300],[16100,1400],[18000,2000]],[[14700,6800],[17000,7200],[18700,6000]]],"terrain_rule":"Roads are suggested routes across broad supported ground, never the only walkable strips. Rivers have authored crossings; ridges have multiple passes/terraces. Exact support mesh and all water crossings are later world work.","permission_rule":"Organic area masks (hidden in default review), physical permission barriers on every unearned approach including off-road, discovery separate. No rectangular district enclosure."}
	data.landscape.settlement_approaches=[]
	for i in range(18):
		var r: Dictionary=regions[i]
		if i<2:data.landscape.settlement_approaches.append({"points":r.internal_route,"curve":"polyline","authority":"Retained source-route orientation; source support/gates remain authoritative"})
		else:
			for anchor in [r.entry,r.exit]:data.landscape.settlement_approaches.append({"points":soft_route(centers[i],v(anchor),50),"curve":"cubic_bezier","authority":"Open-ground settlement approach; terrain support and river crossings must be authored"})
	data.menu_viewpoints=[{"id":"menu.gardens","zone_id":"melting_and_freezing","target":[4300,3000],"visible_bounds":[900,700,7600,5400],"composition":"One snowy garden/mill river landscape, no visible room boundaries"},{"id":"menu.vale","zone_id":"vaporization_and_condensation","target":[11100,6100],"visible_bounds":[7600,3600,7000,5000],"composition":"Continuous orchard/shore/greenhouse valley and branching river"},{"id":"menu.lab","zone_id":"sublimation_and_deposition","target":[16600,4100],"visible_bounds":[13700,1300,6100,5900],"composition":"Connected elevated research ridge with terraces and open foothills"}]
	for road in roads:
		var territory: Array=[];var gates: Array=[];var sampled: Array=[];var crossings: Array=[]
		var last_owner := -1
		for step in range(97):
			var point := cubic(road.points,float(step)/96)
			sampled.append(a(point))
			var owner := owner_at(point)
			if owner>=0:
				if not regions[owner].id in territory:territory.append(regions[owner].id)
				if last_owner>=0 and owner!=last_owner:gates.append({"at":a(point),"from":regions[last_owner].id,"to":regions[owner].id,"permission":"Check whole organic permission area and every approach, not just this trail marker"})
			last_owner=owner
		road.curve="cubic_bezier";road.sampled_points=sampled;road.access_territories=territory;road.permission_crossings=gates;road.length_world=length_of(sampled)
		for river in data.landscape.waterways:
			for j in range(1,sampled.size()):
				for k in range(1,river.points.size()):
					var intersection=Geometry2D.segment_intersects_segment(v(sampled[j-1]),v(sampled[j]),v(river.points[k-1]),v(river.points[k]))
					if intersection!=null:
						var close := false
						for old in crossings:
							if v(old.at).distance_to(intersection)<100:close=true
						if not close:crossings.append({"at":a(intersection),"river":river.id,"kind":"boat water crossing" if road.kind=="crafted boat passage" else "reserved permanent bridge","clear_width":96,"support":"Bridge deck/abutments or crafted boat required; no floor inferred from painted road"})
		road.water_crossings=crossings
		for c in data.connections:
			if c.id==road.id:
				c.length_world=road.length_world;c.travel_seconds_estimate=snappedf(c.length_world/(100 if c.kind=="walk" else 360),0.1)
				c.border.erase("portal_accuracy_world");c.border.trail_crossings=gates;c.access_territories=territory
	data.implementation_note="This revision changes actual planned geography, station positions, trail topology and fog-mask geometry; it does not merely hide rectangle outlines. Existing local source routes remain translation-only. No R3 015 runtime construction."
	if not load("res://population.gd").new().populate(data):quit(1);return
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("R3 014 ORGANIC PASS / one mainland / ",roads.size()," branching trails / ",placed.size()," placement records")
	quit()
