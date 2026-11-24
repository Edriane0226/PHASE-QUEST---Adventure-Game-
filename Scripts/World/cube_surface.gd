extends RefCounted
## Cube caps/bodies clipped to authoritative floors. Rendering never grants floor support.
const GRID = preload("res://Scripts/World/terrain_relief.gd")
const PALETTE = preload("res://Scripts/World/terrain_palette.gd")
const HALF := [Vector2(0,-10),Vector2(20,0),Vector2(0,10),Vector2(-20,0)]
const ROAD_BIN := 256.0
const BAKE_VERSION := 1
const BAKE_DIR := "res://assets/world/terrain_bake_v1/"
var mesh: ArrayMesh
var meshes: Dictionary = {}
var road_bins: Dictionary = {}
var tiles: Dictionary = {}
var stats: Dictionary = {}
var model: RefCounted
var biome := "grass"
var routes: Array = []
var dirty := true
var _science_open := false
var _noise := FastNoiseLite.new()
var _revision := 0
var _instance_revision := -1
var _container: Node2D
var _state_cache: Dictionary = {}
var bake_loaded := false

func configure(value: RefCounted,kind: String) -> void:
	model=value;biome=kind;dirty=true;_state_cache.clear()
	_noise.seed=19017;_noise.frequency=.008;_noise.fractal_octaves=2

func set_routes(values: Array) -> void:
	routes=values;dirty=true;_state_cache.clear()
func bake_signature() -> String:
	# Actual generated geometry, not resource paths: also valid in compiled Android packs.
	# Never deserialize cached support/collisions or progression from a render resource.
	return JSON.stringify([BAKE_VERSION,biome,model.data,model.floors,model.relief.columns,routes,model.science_open]).sha256_text()
func bake_path() -> String:return BAKE_DIR+biome+("-open" if model.science_open else "-closed")+".res"
func restore_bake() -> bool:
	if not ResourceLoader.exists(bake_path()):return false
	var resource=load(bake_path())
	if resource==null or resource.get_meta("signature","")!=bake_signature():return false
	var cached: Dictionary=resource.get_meta("surface",{})
	if not cached.get("meshes") is Dictionary or cached.meshes.is_empty() or not cached.get("tiles") is Dictionary or not cached.get("stats") is Dictionary:return false
	for value in cached.meshes.values():
		if not value is ArrayMesh:return false
	meshes=cached.meshes;tiles=cached.tiles;stats=cached.stats.duplicate(true);stats["baked"]=true
	mesh=meshes.values()[0];_science_open=model.science_open;dirty=false;_revision+=1;bake_loaded=true
	_state_cache[_science_open]={"meshes":meshes,"tiles":tiles,"stats":stats};return true

func _road(points: Array) -> void:
	for i in range(1,points.size()):
		var a: Vector2=model.v(points[i-1]);var b: Vector2=model.v(points[i])
		var box:=Rect2(a,Vector2.ZERO).expand(b).grow(140)
		for x in range(floori(box.position.x/ROAD_BIN),floori(box.end.x/ROAD_BIN)+1):
			for y in range(floori(box.position.y/ROAD_BIN),floori(box.end.y/ROAD_BIN)+1):
				var key:=Vector2i(x,y)
				if not road_bins.has(key):road_bins[key]=[]
				road_bins[key].append([a,b])

func _road_mix(point: Vector2,cell: Vector2i) -> float:
	var distance:=INF
	for segment in road_bins.get(Vector2i(floori(point.x/ROAD_BIN),floori(point.y/ROAD_BIN)),[]):
		distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1])))
	var width:=48.0+_noise.get_noise_2d(point.x,point.y)*24.0
	var wear:=float(posmod(cell.x*127+cell.y*311,101))/100.0
	return (1.0-smoothstep(width-12,width+32,distance))*(.84+wear*.16)

func _height(floor: Dictionary,point: Vector2) -> float:
	return model.surface_height(floor,point)

