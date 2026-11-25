extends SceneTree
## Read-only. Samples ground records and support of CampaignWorld.tscn, so two versions can be compared.
## Run headless with a disposable profile folder:
##   Godot --headless --path <project> -s res://tools/world/terrain_bake/ground_dump.gd -- --out=<file> [--step=24]
## The file holds one record for each sample, and the authored scenery and rooms.
const CAMPAIGN := preload("res://Scripts/World/Runtime/campaign_world.gd")
const DISTRICT := preload("res://Scripts/World/Runtime/authored_district.gd")
const REGISTRY := preload("res://Scripts/Content/world_subregions.gd")

func _initialize() -> void:run.call_deferred()

func argument(key: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--"+key+"="):return value.trim_prefix("--"+key+"=")
	return fallback

func run() -> void:
	await process_frame
	var scene: Node = load("res://World/CampaignWorld.tscn").instantiate()
	scene.set_script(null)
	root.add_child(scene)
	var models: Array = []
	for type in CAMPAIGN.GEOMETRY_MODELS:
		var model: RefCounted = type.new()
		model.data = {"regions":[],"stations":[],"equipment":[],"exploration_stops":[],"sources":[],"trails":[],"local_branches":[],"review_routes":[],"chambers":[]}
		models.append(model)
	for id in REGISTRY.CAMPAIGN_DISTRICTS:
		scene.get_node(REGISTRY.CAMPAIGN_DISTRICTS[id]).append_geometry(models[int(id.substr(1,1))-1])
	for model in models:DISTRICT.prepare_terrain(model)
	var box := Rect2()
	for model in models:
		for floor in model.floors:box = floor.bounds if box.size == Vector2.ZERO else box.merge(floor.bounds)
	var step := int(argument("step","24"))
	var origin := (box.position/step).floor()*step-Vector2(step,step)
	var size := Vector2i(((box.end-origin)/step).ceil())+Vector2i(2,2)
	var heights := PackedInt32Array(); var records := PackedInt32Array(); var support := PackedByteArray()
	heights.resize(size.x*size.y*2); records.resize(size.x*size.y*2); support.resize(size.x*size.y*2)
	for open in 2:
		for model in models:model.science_open = open == 1
		for y in size.y:
			for x in size.x:
				var at := origin+Vector2(x,y)*step
				var i := open*size.x*size.y+y*size.x+x
				heights[i] = -9999
				for model in models:
					if model.nearby(at,model.floors,model.floor_bins).is_empty():continue
					var record: Dictionary = model.height_record(at)
					if not record.is_empty():
						heights[i] = maxi(heights[i],roundi(record.height))
						records[i] = hash([record.body_path,record.region,record.kind])
					if model.supported_box(model.SUPPORT.foot_rect(at)):support[i] |= 1
					if model.supported_box(model.SUPPORT.cargo_clearance_rect(at)):support[i] |= 2
					if model.standable(at,false,false):support[i] |= 4
	var scenery: Array = []
	for zone in scene.get_node("GroundSort").get_children():
		for district in zone.get_children():
			if not district.has_node("Scenery"):continue
			for node in district.get_node("Scenery").get_children():
				if not "elevation" in node:continue
				scenery.append([str(scene.get_path_to(node)),node.global_position,float(node.elevation),_ground(models,node.global_position)])
	var rooms: Array = []
	for node in scene.find_children("*","Node2D",true,false):
		if not node.has_meta("room"):continue
		var record: Dictionary = node.get_meta("room")
		var found: Array = []
		for u in range(0,int(record.size.x)*2+1):
			for v in range(0,int(record.size.y)*2+1):
				var at: Vector2 = node.global_position+Vector2((u-v)*10,(u+v)*5)
				var level := _ground(models,at)
				if not level in found:found.append(level)
		rooms.append([str(scene.get_path_to(node)),node.global_position,float(record.elevation),found])
	var file := FileAccess.open(argument("out","user://ground_dump.bin"),FileAccess.WRITE)
	file.store_var({"origin":origin,"size":size,"step":step,"heights":heights,"records":records,"support":support,"scenery":scenery,"rooms":rooms,
		"floors":models.map(func(m):return m.floors.map(func(f):return [f.region,f.kind,f.height,f.conditional,f.body_path,f.polygon]))})
	file.close()
	print("DUMP ",size," scenery ",scenery.size()," rooms ",rooms)
	quit()

func _ground(models: Array, at: Vector2) -> float:
	var best := -9999.0
	for model in models:
		model.science_open = false
		var record: Dictionary = model.height_record(at)
		if not record.is_empty():best = maxf(best,record.height)
	return best
