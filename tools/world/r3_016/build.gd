extends SceneTree
## OFF-TREE source extraction + native terrain baking. Never calls level _ready or puzzle methods.
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
var layout: Dictionary
var data: Dictionary
var water: Array=[]
var exclusions: Array=[]
var source_origins: Array=[]
var portal_boxes: Array=[]
func _initialize() -> void:call_deferred("run")
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
func owned(node: Node,owner_node: Node) -> void:
	for child in node.get_children():child.owner=owner_node;owned(child,owner_node)
func extract_source(number: int) -> Dictionary:
	var r: Dictionary=layout.regions[number-1];var origin:=v(r.translation_only)
	var scene=load("res://Zone_1/Levels/wrld_lvl_%d.tscn"%number).instantiate()
	var record:={"subregion":r.id,"origin":a(origin),"floors":[],"conditional_floors":[],"collision_index":[],"source_anchors":r.source_anchors,"portal_routes":[],"jumps":[],"scenery":[],"body_scene":"res://World/Zone1/Legacy/%sBodies.tscn"%r.id,"visual_scene":"res://World/Zone1/Legacy/%sDetails.tscn"%r.id}
	for route in scene.get_node("TraversalMarkers").get_children():
		var takeoff=route.get_node_or_null("Takeoff");var landing=route.get_node_or_null("Landing")
		if not takeoff or not landing:continue
		var start_poly:=transformed(takeoff.polygon,transform_of(takeoff,scene));var end_poly:=transformed(landing.polygon,transform_of(landing,scene))
		var start:=Vector2.ZERO;var end:=Vector2.ZERO
		for p in start_poly:start+=p/start_poly.size()
		for p in end_poly:end+=p/end_poly.size()
		record.jumps.append({"id":route.get_meta("obstacle_id",""),"takeoff":arr(start_poly),"landing":arr(end_poly),"from":a(start),"toward":a(end)})
	var floors: Array=[]
	if number==1:
		var cells: Dictionary={}
		for node in scene.get_node("Terrain/SnowSurface").get_children():
			if not node is Polygon2D or not str(node.name).begins_with("SnowRow_"):continue
			var p:=transformed(node.polygon,transform_of(node,scene));var low:=Vector2i(2147483647,2147483647);var high:=Vector2i(-2147483648,-2147483648)
			for point in p:
				var cell:=Vector2i(roundi(point.x/80+point.y/40),roundi(point.y/40-point.x/80));low=low.min(cell);high=high.max(cell)
			for x in range(low.x-1,high.x+2):
				for y in range(low.y-1,high.y+2):
					if Geometry2D.is_point_in_polygon(Vector2((x-y)*40,(x+y)*20),p):cells[Vector2i(x,y)]=true
		# Same direct TileMapLayer and nearest-cell convention as garden_layout.readTerrain.
		for layer in scene.get_node("Terrain").get_children():
			if not layer is TileMapLayer:continue
			for tile in layer.get_used_cells():
				var point: Vector2=transform_of(layer,scene)*layer.map_to_local(tile)
				cells[Vector2i(roundi(point.x/80+point.y/40),roundi(point.y/40-point.x/80))]=true
		for cell in cells:
			var point:=Vector2((cell.x-cell.y)*40,(cell.x+cell.y)*20)
			floors.append(PackedVector2Array([point+Vector2(0,-20),point+Vector2(40,0),point+Vector2(0,20),point+Vector2(-40,0)]))
		record.support_method="Exact original garden_layout cell raster and nearest-cell diamond support, including direct River layer; no level _ready invoked"
	else:
		for node in scene.get_node("Ground").get_children():
			if node is Polygon2D:
				var p:=transformed(node.polygon,transform_of(node,scene))
				if node.visible:floors.append(p)
				else:record.conditional_floors.append({"source_path":str(scene.get_path_to(node)),"polygon":arr(p),"height":0})
		# Exact generated exit deck from existing frozen_sunlit_cache.build_exit_support.
		for b in [Rect2(1740,80,120,170),Rect2(1710,-40,180,120)]:
			var p:=PackedVector2Array()
			for q in box_poly(b):p.append(Vector2(q.x+.5*(q.y-380),380+.5*(q.y-380)-.35*(q.x-180)))
			record.conditional_floors.append({"source_path":"Generated counterweight exit deck","polygon":arr(p),"height":0})
	# Keep original rows: unioning point-touching tiles can produce self-touching contours.
	for p in floors:record.floors.append({"source_path":"original source floor polygon","polygon":arr(p),"height":0})
	if number==1:
		for shelf in scene.get_node("Terrain/JumpSurfaces").get_children():
			var node=shelf.get_node_or_null("WalkableSurface")
			if node:record.floors.append({"source_path":str(scene.get_path_to(node)),"polygon":arr(transformed(node.polygon,transform_of(node,scene))),"height":float(shelf.get_meta("elevation",0)),"body_path":str(scene.get_path_to(shelf.get_node("LowStoneBody")))})
	var floor_box: Array=r.source_floor_bounds
	var envelope:=Rect2(floor_box[0]+origin.x,floor_box[1]+origin.y,floor_box[2],floor_box[3]).grow(160)
	var all_vertices:=PackedVector2Array()
	for p in floors:
		for point in p:all_vertices.append(point+origin)
	for f in record.conditional_floors:
		for point in poly(f.polygon):all_vertices.append(point+origin)
	var hull:=Geometry2D.convex_hull(all_vertices)
	if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.remove_at(hull.size()-1)
	var natural_envelope: PackedVector2Array=poly(arr(Geometry2D.offset_polygon(hull,160,Geometry2D.JOIN_ROUND)[0]))
	record.protected_envelope=arr(natural_envelope)
	exclusions.append(natural_envelope);source_origins.append(origin)
	var portals: Array=[]
	if number==1:portals.append([v(r.exit),Vector2(envelope.position.x-80,r.exit[1])])
	else:
		portals.append([v(r.entry),Vector2(envelope.position.x-80,r.entry[1])])
		portals.append([v(r.exit),Vector2(r.exit[0],envelope.position.y-80)])
	var strips: Array=[]
	for path in portals:
		var line:=PackedVector2Array(path);var offset:=Geometry2D.offset_polyline(line,80,Geometry2D.JOIN_SQUARE,Geometry2D.END_SQUARE)
		for strip in offset:strips.append(strip);portal_boxes.append(bounds(strip))
		record.portal_routes.append({"points":[a(path[0]),a(path[1])],"width":160,"permission":"source exit/arrival seal; only isolated traversal fixture may open","world_strip":arr(offset[0])})
	var bodies:=Node2D.new();bodies.name=r.id+"SourceBodies"
	var native_details:=Node2D.new();native_details.name=r.id+"StaticDetails";native_details.y_sort_enabled=true
	for parent_path in ["Actors","Scenery"]:
		var container=scene.get_node_or_null(parent_path)
		if not container:continue
		for actor in container.get_children():
			if not actor is Node2D or actor.name=="Player" or "Professor" in str(actor.name):continue
			var kind:=str(actor.get_meta("propKind",str(actor.get("kind")))).to_lower();var name_lower:=str(actor.name).to_lower();var asset:=""
			if kind=="pine" or "pine" in name_lower or "fir" in name_lower:asset="snow_tree_pine"
			elif "birch" in name_lower:asset="snow_tree_birch"
			elif kind=="tree" or "grove" in name_lower:asset="snow_tree_young"
			elif kind in ["rock","rubble","pillar"] or "cairn" in name_lower or "bluff" in name_lower:asset="snow_rocks"
			elif kind=="flowers":asset="snow_flower"
			elif kind=="shrub" or "alpineplant" in name_lower:asset="snow_shrub"
			elif name_lower=="lowlog":asset="fallen_log"
			if not asset.is_empty():
				record.scenery.append({"source_path":str(scene.get_path_to(actor)),"at":a(transform_of(actor,scene).origin),"asset":asset});continue
			if kind not in ["lantern","sign"] and not name_lower.begins_with("waypoint"):continue
			# Retain valid source lantern/sign/statue artwork where no replacement is required.
			var anchor:=Node2D.new();anchor.name=str(actor.name);anchor.transform=transform_of(actor,scene);native_details.add_child(anchor)
			for original in actor.find_children("*","Sprite2D",true,false):
				var sprite:=Sprite2D.new();sprite.name=str(original.name);sprite.texture=original.texture;sprite.centered=original.centered;sprite.offset=original.offset;sprite.region_enabled=original.region_enabled;sprite.region_rect=original.region_rect;sprite.material=original.material;sprite.modulate=original.modulate;sprite.transform=transform_of(actor,scene).affine_inverse()*transform_of(original,scene);anchor.add_child(sprite)
	owned(native_details,native_details);var details_packed:=PackedScene.new();details_packed.pack(native_details);ResourceSaver.save(details_packed,record.visual_scene);native_details.free()
	for source in scene.find_children("*","StaticBody2D",true,false):
		var source_path:=str(scene.get_path_to(source))
		if source_path.begins_with("Actors/Player"):continue
		if "ProfessorScaldwell" in source_path:continue # Shared Professor moves with its active placement anchor.
		# Partial R2 012 already retires these collisions at runtime. Preserve that exact scope.
		if number==1 and (source_path.begins_with("Actors/brazier0/") or source_path.begins_with("Actors/HeaterModule/") or source_path.begins_with("Actors/HeaterDock/")):continue
		var body:=StaticBody2D.new();body.name=source_path.replace("/","_");body.collision_layer=source.collision_layer;body.collision_mask=source.collision_mask;body.set_meta("source_path",source_path)
		var gate: bool=(number==1 and (source_path.begins_with("Actors/ice") or source_path.begins_with("Actors/exit/") or "ReturnGate" in source_path)) or (number==2 and source_path.begins_with("SolidBarriers/") and not "WalkwayWall" in source_path)
		body.set_meta("science_gate",gate);bodies.add_child(body)
		for collision in source.get_children():
			if not collision is CollisionShape2D and not collision is CollisionPolygon2D:continue
			var t:=transform_of(collision,scene);var pieces: Array=[]
			if collision is CollisionShape2D and collision.shape:pieces=primitive(collision.shape)
			elif collision is CollisionPolygon2D:pieces=[collision.polygon]
			for p in pieces:
				var global_poly:=transformed(p,t);var local_cuts: Array=[]
				# Only the intended source shoreline portal may be opened, never another gap.
				if source_path=="IslandEdges":
					for strip in strips:local_cuts.append(transformed(strip,Transform2D(0,-origin)))
				for remnant in subtract([global_poly],local_cuts):
					if remnant.size()<3:continue
					var shape:=CollisionPolygon2D.new();shape.polygon=remnant;shape.disabled=collision.disabled;body.add_child(shape)
					record.collision_index.append({"source_path":source_path,"polygon":arr(remnant),"layer":source.collision_layer,"disabled":collision.disabled,"gate":gate})
		if body.get_child_count()==0:body.free()
	owned(bodies,bodies)
	var packed:=PackedScene.new();packed.pack(bodies)
	ResourceSaver.save(packed,record.body_scene)
	bodies.free();scene.free();return record
