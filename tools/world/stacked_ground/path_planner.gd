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
	for margin in [192,480]:
		var area:=box.grow(margin);var grid:=AStarGrid2D.new();grid.cell_size=Vector2.ONE*24;grid.region=Rect2i(Vector2i((area.position/24).floor()),Vector2i((area.size/24).ceil())+Vector2i.ONE);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update();grid.fill_solid_region(grid.region,true)
		for y in range(grid.region.position.y,grid.region.end.y):
			for x in range(grid.region.position.x,grid.region.end.x):
				if geometry.standable(Vector2(x,y)*24):grid.set_point_solid(Vector2i(x,y),false)
		var from:=nearest(grid,original[0]);var to:=nearest(grid,original[-1])
		if from.x<0 or to.x<0:continue
		var path: PackedVector2Array=grid.get_point_path(from,to)
		if not path.is_empty():return path
	return PackedVector2Array()
func nearest(grid: AStarGrid2D,point: Vector2) -> Vector2i:
	var center:=Vector2i((point/24).round());var best:=Vector2i(-1,-1);var distance:=INF
	for y in range(center.y-3,center.y+4):
		for x in range(center.x-3,center.x+4):
			var key:=Vector2i(x,y)
			if not grid.is_in_boundsv(key) or grid.is_point_solid(key):continue
			var gap:=point.distance_to(Vector2(key)*24)
			if gap<distance:distance=gap;best=key
	return best
