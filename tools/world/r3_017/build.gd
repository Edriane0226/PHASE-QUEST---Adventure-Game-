extends SceneTree
var layout: Dictionary
var data: Dictionary
func _initialize() -> void:call_deferred("run")
func run() -> void:
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://layout/layout.json"))
	data={"version":1,"scope":"R3 017 sunny terrain shells only; no campaign/puzzle/save authority","regions":layout.regions.slice(6,12),"stations":[],"exploration_stops":[],"local_branches":[],"trails":[],"sources":[],"water":[],"decorations":[],"equipment":[],"solids":[],"travel_reserves":[],"layout_hash":FileAccess.get_sha256("res://layout/layout.json")}
	var water: Array=[]
	for river in layout.landscape.waterways:
		water.append_array(Geometry2D.offset_polyline(poly(river.points),river.width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
	for lake in layout.landscape.lakes:
		var p:=PackedVector2Array()
		for j in range(48):p.append(v(lake.center)+Vector2(cos(j*TAU/48)*lake.radii[0],sin(j*TAU/48)*lake.radii[1]))
		water.append(p)
	for p in water:data.water.append(arr(p))
	for s in layout.stations:
		if s.subregion.begins_with("Z2"):data.stations.append(s)
	for s in layout.landscape.exploration_stops:
		if s.subregion.begins_with("Z2"):data.exploration_stops.append(s)
	for b in layout.landscape.local_branches:
		if b.subregion.begins_with("Z2"):data.local_branches.append(b)
	for t in layout.landscape.trails:
		if t.a.begins_with("Z2") and t.b.begins_with("Z2"):data.trails.append(t)
	for r in data.regions:
		r.ground_pieces=bake_ground(poly(r.permission_polygon),water)
		print("SUNNY GROUND ",r.id," / ",r.ground_pieces.size()," pieces")
	for connection in layout.connections:
		if connection.id not in ["Z1L6--Z2L1","Z2L6--Z3L1"]:continue
		data.travel_reserves.append({"id":connection.id,"kind":connection.kind,"local_anchor":connection.destination_anchor if connection.destination=="Z2L1" else connection.source_anchor,"source_anchor":connection.source_anchor,"destination_anchor":connection.destination_anchor,"polyline":connection.polyline,"carry":connection.carry,"prerequisite":connection.prerequisite,"runtime":"geographic landing/approach only; no travel or unlock callback"})
	write_data()
	var geometry=load("res://Scripts/World/Zone2/zone2_geometry.gd").new()
	if not geometry.load_data():push_error("Cannot load sunny terrain bake");quit(1);return
	geometry.prefix=6
	data.checkpoint_spurs=geometry.checkpoint_spurs
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_2/world_v1/kit_catalog.json"))
	var groups: Dictionary={}
	for e in catalog.entries:
		if not groups.has(e.group):groups[e.group]=e
	for s in data.stations:
		var placed: Array=[]
		var required: Array=s.required_groups.duplicate()
		if s.id=="Z2L1.entry":required.append("landing_plank")
		elif s.id=="Z2L6.exit":required.append("water_lift")
		for group in required:
			if not groups.has(group):push_error("Missing accepted Zone2 asset "+group);quit(1);return
			var entry: Dictionary=groups[group];var found:=false
			# Place equipment around clear 96wu working center; guard hot machinery with extra solid margin.
			for row in range(4):
				if found:break
				for angle in [-90,-45,-135,0,180,45,135,90]:
					var at:=v(s.ground_xy)+Vector2.RIGHT.rotated(deg_to_rad(angle))*(140+row*90)
					var f: Array=entry.footprint_world;var box:=Rect2(at+Vector2(f[0],f[1]),Vector2(f[2],f[3]))
					var hot: bool=group in ["boiler","model_turbine","engine_assembly"]
					box=box.grow(20 if hot else 6)
					if geometry.region_at(at)!=s.subregion or not geometry.supported_box(box.grow(18)) or geometry.blocked_box(box.grow(16)):continue
					var clear:=true
					# Keep authored path ribbons outside machinery/guard collision envelopes.
					var clearance:=maxf(box.size.x,box.size.y)/2+42
					for branch in data.local_branches:
						for j in range(1,branch.points.size()):
							if at.distance_to(Geometry2D.get_closest_point_to_segment(at,v(branch.points[j-1]),v(branch.points[j])))<clearance:clear=false
					for trail in data.trails:
						for j in range(1,trail.sampled_points.size()):
							if at.distance_to(Geometry2D.get_closest_point_to_segment(at,v(trail.sampled_points[j-1]),v(trail.sampled_points[j])))<clearance:clear=false
					for other in data.stations+data.exploration_stops:
						if box.grow(72).has_point(v(other.ground_xy)):clear=false;break
					if not clear:continue
					var points:=box_poly(box)
					data.equipment.append({"station":s.id,"subregion":s.subregion,"asset":entry.id,"group":group,"at":a(at),"hot_guard":hot,"safe_working_center":s.ground_xy})
					data.solids.append({"subregion":s.subregion,"polygon":arr(points),"layer":1,"kind":"guarded hot equipment" if hot else "equipment footprint","station":s.id})
					geometry.add_blocker(points,s.subregion,1);placed.append(at);found=true;break
			if not found:push_error("No dry clear equipment slot "+s.id+":"+group);quit(1);return
	var rng:=RandomNumberGenerator.new();rng.seed=170017
	for r in data.regions:
		var b: Array=r.bounds;var count:=0
		for attempt in range(1800):
			var at:=Vector2(rng.randf_range(b[0],b[0]+b[2]),rng.randf_range(b[1],b[1]+b[3]))
			if geometry.region_at(at)!=r.id or not geometry.standable(at):continue
			var clear:=true
			for s in data.stations+data.exploration_stops:
				var f: Array=s.footprint
				if Rect2(f[0],f[1],f[2],f[3]).grow(200).has_point(at):clear=false;break
			if not clear:continue
			for branch in data.local_branches:
				for j in range(1,branch.points.size()):
					if at.distance_to(Geometry2D.get_closest_point_to_segment(at,v(branch.points[j-1]),v(branch.points[j])))<120:clear=false
			for trail in data.trails:
				for j in range(1,trail.sampled_points.size()):
					if at.distance_to(Geometry2D.get_closest_point_to_segment(at,v(trail.sampled_points[j-1]),v(trail.sampled_points[j])))<140:clear=false
			for old in data.decorations:
				if at.distance_to(v(old.at))<145:clear=false
			if not clear:continue
			var asset: String=["sun_tree_young","sun_tree_orchard","sun_tree_ripe","sun_rocks","flowers","reeds"][count%6]
			data.decorations.append({"subregion":r.id,"at":a(at),"asset":asset});count+=1
			if asset not in ["flowers","reeds"]:
				var points:=box_poly(Rect2(at-Vector2(14,10),Vector2(28,20)))
				data.solids.append({"subregion":r.id,"polygon":arr(points),"layer":2 if asset=="sun_rocks" else 1,"kind":"scenery"});geometry.add_blocker(points,r.id,2 if asset=="sun_rocks" else 1)
			if count>=85:break
	write_data()
	print("R3 017 BAKE PASS / ",data.stations.size()," stations / ",data.equipment.size()," production props / ",data.decorations.size()," scenery")
	quit()
func write_data() -> void:
	FileAccess.open("res://World/Data/zone2-shells.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func v(p: Array) -> Vector2:return Vector2(p[0],p[1])
func a(p: Vector2) -> Array:return [snappedf(p.x,.001),snappedf(p.y,.001)]
func poly(points: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(v(p))
	return result
func arr(points: PackedVector2Array) -> Array:
	var result: Array=[]
	for p in points:result.append(a(p))
	return result
func box_poly(box: Rect2) -> PackedVector2Array:return PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
func bounds(p: PackedVector2Array) -> Rect2:
	var b:=Rect2(p[0],Vector2.ZERO)
	for q in p:b=b.expand(q)
	return b
func transform_of(node: Node,root: Node) -> Transform2D:
	var result:=Transform2D.IDENTITY;var cursor: Node=node
	while cursor!=root:
		if cursor is Node2D:result=cursor.transform*result
		cursor=cursor.get_parent()
	return result
func transformed(points: PackedVector2Array,t: Transform2D) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(t*p)
	return result
func primitive(shape: Shape2D) -> Array:
	if shape is RectangleShape2D:return [box_poly(Rect2(-shape.size/2,shape.size))]
	if shape is ConvexPolygonShape2D:return [shape.points]
	if shape is ConcavePolygonShape2D:
		var result: Array=[]
		for i in range(0,shape.segments.size(),2):
			var from: Vector2=shape.segments[i];var to: Vector2=shape.segments[i+1];var normal: Vector2=(to-from).normalized().orthogonal()*1.1
			result.append(PackedVector2Array([from+normal,to+normal,to-normal,from-normal]))
		return result
	var points:=PackedVector2Array()
	if shape is CircleShape2D or shape is CapsuleShape2D:
		for j in range(32):
			var p: Vector2=Vector2.RIGHT.rotated(j*TAU/32)*shape.radius
			if shape is CapsuleShape2D:p.y+=signf(p.y)*maxf(0,shape.height/2-shape.radius)
			points.append(p)
		return [points]
	return []
func merge_all(input: Array) -> Array:
	var result: Array=[]
	for p in input:
		var combined: PackedVector2Array=p;var index:=0
		while index<result.size():
			var joined:=Geometry2D.merge_polygons(combined,result[index])
			if joined.size()==1:combined=joined[0];result.remove_at(index);index=0
			else:index+=1
		result.append(combined)
	return result
func subtract(pieces: Array,cuts: Array) -> Array:
	var result: Array=pieces
	for cut in cuts:
		var next: Array=[];var cb:=bounds(cut)
		for piece in result:
			if not bounds(piece).intersects(cb):next.append(piece);continue
			next.append_array(Geometry2D.clip_polygons(piece,cut))
		result=next
	return result
func bake_ground(area: PackedVector2Array,cuts: Array) -> Array:
	# Split at every cut X coordinate so enclosed holes become open simple pieces.
	var b:=bounds(area);var xs: Array[float]=[b.position.x,b.end.x]
	for cut in cuts:
		if not b.intersects(bounds(cut)):continue
		for q in cut:
			if q.x>b.position.x and q.x<b.end.x:xs.append(q.x)
	xs.sort();var result: Array=[]
	for j in range(1,xs.size()):
		if xs[j]-xs[j-1]<.01:continue
		var strip:=box_poly(Rect2(xs[j-1],b.position.y-10,xs[j]-xs[j-1],b.size.y+20))
		var pieces:=subtract(Geometry2D.intersect_polygons(area,strip),cuts)
		for piece in pieces:
			if piece.size()<3:continue
			if Geometry2D.is_polygon_clockwise(piece):piece.reverse()
			if Geometry2D.triangulate_polygon(piece).is_empty():push_error("Untriangulatable land piece");quit(1);return []
			# Shared boolean vertices use float32. Tiny overlap closes numeric strip seams;
			# protected cuts have a larger .1wu inset, so this cannot fill a source gap.
			for expanded in Geometry2D.offset_polygon(piece,.025,Geometry2D.JOIN_MITER):result.append(arr(expanded))
	return result
