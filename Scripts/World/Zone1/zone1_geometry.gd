extends RefCounted
## Read-only baked terrain/source geometry. Explicit fixture permissions never touch PlayerSave.
const DATA="res://World/Data/zone1-shells.json"
const SUPPORT=preload("res://Scripts/World/terrain_support_profiles.gd")
const CELL:=192.0
var data: Dictionary
var floors: Array=[]
var blockers: Array=[]
var floor_bins: Dictionary={}
var blocker_bins: Dictionary={}
var bridges: Array=[]
var prefix:=0
var science_open:=false
var region_polygons: Array=[]
var checkpoint_spurs: Array=[]
var relief: RefCounted
var terraces: RefCounted
func v(p: Array) -> Vector2:return Vector2(p[0],p[1])
func polygon(points: Array,offset:=Vector2.ZERO) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(v(p)+offset)
	return result
func box_of(points: PackedVector2Array) -> Rect2:
	var box:=Rect2(points[0],Vector2.ZERO)
	for p in points:box=box.expand(p)
	return box
func rect_poly(box: Rect2) -> PackedVector2Array:return PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
func cells(box: Rect2) -> Array:
	var result: Array=[]
	for x in range(floori(box.position.x/CELL),floori(box.end.x/CELL)+1):
		for y in range(floori(box.position.y/CELL),floori(box.end.y/CELL)+1):result.append(Vector2i(x,y))
	return result
func index_record(record: Dictionary,list: Array,bins: Dictionary) -> void:
	record.bounds=box_of(record.polygon);var id:=list.size();list.append(record)
	for key in cells(record.bounds.grow(1)):
		if not bins.has(key):bins[key]=[]
		bins[key].append(id)
func add_floor(p: PackedVector2Array,region: String,kind: String,height:=0.0,conditional:=false,body_path:="") -> void:
	index_record({"polygon":p,"region":region,"kind":kind,"height":height,"conditional":conditional,"body_path":body_path},floors,floor_bins)
func add_blocker(p: PackedVector2Array,region: String,layer: int,gate:=false,source_path:="") -> void:
	index_record({"polygon":p,"region":region,"layer":layer,"gate":gate,"source_path":source_path},blockers,blocker_bins)
func load_data() -> bool:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not parsed is Dictionary:return false
	data=parsed
	for region in data.regions:region_polygons.append(polygon(region.permission_polygon))
	for region in data.regions:
		for points in region.ground_pieces:add_floor(polygon(points),region.id,"mainland")
	for source in data.sources:
		var origin:=v(source.origin)
		for f in source.floors:add_floor(polygon(f.polygon,origin),source.subregion,"legacy",f.height,false,f.get("body_path",""))
		for f in source.conditional_floors:add_floor(polygon(f.polygon,origin),source.subregion,"legacy",f.height,true)
		for portal in source.portal_routes:add_floor(polygon(portal.world_strip),source.subregion,"source portal",0)
		for record in source.collision_index:
			if not record.disabled:add_blocker(polygon(record.polygon,origin),source.subregion,int(record.layer),record.gate,record.source_path)
		# A tall seal spans the only supported path through the protected source moat.
		for portal in source.portal_routes:
			var points: Array=portal.points;var end:=v(points[-1]);var start:=v(points[0]);var at:=end.lerp(start,.2)
			var direction: Vector2=(start-end).normalized();var side:=direction.orthogonal()
			add_blocker(PackedVector2Array([at-side*90-direction*6,at+side*90-direction*6,at+side*90+direction*6,at-side*90+direction*6]),source.subregion,8,true,"SourcePortalSeal")
	# Real permanent dry support is added only at recorded water crossings.
	for branch in data.local_branches:
		for span in branch.water_crossings:add_bridge([v(span.from),v(span.to)],branch.subregion)
	for trail in data.trails:
		for crossing in trail.water_crossings:
			var at:=v(crossing.at);var closest:=Vector2.RIGHT;var distance:=INF
			for j in range(1,trail.sampled_points.size()):
				var from:=v(trail.sampled_points[j-1]);var to:=v(trail.sampled_points[j]);var gap:=at.distance_to(Geometry2D.get_closest_point_to_segment(at,from,to))
				if gap<distance:distance=gap;closest=(to-from).normalized()
			var width:=210.0 if crossing.river=="meltwater_river" else 125.0
			add_bridge([at-closest*(width+120),at+closest*(width+120)],region_at(at))
	if data.has("checkpoint_spurs"):
		for spur in data.checkpoint_spurs:checkpoint_spurs.append(spur);add_bridge([v(spur.from),v(spur.to)],spur.subregion)
	else:
		# A planned shoreline checkpoint needs a permanent deck, never an assumed ice floor.
		for station in data.stations:
			if station.kind!="checkpoint" or int(station.subregion.right(1))<3:continue
			var at:=v(station.ground_xy)
			if supported_box(Rect2(at-Vector2(10,11),Vector2(20,22))):continue
			var target:=Vector2(INF,INF)
			for radius in range(16,193,8):
				for direction in range(32):
					var point:=at+Vector2.RIGHT.rotated(direction*TAU/32)*radius
					if region_at(point)==station.subregion and supported_box(Rect2(point-Vector2(32,32),Vector2(64,64))):target=point;break
				if target.is_finite():break
			if target.is_finite():
				var spur:={"id":station.id,"subregion":station.subregion,"from":[at.x,at.y],"to":[target.x,target.y],"kind":"permanent shoreline checkpoint deck; no science outcome"}
				checkpoint_spurs.append(spur);add_bridge([at,target],station.subregion)
	for decoration in data.decorations:
		if decoration.asset in ["snow_shrub","snow_tuft"]:continue
		var p:=v(decoration.at);var points:=PackedVector2Array()
		for j in range(12):points.append(p+Vector2(cos(j*TAU/12)*14,sin(j*TAU/12)*10))
		add_blocker(points,decoration.subregion,2 if decoration.asset=="snow_rocks" else 1)
	terraces=preload("res://Scripts/World/puzzle_terraces.gd").new();terraces.configure(self)
	relief=preload("res://Scripts/World/terrain_relief.gd").new()
	relief.build(self)
	return true
