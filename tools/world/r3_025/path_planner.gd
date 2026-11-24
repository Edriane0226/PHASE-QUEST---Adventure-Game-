extends RefCounted
## Measured navigation only; never shipped as automatic gameplay or a puzzle solver.
func route(geometry: RefCounted,original: PackedVector2Array) -> PackedVector2Array:
	var clear:=true
	for i in range(1,original.size()):
		var count:=maxi(1,ceili(original[i-1].distance_to(original[i])/6))
		for j in range(count+1):
			if not geometry.standable(original[i-1].lerp(original[i],j/float(count))):clear=false;break
		if not clear:break
	if clear:return original
	var box:=Rect2(original[0],Vector2.ZERO)
	for p in original:box=box.expand(p)
	for margin in [64,160,320]:
		var area:=box.grow(margin);var grid:=AStarGrid2D.new();grid.cell_size=Vector2.ONE*8;grid.region=Rect2i(Vector2i((area.position/8).floor()),Vector2i((area.size/8).ceil())+Vector2i.ONE);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update();grid.fill_solid_region(grid.region,true)
		for y in range(grid.region.position.y,grid.region.end.y):
			for x in range(grid.region.position.x,grid.region.end.x):
				if geometry.standable(Vector2(x,y)*8):grid.set_point_solid(Vector2i(x,y),false)
		var from:=nearest(grid,original[0]);var to:=nearest(grid,original[-1])
		if from.x<0 or to.x<0:continue
		var path: PackedVector2Array=grid.get_point_path(from,to)
		if not path.is_empty():return turns(path)
	return PackedVector2Array()
func turns(path: PackedVector2Array) -> PackedVector2Array:
	# Remove only collinear grid points. Original collision-safe segments and
	# every turn remain; no shortcut across corners or unsupported ground.
	if path.size()<3:return path
	var result:=PackedVector2Array([path[0]])
	for i in range(1,path.size()-1):
		var before: Vector2=path[i]-path[i-1];var after: Vector2=path[i+1]-path[i]
		if absf(before.cross(after))>.01 or before.dot(after)<=0:result.append(path[i])
	result.append(path[-1]);return result
func nearest(grid: AStarGrid2D,point: Vector2) -> Vector2i:
	var center:=Vector2i((point/8).round());var best:=Vector2i(-1,-1);var distance:=INF
	for y in range(center.y-3,center.y+4):
		for x in range(center.x-3,center.x+4):
			var key:=Vector2i(x,y)
			if not grid.is_in_boundsv(key) or grid.is_point_solid(key):continue
			var gap:=point.distance_to(Vector2(key)*8)
			if gap<distance:distance=gap;best=key
	return best
