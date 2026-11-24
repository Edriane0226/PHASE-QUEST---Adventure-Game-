extends RefCounted
## Reviewable placement plan only: no scene imports, saves, rewards or live tasks.
var d: Dictionary
var polys: Array = []
var occupied: Array = []
var legacy: Array[Rect2] = []
const STOP_SIZE := Vector2(180,140)
const GAP_TARGET := 1100.0

func v(p: Array) -> Vector2:return Vector2(p[0],p[1])
func a(p: Vector2) -> Array:return [snappedf(p.x,0.01),snappedf(p.y,0.01)]
func rect(f: Array) -> Rect2:return Rect2(f[0],f[1],f[2],f[3])
func polygon(points: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q in points:p.append(v(q))
	return p
func dry(p: Vector2, margin: float) -> bool:
	for river in d.landscape.waterways:
		for j in range(1,river.points.size()):
			if Geometry2D.get_closest_point_to_segment(p,v(river.points[j-1]),v(river.points[j])).distance_to(p)<river.width/2.0+margin:return false
	for lake in d.landscape.lakes:
		var delta := p-v(lake.center)
		if pow(delta.x/(lake.radii[0]+margin),2)+pow(delta.y/(lake.radii[1]+margin),2)<1:return false
	return true
func fits(p: Vector2, size: Vector2, i: int, protect_source := false) -> bool:
	var box := Rect2(p-size/2,size).grow(32)
	for q in [box.position,box.end,Vector2(box.position.x,box.end.y),Vector2(box.end.x,box.position.y)]:
		if not Geometry2D.is_point_in_polygon(q,polys[i]):return false
	if not dry(p,size.length()/2+48):return false
	if protect_source and i<2 and box.intersects(legacy[i].grow(128)):return false
	for other in occupied:
		if box.intersects(rect(other.footprint).grow(24)):return false
	return true
func spacing(p: Vector2, i: int) -> float:
	var distance := p.distance_to(v(d.regions[i].center))
	for s in occupied:
		if s.subregion==d.regions[i].id:distance=minf(distance,p.distance_to(v(s.ground_xy)))
	return distance
func best_point(i: int, size: Vector2, protect_source := false) -> Variant:
	var b=d.regions[i].bounds
	var rng := RandomNumberGenerator.new();rng.seed=140014+i*3251+occupied.size()*53
	var best: Variant=null;var score := -1.0
	for attempt in range(1600):
		var p := Vector2(rng.randf_range(b[0],b[0]+b[2]),rng.randf_range(b[1],b[1]+b[3]))
		if not fits(p,size,i,protect_source):continue
		var candidate := spacing(p,i)
		if candidate>score:best=p;score=candidate
	return best
func move_station(s: Dictionary, p: Vector2) -> void:
	var size := Vector2(s.footprint[2],s.footprint[3])
	s.ground_xy=a(p);s.visual_xy=a(p-Vector2(0,s.elevation));s.footprint=[snappedf(p.x-size.x/2,0.01),snappedf(p.y-size.y/2,0.01),size.x,size.y]
	s.authority="Spread across owned learning area; stable required groups/outcomes, dry working pad, local cargo handling. Geographic discovery does not grant completion."
func point_gap(i: int) -> float:
	var b=d.regions[i].bounds;var gap := 0.0
	for x in range(int(b[0])+120,int(b[0]+b[2]),360):
		for y in range(int(b[1])+120,int(b[1]+b[3]),360):
			var p := Vector2(x,y)
			if not Geometry2D.is_point_in_polygon(p,polys[i]) or not dry(p,80):continue
			if i<2 and legacy[i].grow(128).has_point(p):continue
			gap=maxf(gap,spacing(p,i))
	return snappedf(gap,1)
func line_hits_box(from: Vector2, to: Vector2, b: Rect2) -> bool:
	if b.has_point(from) or b.has_point(to):return true
	var corners := [b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]
	for j in range(4):
		if Geometry2D.segment_intersects_segment(from,to,corners[j],corners[(j+1)%4])!=null:return true
	return false
func walk_path(from: Vector2, to: Vector2, i: int) -> Array:
	if i>=2 or not line_hits_box(from,to,legacy[i].grow(64)):return [a(from),a(to)]
	# Shortest visibility path around the protected original route envelope.
	var b := legacy[i].grow(96)
	var points := [from,to,b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]
	var distances := [0.0,INF,INF,INF,INF,INF];var previous := [-1,-1,-1,-1,-1,-1];var visited := {}
	for step in range(6):
		var current := -1
		for j in range(6):
			if not visited.has(j) and (current<0 or distances[j]<distances[current]):current=j
		if current<0 or is_inf(distances[current]):break
		visited[current]=true
		for j in range(6):
			if j==current or line_hits_box(points[current],points[j],legacy[i].grow(64)):continue
			var cost: float=distances[current]+points[current].distance_to(points[j])
			if cost<distances[j]:distances[j]=cost;previous[j]=current
	if previous[1]<0:return []
	var result: Array=[];var cursor := 1
	while cursor>=0:result.push_front(a(points[cursor]));cursor=previous[cursor]
	return result
func annotate_path(points: Array) -> Dictionary:
	var samples: Array=[];var total := 0.0
	for j in range(1,points.size()):
		var from := v(points[j-1]);var to := v(points[j]);var length := from.distance_to(to);total+=length
		for step in range(int(ceil(length/24))+1):samples.append(a(from.lerp(to,float(step)/maxi(1,int(ceil(length/24))))))
	var spans: Array=[];var wet_start := -1
	for j in range(samples.size()+1):
		var wet: bool=j<samples.size() and not dry(v(samples[j]),48)
		if wet and wet_start<0:wet_start=maxi(0,j-1)
		if not wet and wet_start>=0:
			spans.append({"from":samples[wet_start],"to":samples[mini(j,samples.size()-1)],"kind":"reserved permanent footbridge/boardwalk","clear_width":96,"support":"Permanent supported deck and dry abutments; no ice assumption or carry jumping"});wet_start=-1
	return {"points":points,"sampled_points":samples,"length_world":snappedf(total,1),"clear_width":96,"water_crossings":spans,"permission":"Entire path stays inside this location's organic permission area; no new progression unlock","support":"Broad supported ground; bridge reservations explicitly cover water. Physical integration remains later work."}
func populate(layout: Dictionary) -> bool:
	d=layout
	for r in d.regions:polys.append(polygon(r.permission_polygon))
	for r in d.regions.slice(0,2):
		var b=r.source_floor_bounds;legacy.append(Rect2(b[0]+r.translation_only[0],b[1]+r.translation_only[1],b[2],b[3]))
	# Keep arrival/exit/main-road geometry and every legacy interaction unchanged.
	for s in d.stations:
		if s.kind=="catalog reservation":continue
		if s.subregion not in ["Z1L1","Z1L2"] and s.kind in ["puzzle court","optional minigame"]:continue
		occupied.append(s)
	var moved := 0
	for i in range(2,18):
		var r: Dictionary=d.regions[i];r.internal_route=[r.entry];r.local_cargo_paths=[]
		for s in d.stations:
			if s.subregion!=r.id or s.kind not in ["puzzle court","optional minigame"]:continue
			var p=best_point(i,Vector2(s.footprint[2],s.footprint[3]))
			if p==null:push_error("Cannot spread worksite "+s.id);return false
			move_station(s,p);occupied.append(s);moved+=1;r.internal_route.append(s.ground_xy)
			var local := annotate_path([s.ground_xy,a(p+Vector2(0,40))])
			local.merge({"id":s.id+".return","turning_pad":128,"scope":"same worksite","recovery":"Newest unlocked local checkpoint; recover unique item once within the same worksite","carry_policy":"Local working/cargo pad. Do not require carrying components across the whole region; any inter-station delivery needs its own measured route."})
			r.local_cargo_paths.append(local)
		r.internal_route.append(r.exit)
	var stops: Array=[];var paths: Array=[];var coverage: Array=[]
	var practice_names := ["Ice or Water?","Evaporation or Condensation?","Sublimation or Deposition?"]
	var practice_rules := ["Observe or replay the existing solid/liquid demonstration; identify state before/after heating or cooling.","Compare existing drying and collected-condensation demonstrations; distinguish evaporation from boiling.","Compare existing controlled solid-to-gas/gas-to-solid demonstrations; identify frost as a sample, never structural support."]
	for i in range(18):
		var r: Dictionary=d.regions[i];var zone := i/6;var count := 0
		while count<3 or (count<8 and point_gap(i)>GAP_TARGET):
			var p=best_point(i,STOP_SIZE,true)
			if p==null:push_error("Cannot place exploration stop in "+r.id);return false
			var kind: String=["free practice","field observation","rest overlook","field observation"][count%4]
			var name: String=practice_names[zone] if count%4==0 else ("Field Notes · "+r.name.trim_prefix("The ") if count%4 in [1,3] else "Scenic Rest · "+r.name.trim_prefix("The "))
			var s := {"id":r.id+".explore"+str(count+1),"subregion":r.id,"name":name,"kind":kind,"ground_xy":a(p),"footprint":[snappedf(p.x-STOP_SIZE.x/2,0.01),snappedf(p.y-STOP_SIZE.y/2,0.01),STOP_SIZE.x,STOP_SIZE.y],"optional":true,"repeatable":true,"rewards":[],"completion_effect":"none","progression_effect":"none","permission_owner":r.id,"requires_completed":r.requires_completed.duplicate(),"activity":practice_rules[zone] if kind=="free practice" else ("Inspect nearby existing zone-kit scenery and describe an observed state change. Read-only field-note interaction; no item collection." if kind=="field observation" else "Explore a scenic turnout and consult existing Guides. Rest is scenic only; it does not heal, save, unlock a checkpoint or change Warmth."),"reuse":"Existing zone props, learning/Guides demonstration and support assets. Review-map icons are vector planning symbols, not new production assets.","support":"Dry 180x140 pad, 96wu approach and permanent ground. No carry or timed-jump requirement."}
			if kind=="free practice":
				for source in d.stations:
					if source.kind=="optional minigame" and source.subregion.begins_with("Z"+str(zone+1)):s.practice_reference=source.id;break
			stops.append(s);occupied.append(s);count+=1
		coverage.append({"subregion":r.id,"added_stops":count,"sampled_max_gap_world":point_gap(i),"target_world":GAP_TARGET,"sampling":"360wu dry-ground grid; source route envelopes excluded, original interactions retained"})
		# Minimum spanning local branches connect every planned worksite and stop.
		var nodes: Array=[]
		if i>=2:
			for s in d.stations:
				if s.subregion==r.id and s.kind not in ["catalog reservation","checkpoint"]:nodes.append(s)
		for s in stops:
			if s.subregion==r.id:nodes.append(s)
		var connected: Array=[nodes.pop_front()]
		while not nodes.is_empty():
			var best_from: Dictionary={};var best_to := -1;var best_length := INF;var best_path: Array=[]
			for source in connected:
				for j in range(nodes.size()):
					var points := walk_path(v(source.ground_xy),v(nodes[j].ground_xy),i)
					if points.is_empty():continue
					var length := 0.0
					for k in range(1,points.size()):length+=v(points[k-1]).distance_to(v(points[k]))
					if length<best_length:best_from=source;best_to=j;best_length=length;best_path=points
			if best_to<0:push_error("Disconnected local exploration network "+r.id);return false
			var dest: Dictionary=nodes.pop_at(best_to);var route := annotate_path(best_path)
			route.merge({"id":r.id+".branch"+str(connected.size()),"subregion":r.id,"from":best_from.id,"to":dest.id,"legacy_policy":"Outside protected source floor envelopes; use existing authored exit/gate adapter to reach surrounding exploration, never paint support across an original puzzle gap" if i<2 else "Local walking approach to scattered worksite; does not solve the worksite"})
			paths.append(route);connected.append(dest)
	d.schema_version=3;d.revision="Populated organic mainland; distributed requirements and optional exploration"
	d.landscape.exploration_stops=stops;d.landscape.local_branches=paths;d.landscape.population_coverage=coverage
	d.landscape.population_policy="Show required interactions and optional exploration by default. No added mandatory objectives, rewards, save keys, checkpoint effects or ability unlocks. Original eight campaign minigames remain authoritative; free practice reuses existing demonstrations. Preserve source route envelopes."
	print("POPULATION / ",moved," distributed worksites / ",stops.size()," optional stops / ",paths.size()," local branches")
	return true
