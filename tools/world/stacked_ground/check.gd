extends SceneTree
var checks := 0
var failures: Array = []
var summary: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("FAIL ",message)
func run() -> void:
	var begun := Time.get_ticks_msec()
	var field_script = load("res://Scripts/World/terrain_relief.gd")
	for number in range(1,4):
		var model = load("res://Scripts/World/Zone%d/zone%d_geometry.gd" % [number,number]).new()
		check(model.load_data(),"zone loads %d" % number)
		var field: RefCounted = model.relief
		check(field.CUBE_UNIT_PX==20 and field.CUBE_STEP_PX==20 and field.TILE_SIZE==Vector2i(40,20),"one 20px cube unit throughout")
		for terrace in model.terraces.platforms:
			if terrace.kind!="station":continue
			var at: Vector2=field.center(field.cell_at(terrace.center))
			var actual: Dictionary=model.height_record(at)
			if actual.is_empty():continue
			check(float(actual.height)>=float(terrace.height),"puzzle uses real raised support "+terrace.station)
			check(is_zero_approx(fmod(float(actual.height),20)),"puzzle support aligned to cube layers")
		for source in model.data.get("sources",[]):
			for floor in model.floors:
				if floor.kind!="legacy" or floor.region!=source.subregion:continue
				var at: Vector2=floor.bounds.get_center()
				check(model.surface_height(floor,at)>=80,"retained puzzle floor raised into shared world")
		check(field.columns.size()>50,"zone has stacked landforms %d" % number)
		var copy = field_script.new(); copy.build(model)
		check(copy.columns==field.columns,"deterministic rebuild %d" % number)
		var heights: Dictionary = {}; var blocks := 0
		for cell: Vector2i in field.columns:
			var column: Dictionary = field.columns[cell]; var point: Vector2 = field.center(cell)
			heights[column.height] = true; blocks += roundi(column.base/field.CUBE_STEP_PX)+int(column.height)+1
			check(field.cell_at(point)==cell,"grid round trip")
			check(column.height>=0 and column.height<=field.MAX_HEIGHT,"bounded filled column")
			check(is_equal_approx(model.height_mainland(point),column.base+column.height*field.CUBE_STEP_PX),"support matches top")
			check(field.clearance(point)>=85,"reserved lane clearance")
		check(heights.size()>=4,"multiple height contours %d" % number)
		for s in model.data.stations:
			var point: Vector2 = model.v(s.ground_xy)
			check(not is_finite(field.height_at(point)),"station unaffected "+s.id)
		for path in ["res://World/Data/navigation-routes.json","res://World/Data/zone%d-routes.json" % number]:
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			for route in data.routes:
				for p in route.points:
					check(not is_finite(field.height_at(model.v(p))),"authored route height retained "+route.id)
		var art = load("res://Scripts/World/Zone%d/zone%d_ground_art.gd" % [number,number]).new()
		root.add_child(art); art.configure(model)
		var route_data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/zone%d-routes.json" % number))
		art.routes=route_data.routes;art.surface.build()
		check(art.surface.stats.cells>field.columns.size(),"cube surface covers broad flat ground")
		check(art.surface.stats.road_caps>0,"roads use supported cube caps")
		for station in model.data.stations:
			var at: Vector2=model.v(station.ground_xy)
			# Targets such as ChannelIce intentionally sit in a scientific water gap.
			if model.height_record(at).is_empty():continue
			var cell: Vector2i=field.cell_at(at)
			check(art.surface.tiles.has(cell) or field.columns.has(cell),"cube coverage at reserved station "+station.id)
		print("SURFACE ",number," ",art.surface.stats)
		for stack in art.get_children():
			if not stack.name.begins_with("Stacked_"):continue
			check(stack.layers.size()==stack.max_height+1,"one TileMapLayer per z")
			for z in range(stack.layers.size()):
				var layer: TileMapLayer = stack.layers[z]
				check(is_equal_approx(layer.position.y,-z*field.CUBE_STEP_PX),"exact layer elevation")
			for cell: Vector2i in field.regions[stack.region_id]:
				check((stack.position+stack.layers[0].map_to_local(cell)).is_equal_approx(field.center(cell)),"render/support grid alignment")
				for z in range(roundi(field.columns[cell].base/field.CUBE_STEP_PX)+int(field.columns[cell].height)+1):
					check(stack.layers[z].get_cell_source_id(cell)>=0,"no hollow/floating cube")
		summary.append({"zone":number,"columns":field.columns.size(),"blocks":blocks,"heights":heights.keys(),"bowls":field.features.size(),"surface":art.surface.stats})
		art.free()
		print("ZONE ",number," ",summary[-1])
	var result := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"zones":summary,"elapsed_ms":Time.get_ticks_msec()-begun}
	FileAccess.open("res://../evidence/check-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STACKED GROUND ",result.status," ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