func add_bridge(line: Array,region: String) -> void:
	for p in Geometry2D.offset_polyline(PackedVector2Array(line),96,Geometry2D.JOIN_SQUARE,Geometry2D.END_SQUARE):
		# Never extend an incidental bridge into an original route's protected envelope.
		var pieces: Array=[p]
		for source in data.sources:
			var cut:=polygon(source.protected_envelope);var next: Array=[]
			for piece in pieces:next.append_array(Geometry2D.clip_polygons(piece,cut))
			pieces=next
		for piece in pieces:
			var clipped: Array=[]
			for r in data.regions:clipped.append_array(Geometry2D.intersect_polygons(piece,polygon(r.permission_polygon)))
			for part in clipped:add_floor(part,region,"bridge");bridges.append(part)
func region_at(point: Vector2) -> String:
	for i in range(region_polygons.size()):
		if Geometry2D.is_point_in_polygon(point,region_polygons[i]):return data.regions[i].id
	return ""
func permitted(point: Vector2) -> bool:
	var id:=region_at(point)
	return not id.is_empty() and int(id.right(1))<=prefix
func height_mainland(point: Vector2) -> float:
	if relief!=null:
		var stacked: float=relief.height_at(point)
		if is_finite(stacked):return stacked
	return base_height_mainland(point)
func base_height_mainland(point: Vector2) -> float:
	var grid=preload("res://Scripts/World/terrain_relief.gd")
	var at: Vector2=grid.block_center(grid.block_of(grid.cell_at(point)))
	# The whole block belongs to the region of its centre, so a border never splits it.
	var owner_point:=at if not region_at(at).is_empty() and not region_at(point).is_empty() else point
	for i in range(data.regions.size()):
		var r: Dictionary=data.regions[i];var p: PackedVector2Array=region_polygons[i]
		if not Geometry2D.is_point_in_polygon(owner_point,p):continue
		if terraces!=null:return terraces.slope_at(self,i,at)+terraces.offset_at(at)
		var distance:=INF
		for j in range(p.size()):distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,p[j],p[(j+1)%p.size()])))
		return roundf(float(r.elevation)*smoothstep(0,320,distance)/20.0)*20.0
	return 0.0
func surface_height(floor: Dictionary,point: Vector2) -> float:
	var grid=preload("res://Scripts/World/terrain_relief.gd")
	var at: Vector2=grid.center(grid.cell_at(point))
	if floor.kind=="mainland":return height_mainland(at)
	if floor.kind in ["bridge","source portal"]:return base_height_mainland(at)
	if floor.kind=="platform":return height_mainland(at)+ceilf(float(floor.height)/20.0)*20.0
	return ceilf(float(floor.height)/20.0)*20.0+(terraces.offset_at(at) if terraces!=null else 0.0)
func nearby(point: Vector2,list: Array,bins: Dictionary) -> Array:
	var result: Array=[]
	for id in bins.get(Vector2i(floori(point.x/CELL),floori(point.y/CELL)),[]):result.append(list[id])
	return result
func height_record(point: Vector2) -> Dictionary:
	var result: Dictionary={}
	for f in nearby(point,floors,floor_bins):
		if f.conditional and not science_open:continue
		if not f.bounds.has_point(point) or not Geometry2D.is_point_in_polygon(point,f.polygon):continue
		var height: float=surface_height(f,point)
		if result.is_empty() or height>result.height:result={"height":height,"body_path":f.body_path,"region":f.region,"kind":f.kind}
	return result
func supported_box(box: Rect2,required_body_path:="") -> bool:
	var candidates: Array=[];var seen: Dictionary={}
	for key in cells(box):
		for id in floor_bins.get(key,[]):
			if seen.has(id):continue
			seen[id]=true;var f: Dictionary=floors[id]
			if f.conditional and not science_open:continue
			if not required_body_path.is_empty() and f.body_path!=required_body_path:continue
			if f.bounds.intersects(box):candidates.append(f.polygon)
	return SUPPORT.rectangle_supported(box,candidates)
func blocked_box(box: Rect2,mask:=11,standing_body_path:="") -> bool:
	var foot:=rect_poly(box);var seen: Dictionary={}
	for key in cells(box):
		for id in blocker_bins.get(key,[]):
			if seen.has(id):continue
			seen[id]=true;var b: Dictionary=blockers[id]
			if b.layer&mask==0 or b.gate and science_open:continue
			if b.layer==2 and not standing_body_path.is_empty() and b.source_path==standing_body_path:continue
			if b.bounds.intersects(box) and not Geometry2D.intersect_polygons(foot,b.polygon).is_empty():return true
	return false
func standable(point: Vector2,cargo:=false,permissions:=true,landing:=false) -> bool:
	if permissions and not permitted(point):return false
	var box:=SUPPORT.cargo_clearance_rect(point) if cargo else SUPPORT.foot_rect(point)
	var body_path: String=str(height_record(point).get("body_path","")) if landing else ""
	return supported_box(box,body_path) and not blocked_box(box,11,body_path)
