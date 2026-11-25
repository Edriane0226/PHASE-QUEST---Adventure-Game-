extends SceneTree
## Finds floors less than 3.1 units wide and joins each one to the neighbour with the longest shared edge.
## Only floors of one district with the same kind, height, condition and body path are joined.
## Writes a plan; merge_slivers.mjs applies it to CampaignWorld.tscn. Changes nothing itself.
##   Godot --headless --path <project> -s res://tools/world/terrain_bake/merge_slivers.gd -- --out=<plan.json>
const REGISTRY := preload("res://Scripts/Content/world_subregions.gd")
const COMPARE := preload("res://tools/world/terrain_bake/ground_compare.gd")
const THIN := 3.1

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var out := "user://merge_plan.json"
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--out="):out = value.trim_prefix("--out=")
	var scene: Node = load("res://World/CampaignWorld.tscn").instantiate()
	var plan: Array = []
	var totals := {"before":0,"after":0,"thin_before":0,"thin_after":0,"sum_before":0.0,"sum_after":0.0,"overlap_removed":0.0,"worst_error":0.0,"tidy_area":0.0}
	for id in REGISTRY.CAMPAIGN_DISTRICTS:
		var district: Node = scene.get_node(REGISTRY.CAMPAIGN_DISTRICTS[id])
		var groups: Dictionary = {}
		for node in district.get_node("Layout/Floors").get_children():
			var key := str([node.get_meta("kind",""),node.get_meta("height",0.0),node.get_meta("conditional",false),node.get_meta("body_path",""),node.transform])
			for name in node.get_meta_list():if not name in ["kind","height","conditional","body_path"]:key += str([name,node.get_meta(name)])
			if not groups.has(key):groups[key] = []
			groups[key].append({"name":str(node.name),"polygon":node.polygon,"from":[str(node.name)],"area":COMPARE._area(node.polygon)})
		for key in groups:
			var list: Array = groups[key]
			totals.before += list.size()
			for f in list:
				totals.sum_before += absf(f.area)
				if COMPARE._width(f.polygon) < THIN:totals.thin_before += 1
			_join(list,totals)
			totals.after += list.size()
			for f in list:
				totals.sum_after += absf(COMPARE._area(f.polygon))
				if COMPARE._width(f.polygon) < THIN:totals.thin_after += 1; print("LEFT ",id," ",f.name," width ",COMPARE._width(f.polygon)," area ",absf(COMPARE._area(f.polygon)))
				if f.from.size() > 1:
					plan.append({"parent":str(REGISTRY.CAMPAIGN_DISTRICTS[id])+"/Layout/Floors","keep":f.name,"remove":f.from.filter(func(n):return n != f.name),"polygon":var_to_str(f.polygon)})
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(plan,"\t"))
	file.close()
	print("MERGE ",totals)
	scene.free()
	quit()

func _join(list: Array, totals: Dictionary) -> void:
	var blocked: Dictionary = {}
	while true:
		var thin: Dictionary = {}
		for f in list:
			if blocked.has(f.name) or COMPARE._width(f.polygon) >= THIN:continue
			if thin.is_empty() or absf(COMPARE._area(f.polygon)) < absf(COMPARE._area(thin.polygon)):thin = f
		if thin.is_empty():return
		var best: Dictionary = {}; var best_shared := .5; var best_shape := PackedVector2Array()
		var box := _box(thin.polygon).grow(.5)
		for f in list:
			if f == thin or not _box(f.polygon).intersects(box):continue
			var merged := Geometry2D.merge_polygons(thin.polygon,f.polygon)
			if merged.size() != 1:continue
			var shared: float = _length(thin.polygon)+_length(f.polygon)-_length(merged[0])
			if shared > best_shared:best = f; best_shared = shared; best_shape = merged[0]
		if best.is_empty():
			blocked[thin.name] = true
			continue
		var overlap := 0.0
		for piece in Geometry2D.intersect_polygons(thin.polygon,best.polygon):overlap += absf(COMPARE._area(piece))
		var error: float = absf(COMPARE._area(best_shape))-(absf(COMPARE._area(thin.polygon))+absf(COMPARE._area(best.polygon))-overlap)
		if absf(error) > 1.0:
			blocked[thin.name] = true
			continue
		totals.overlap_removed += overlap
		totals.worst_error = maxf(totals.worst_error,absf(error))
		best.polygon = _tidy(best_shape,totals)
		best.from.append_array(thin.from)
		list.erase(thin)
		blocked.clear()

## Drops repeated points and points on a straight edge. They move the outline by less than 0.005,
## inside the 0.05 overlap of neighbours, but they confuse Geometry2D.is_point_in_polygon.
func _tidy(p: PackedVector2Array, totals: Dictionary) -> PackedVector2Array:
	var start := absf(COMPARE._area(p))
	var changed := true
	while changed and p.size() > 3:
		changed = false
		for i in p.size():
			var a := p[(i+p.size()-1)%p.size()]; var b := p[(i+1)%p.size()]
			if p[i].distance_to(a) < .005 or p[i].distance_to(Geometry2D.get_closest_point_to_segment(p[i],a,b)) < .002:
				p.remove_at(i); changed = true
				break
	totals.tidy_area += absf(absf(COMPARE._area(p))-start)
	return p

func _box(p: PackedVector2Array) -> Rect2:
	var box := Rect2(p[0],Vector2.ZERO)
	for q in p:box = box.expand(q)
	return box

func _length(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in p.size():sum += p[i].distance_to(p[(i+1)%p.size()])
	return sum
