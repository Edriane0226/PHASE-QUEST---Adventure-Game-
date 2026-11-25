extends SceneTree
## Samples support beside every floor that one ground dump has and the other lacks.
##   Godot --headless --path <project> -s res://tools/world/terrain_bake/seam_check.gd -- <before> <after> [step]
const SUPPORT := preload("res://Scripts/World/terrain_support_profiles.gd")
const COMPARE := preload("res://tools/world/terrain_bake/ground_compare.gd")
const BIN := 96.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var step := float(args[2]) if args.size() > 2 else 3.0
	var sets: Array = []
	for path in [args[0],args[1]]:
		var data: Dictionary = FileAccess.open(path,FileAccess.READ).get_var()
		var zones: Array = []
		for list in data.floors:
			var bins := {}
			for f in list:
				if f[3]:continue
				var box := Rect2(f[5][0],Vector2.ZERO)
				for p in f[5]:box = box.expand(p)
				for x in range(floori(box.position.x/BIN)-1,floori(box.end.x/BIN)+2):
					for y in range(floori(box.position.y/BIN)-1,floori(box.end.y/BIN)+2):
						if not bins.has(Vector2i(x,y)):bins[Vector2i(x,y)] = []
						bins[Vector2i(x,y)].append([f[5],box])
			zones.append({"list":list,"bins":bins})
		sets.append(zones)
	var counts := {"places":0,"samples":0,"point_lost":0,"point_gained":0,"foot_lost":0,"foot_gained":0}
	var shown := 0
	for z in 3:
		var after := {}
		for f in sets[1][z].list:after[f[5]] = true
		for f in sets[0][z].list:
			if f[3] or after.has(f[5]):continue
			counts.places += 1
			# Only thin pieces are walked: the rest of a joined floor did not move.
			if COMPARE._width(f[5]) >= 3.1:continue
			var box := Rect2(f[5][0],Vector2.ZERO)
			for p in f[5]:box = box.expand(p)
			box = box.grow(14)
			var y := box.position.y
			while y < box.end.y:
				var x := box.position.x
				while x < box.end.x:
					var at := Vector2(x,y); x += step
					if not Geometry2D.is_point_in_polygon(at,f[5]):
						var near := INF
						for i in f[5].size():near = minf(near,at.distance_to(Geometry2D.get_closest_point_to_segment(at,f[5][i],f[5][(i+1)%f[5].size()])))
						if near > 14:continue
					counts.samples += 1
					var r: Array = []
					for s in 2:r.append(_look(sets[s][z].bins,at))
					if r[0][0] != r[1][0]:counts["point_lost" if r[0][0] else "point_gained"] += 1
					if r[0][1] != r[1][1]:
						counts["foot_lost" if r[0][1] else "foot_gained"] += 1
						if r[0][1] and shown < 25:shown += 1; print("  foot lost zone ",z+1," at ",at)
				y += step
	print("SEAMCHECK ",counts)
	quit()

func _look(bins: Dictionary, at: Vector2) -> Array:
	var foot: Rect2 = SUPPORT.foot_rect(at)
	var point := false
	var list: Array = []
	for f in bins.get(Vector2i(floori(at.x/BIN),floori(at.y/BIN)),[]):
		if not f[1].intersects(foot.grow(1)):continue
		list.append(f[0])
		if Geometry2D.is_point_in_polygon(at,f[0]):point = true
	return [point,SUPPORT.rectangle_supported(foot,list)]
