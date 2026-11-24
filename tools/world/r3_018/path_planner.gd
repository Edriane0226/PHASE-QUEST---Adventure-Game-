extends RefCounted
## Test-only measured routes. Shipping scene does not auto-solve or auto-navigate.
var geometry: RefCounted
var grid:=AStarGrid2D.new()
var cargo:=false
var fine_grids: Array=[]
var originally_open: Dictionary={}
const STEP:=24.0
func build(model: RefCounted,carry:=false) -> void:
	geometry=model;cargo=carry;grid.region=Rect2i(495,10,345,365);grid.cell_size=Vector2.ONE*STEP;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update();grid.fill_solid_region(grid.region,true)
	var available:=0;var open_cells: Array=[]
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var point:=Vector2(x,y)*STEP
			if geometry.standable(point,carry):grid.set_point_solid(Vector2i(x,y),false);available+=1;open_cells.append(Vector2i(x,y))
	originally_open[grid.get_instance_id()]=open_cells
	print("NAV GRID ",available," supported clear nodes / cargo=",carry)
	for source in geometry.data.sources:
		var b: Array=geometry.data.regions[int(source.subregion.right(1))-1].source_floor_bounds;var origin: Vector2=geometry.v(source.origin)
		var box:=Rect2(b[0]+origin.x,b[1]+origin.y,b[2],b[3]).grow(264)
		var fine:=AStarGrid2D.new();fine.cell_size=Vector2.ONE*8;fine.region=Rect2i(Vector2i((box.position/8).floor()),Vector2i((box.size/8).ceil()));fine.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;fine.update();fine.fill_solid_region(fine.region,true)
		var fine_open: Array=[]
		for y in range(fine.region.position.y,fine.region.end.y):
			for x in range(fine.region.position.x,fine.region.end.x):
				if geometry.standable(Vector2(x,y)*8,carry):fine.set_point_solid(Vector2i(x,y),false);fine_open.append(Vector2i(x,y))
		fine_grids.append(fine)
		originally_open[fine.get_instance_id()]=fine_open
	print("NAV FINE / ",fine_grids.size()," source-only 8wu grids")
func nearest(point: Vector2,max_distance:=180.0) -> Vector2i:
	var cell:=Vector2i((point/STEP).round());var best:=Vector2i(-1,-1);var score:=INF
	var radius:=ceili(max_distance/STEP)
	for x in range(cell.x-radius,cell.x+radius+1):
		for y in range(cell.y-radius,cell.y+radius+1):
			var candidate:=Vector2i(x,y)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):continue
			var gap:=point.distance_to(Vector2(candidate)*STEP)
			if gap<score:best=candidate;score=gap
	return best
func walking(from: Vector2,to: Vector2) -> PackedVector2Array:
	for fine in fine_grids:
		if not fine.region.has_point(Vector2i((from/8).round())) or not fine.region.has_point(Vector2i((to/8).round())):continue
		var from_cell:=fine_nearest(fine,from);var to_cell:=fine_nearest(fine,to)
		if from_cell.x>=0 and to_cell.x>=0:
			var path: PackedVector2Array=fine.get_point_path(from_cell,to_cell)
			if not path.is_empty():return path
	var a:=nearest(from);var b:=nearest(to)
	if a.x<0 or b.x<0:return PackedVector2Array()
	return grid.get_point_path(a,b)
func fine_nearest(fine: AStarGrid2D,point: Vector2) -> Vector2i:
	var center:=Vector2i((point/8).round());var best:=Vector2i(-1,-1);var score:=INF
	for x in range(center.x-7,center.x+8):
		for y in range(center.y-7,center.y+8):
			var cell:=Vector2i(x,y)
			if not fine.is_in_boundsv(cell) or fine.is_point_solid(cell):continue
			var distance:=point.distance_to(Vector2(cell)*8)
			if distance<score:score=distance;best=cell
	return best
func refresh_gate_cells() -> void:
	var boxes: Array=[]
	for b in geometry.blockers:
		if b.gate:boxes.append(b.bounds.grow(48))
	for f in geometry.floors:
		if f.conditional:boxes.append(f.bounds.grow(48))
	for navigation in [grid]+fine_grids:
		var size: float=navigation.cell_size.x
		for box in boxes:
			var area:=Rect2i(Vector2i((box.position/size).floor()),Vector2i((box.size/size).ceil())+Vector2i.ONE).intersection(navigation.region)
			for y in range(area.position.y,area.end.y):
				for x in range(area.position.x,area.end.x):navigation.set_point_solid(Vector2i(x,y),not geometry.standable(Vector2(x,y)*size,cargo))
