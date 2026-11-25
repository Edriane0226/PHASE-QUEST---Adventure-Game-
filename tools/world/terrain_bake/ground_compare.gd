extends SceneTree
## Compares two files of ground_dump.gd.
##   Godot --headless -s res://tools/world/terrain_bake/ground_compare.gd -- <before> <after>
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var a: Dictionary = FileAccess.open(args[0],FileAccess.READ).get_var()
	var b: Dictionary = FileAccess.open(args[1],FileAccess.READ).get_var()
	if a.origin != b.origin or a.size != b.size or a.step != b.step:
		print("GRID differs: ",a.origin,a.size," ",b.origin,b.size)
	var total: int = a.size.x*a.size.y
	var counts := {"samples":total*2,"ground_before":0,"ground_after":0,"record_differs":0,"foot_differs":0,"cargo_differs":0,"stand_differs":0,"height_differs":0}
	var where: Array = []
	for i in total*2:
		if a.records[i] != 0:counts.ground_before += 1
		if b.records[i] != 0:counts.ground_after += 1
		if a.heights[i] != b.heights[i]:counts.height_differs += 1
		var off := false
		if a.records[i] != b.records[i]:counts.record_differs += 1; off = true
		var x: int = a.support[i]^b.support[i]
		if x & 1:counts.foot_differs += 1; off = true
		if x & 2:counts.cargo_differs += 1; off = true
		if x & 4:counts.stand_differs += 1; off = true
		if off and where.size() < 40:where.append([a.origin+Vector2((i%total)%int(a.size.x),(i%total)/int(a.size.x))*a.step,a.support[i],b.support[i]])
	print("COMPARE ",counts)
	for w in where:print("  at ",w)
	var same := 0; var other: Dictionary = {}
	for s in a.scenery:
		if absf(s[2]-s[3]) < .5:same += 1
		else:other[s[2]-s[3]] = int(other.get(s[2]-s[3],0))+1
	print("SCENERY before: on ground ",same," other offsets ",other)
	same = 0; other = {}
	for s in b.scenery:
		if absf(s[2]-s[3]) < .5:same += 1
		else:other[s[2]-s[3]] = int(other.get(s[2]-s[3],0))+1
	print("SCENERY after: on ground ",same," other offsets ",other)
	for d in [a,b]:
		var sums: Array = []
		for list in d.floors:
			var area := 0.0; var thin := 0
			for f in list:
				area += absf(_area(f[5]))
				if _width(f[5]) < 3.1:thin += 1
			sums.append([list.size(),snappedf(area,.0001),thin])
		print("FLOORS [count, area, under 3.1 wide] ",sums)
	quit()

static func _area(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in p.size():sum += (p[i]-p[0]).cross(p[(i+1)%p.size()]-p[0])
	return sum*.5

## Smallest extent over the directions of its edges.
static func _width(p: PackedVector2Array) -> float:
	var best := INF
	for i in p.size():
		var edge := p[(i+1)%p.size()]-p[i]
		if edge.length() < .0001:continue
		var normal := edge.normalized().orthogonal(); var low := INF; var high := -INF
		for q in p:low = minf(low,q.dot(normal)); high = maxf(high,q.dot(normal))
		best = minf(best,high-low)
	return best