func run() -> void:
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://layout/layout.json"))
	DirAccess.make_dir_recursive_absolute("res://World/Zone1/Legacy")
	data={"version":1,"scope":"R3 016 shells only; no campaign readiness or puzzle logic","regions":layout.regions.slice(0,6),"stations":[],"exploration_stops":[],"local_branches":[],"trails":[],"sources":[],"water":[],"decorations":[],"layout_hash":FileAccess.get_sha256("res://layout/layout.json")}
	for river in layout.landscape.waterways:
		var line:=poly(river.points)
		for p in Geometry2D.offset_polyline(line,river.width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):water.append(p)
	for lake in layout.landscape.lakes:
		var p:=PackedVector2Array()
		for j in range(48):p.append(v(lake.center)+Vector2(cos(j*TAU/48)*lake.radii[0],sin(j*TAU/48)*lake.radii[1]))
		water.append(p)
	for p in water:data.water.append(arr(p))
	for number in [1,2]:data.sources.append(extract_source(number))
	for station in layout.stations:
		if station.subregion.begins_with("Z1"):data.stations.append(station)
	for stop in layout.landscape.exploration_stops:
		if stop.subregion.begins_with("Z1"):data.exploration_stops.append(stop)
	for branch in layout.landscape.local_branches:
		if branch.subregion.begins_with("Z1"):data.local_branches.append(branch)
	for trail in layout.landscape.trails:
		if trail.a.begins_with("Z1") and trail.b.begins_with("Z1"):data.trails.append(trail)
	for r in data.regions:
		var protected_cuts: Array=[]
		for cut in exclusions:protected_cuts.append_array(Geometry2D.offset_polygon(cut,.1))
		r.ground_pieces=bake_ground(poly(r.permission_polygon),water+protected_cuts)
		print("GROUND ",r.id," / ",r.ground_pieces.size()," pieces")
	# Tree/rock placement uses existing assets; measured activity pads and access lanes stay clear.
	var rng:=RandomNumberGenerator.new();rng.seed=160016
	for r in data.regions:
		var b: Array=r.bounds;var count:=0
		for attempt in range(1100):
			var p:=Vector2(rng.randf_range(b[0],b[0]+b[2]),rng.randf_range(b[1],b[1]+b[3]));var allowed:=Geometry2D.is_point_in_polygon(p,poly(r.permission_polygon))
			for cut in water+exclusions:
				if Geometry2D.is_point_in_polygon(p,cut) or bounds(cut).grow(50).has_point(p) and cut in exclusions:allowed=false
			for s in data.stations+data.exploration_stops:
				if s.subregion==r.id:
					var f: Array=s.footprint
					if Rect2(f[0],f[1],f[2],f[3]).grow(96).has_point(p):allowed=false
			for branch in data.local_branches:
				for j in range(1,branch.points.size()):
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,v(branch.points[j-1]),v(branch.points[j])))<120:allowed=false
			for trail in data.trails:
				for j in range(1,trail.sampled_points.size()):
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,v(trail.sampled_points[j-1]),v(trail.sampled_points[j])))<140:allowed=false
			for old in data.decorations:
				if p.distance_to(v(old.at))<145:allowed=false
			if not allowed:continue
			data.decorations.append({"subregion":r.id,"at":a(p),"asset":["snow_tree_pine","snow_tree_young","snow_tree_birch","snow_rocks","snow_shrub","snow_tuft"][count%6]});count+=1
			if count>=100:break
	FileAccess.open("res://World/Data/zone1-shells.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	var geometry=load("res://Scripts/World/Zone1/zone1_geometry.gd").new()
	if not geometry.load_data():push_error("Cannot calibrate shoreline checkpoint decks");quit(1);return
	data.checkpoint_spurs=geometry.checkpoint_spurs
	FileAccess.open("res://World/Data/zone1-shells.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("R3 016 BAKE PASS / 6 organic shells / 2 off-tree source inserts / ",data.stations.size()," stations / ",data.decorations.size()," scenery instances")
	quit()