func safe_at(point: Vector2) -> Vector2:
	var at:=nearest(point)
	return Vector2(at)*STEP if at.x>=0 else Vector2(INF,INF)
func safe_in_region(point: Vector2,id: String) -> Vector2:
	var center:=Vector2i((point/STEP).round());var best:=Vector2(INF,INF);var score:=INF
	for x in range(center.x-8,center.x+9):
		for y in range(center.y-8,center.y+9):
			var cell:=Vector2i(x,y);var at:=Vector2(cell)*STEP
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell) or geometry.region_at(at)!=id:continue
			var gap:=point.distance_to(at)
			if gap<score:score=gap;best=at
	return best
func set_prefix(value: int) -> void:
	geometry.prefix=value
	for navigation in [grid]+fine_grids:
		for cell in originally_open[navigation.get_instance_id()]:navigation.set_point_solid(cell,not geometry.permitted(Vector2(cell)*navigation.cell_size.x))
func plan(from: Vector2,to: Vector2) -> Array:
	var direct:=walking(from,to)
	if not direct.is_empty():return [{"kind":"walk","points":direct}]
	if cargo:return []
	var nodes: Array=[from,to];var jumps: Array=[]
	for source in geometry.data.sources:
		for portal in source.portal_routes:
			for point in portal.points:nodes.append(geometry.v(point))
		var origin: Vector2=geometry.v(source.origin)
		for jump in source.jumps:
			var start: Vector2=geometry.v(jump.from)+origin;var target: Vector2=geometry.v(jump.toward)+origin
			var direction: Vector2=(target-start).normalized()
			# Original fixed travel distance; find a valid authored takeoff and landing pair.
			var chosen: Variant=null;var best_score:=INF
			for dx in range(-16,17,4):
				for dy in range(-16,17,4):
					var p:=start+Vector2(dx,dy);var end:=p+direction*103.6
					if geometry.standable(p,false,true,true) and geometry.standable(end,false,true,true) and Geometry2D.is_point_in_polygon(p-origin,geometry.polygon(jump.takeoff)) and Geometry2D.is_point_in_polygon(end-origin,geometry.polygon(jump.landing)):
						var score:=p.distance_to(start)+end.distance_to(target)
						if score<best_score:best_score=score;chosen=[p,end]
			if chosen==null:continue
			var index:=nodes.size();nodes.append(chosen[0]);nodes.append(chosen[1]);jumps.append({"a":index,"b":index+1,"id":jump.id,"direction":direction})
	var edges: Dictionary={}
	for i in range(nodes.size()):edges[i]=[]
	for i in range(nodes.size()):
		for j in range(i+1,nodes.size()):
			var path:=walking(nodes[i],nodes[j])
			if not path.is_empty():
				var cost:=0.0
				for k in range(1,path.size()):cost+=path[k-1].distance_to(path[k])
				edges[i].append({"to":j,"cost":cost,"step":{"kind":"walk","points":path}})
				var reverse:=path.duplicate();reverse.reverse();edges[j].append({"to":i,"cost":cost,"step":{"kind":"walk","points":reverse}})
	for jump in jumps:
		for pair in [[jump.a,jump.b],[jump.b,jump.a]]:edges[pair[0]].append({"to":pair[1],"cost":110,"step":{"kind":"jump","from":nodes[pair[0]],"to":nodes[pair[1]],"id":jump.id}})
	var distance: Dictionary={0:0.0};var previous: Dictionary={};var visited: Dictionary={}
	for count in range(nodes.size()):
		var current:=-1;var score:=INF
		for i in range(nodes.size()):
			if not visited.has(i) and float(distance.get(i,INF))<score:score=distance[i];current=i
		if current<0:break
		visited[current]=true
		for edge in edges[current]:
			var cost: float=score+edge.cost
			if cost<float(distance.get(edge.to,INF)):distance[edge.to]=cost;previous[edge.to]={"from":current,"step":edge.step}
	var result: Array=[];var cursor:=1
	while previous.has(cursor):result.push_front(previous[cursor].step);cursor=previous[cursor].from
	return result if cursor==0 else []