func _triangle(tool: SurfaceTool,a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:
	tool.set_color(color)
	tool.add_vertex(Vector3(a.x,a.y,0));tool.add_vertex(Vector3(b.x,b.y,0));tool.add_vertex(Vector3(c.x,c.y,0))

func build() -> void:
	var started:=Time.get_ticks_msec()
	tiles={};road_bins.clear()
	for branch in model.data.local_branches:_road(branch.points)
	for trail in model.data.trails:_road(trail.sampled_points)
	for source in model.data.get("sources",[]):
		for portal in source.portal_routes:_road(portal.points)
	for chamber in model.data.get("chambers",[]):_road(chamber.service_loop)
	for route in routes:_road(route.points)
	var bounds: Rect2=model.floors[0].bounds
	for floor in model.floors:bounds=bounds.merge(floor.bounds)
	var grid_bounds:=Rect2(Vector2(GRID.cell_at(bounds.position)),Vector2.ZERO)
	for point in [bounds.end,Vector2(bounds.end.x,bounds.position.y),Vector2(bounds.position.x,bounds.end.y)]:grid_bounds=grid_bounds.expand(Vector2(GRID.cell_at(point)))
	var caps: Array=[];var road_count:=0;var clipped_count:=0
	for x in range(floori(grid_bounds.position.x)-1,ceili(grid_bounds.end.x)+2):
		for y in range(floori(grid_bounds.position.y)-1,ceili(grid_bounds.end.y)+2):
			var cell:=Vector2i(x,y);var at: Vector2=GRID.center(cell)
			var diamond:=PackedVector2Array()
			for p: Vector2 in HALF:diamond.append(at+p)
			var box:=Rect2(at-Vector2(GRID.TILE_SIZE)*.5,Vector2(GRID.TILE_SIZE));var seen: Dictionary={}
			var mix:=_road_mix(at,cell)
			for bin in model.cells(box.grow(.1)):
				for id in model.floor_bins.get(bin,[]):
					if seen.has(id):continue
					seen[id]=true
					var floor: Dictionary=model.floors[id]
					if floor.conditional and not model.science_open:continue
					if not floor.bounds.intersects(box):continue
					# One seamless shell covers both filled TileMap columns and puzzle foundations.
					for polygon: PackedVector2Array in Geometry2D.intersect_polygons(diamond,floor.polygon):
						if polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty():continue
						caps.append({"cell":cell,"at":at,"polygon":polygon,"floor":floor,"road":mix,"height":_height(floor,at)})
						tiles[cell]=true
						if mix>.3 and floor.kind!="bridge":road_count+=1
						if polygon.size()!=4 or not polygon.has(at+HALF[0]):clipped_count+=1
	# Back-to-front cube columns; higher authored floors cover lower overlapping floors.
	caps.sort_custom(func(a,b):return a.at.y<b.at.y if a.at.y!=b.at.y else a.height<b.height)
	var tools: Dictionary={}
	var top: Color=PALETTE.top(biome)
	var dirt: Color={"snow":Color("c3b499"),"grass":Color("b69b72"),"lab":Color("9aaba7")}[biome]
	for cap in caps:
		var chunk:=Vector2i(floori(cap.at.x/768),floori(cap.at.y/384))
		if not tools.has(chunk):
			var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);tools[chunk]=builder
		var tool: SurfaceTool=tools[chunk]
		var points:=PackedVector2Array();var floor: Dictionary=cap.floor
		for p: Vector2 in cap.polygon:points.append(p-Vector2(0,float(cap.height)))
		var tint:=float(posmod(cap.cell.x*73+cap.cell.y*151,101))/100.0
		var color: Color=top.lightened((tint-.5)*.035)
		if floor.kind=="bridge":color=Color("ae9570") if biome!="lab" else Color("8eaaa7")
		else:color=color.lerp(dirt,float(cap.road))
		# Opaque sides extend through every 20px stratum down to the foundation.
		for i in range(points.size()):
			var next: int=(i+1)%points.size();var a: Vector2=points[i];var b: Vector2=points[next]
			var edge: Vector2=cap.polygon[next]-cap.polygon[i]
			var outward:=edge.orthogonal()
			if Geometry2D.is_point_in_polygon((cap.polygon[i]+cap.polygon[next])*.5+outward.normalized(),cap.polygon):outward=-outward
			if outward.y<=.01 or absf(a.x-b.x)<.01:continue
			var neighbor: Dictionary=model.height_record((cap.polygon[i]+cap.polygon[next])*.5+outward.normalized()*.5)
			var edge_height: float=float(cap.height)
			if not neighbor.is_empty() and float(neighbor.height)>=edge_height-.1:continue
			var side: Color=PALETTE.LEFT[biome] if outward.x<0 else PALETTE.RIGHT[biome]
			var bottom: float=float(neighbor.height) if not neighbor.is_empty() else -20.0
			for z in range(floori(bottom/GRID.CUBE_STEP_PX),ceili(edge_height/GRID.CUBE_STEP_PX)):
				var lower: float=maxf(bottom,z*GRID.CUBE_STEP_PX);var upper: float=minf(edge_height,(z+1)*GRID.CUBE_STEP_PX)
				var upper_a: Vector2=cap.polygon[i]-Vector2(0,upper);var upper_b: Vector2=cap.polygon[next]-Vector2(0,upper)
				var bottom_a: Vector2=cap.polygon[i]-Vector2(0,lower);var bottom_b: Vector2=cap.polygon[next]-Vector2(0,lower)
				_triangle(tool,upper_a,upper_b,bottom_b,side);_triangle(tool,upper_a,bottom_b,bottom_a,side)
		var indices:=Geometry2D.triangulate_polygon(points)
		for i in range(0,indices.size(),3):_triangle(tool,points[indices[i]],points[indices[i+1]],points[indices[i+2]],color)
	meshes={}
	for chunk in tools:meshes[chunk]=tools[chunk].commit()
	mesh=meshes.values()[0] if not meshes.is_empty() else null
	_revision+=1
	_science_open=model.science_open;dirty=false
	stats={"cells":tiles.size(),"caps":caps.size(),"road_caps":road_count,"clipped_caps":clipped_count,"render_chunks":meshes.size(),"build_ms":Time.get_ticks_msec()-started}
	_state_cache[_science_open]={"meshes":meshes,"tiles":tiles,"stats":stats}

func draw_surface(canvas: Node2D) -> void:
	if dirty:
		if not restore_bake():build()
	elif _science_open!=model.science_open:
		if _state_cache.has(model.science_open):
			var cached: Dictionary=_state_cache[model.science_open]
			meshes=cached.meshes;tiles=cached.tiles;stats=cached.stats;_science_open=model.science_open;_revision+=1
		elif not restore_bake():build()
	if _instance_revision==_revision:return
	if not is_instance_valid(_container):
		_container=Node2D.new();_container.name="CubeSurfaceChunks";canvas.add_child(_container)
	for child in _container.get_children():child.free()
	for chunk in meshes:
		var instance:=MeshInstance2D.new();instance.name="Chunk_%d_%d"%[chunk.x,chunk.y];instance.mesh=meshes[chunk];_container.add_child(instance)
	_instance_revision=_revision
