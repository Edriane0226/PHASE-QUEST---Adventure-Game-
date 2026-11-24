extends SceneTree
var world: Node
var captures: Array = []
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var filename:="terraces20-"+name
	var error:=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../evidence/"+filename+".png"))
	if error!=OK:failures.append("capture failed: "+filename);push_error(failures[-1])
	else:captures.append(filename)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	await capture("start-locked")
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(18)
	world._discovery_clock=-10000
	for y in range(world.discovery.SIZE.y):
		for x in range(world.discovery.SIZE.x):
			var key:=Vector2i(x,y)
			if world.access.point_allowed(world.discovery.center(key)):world.discovery.cells[key]=true
	world.discovery.revision+=1;world.map_provider.refresh_masks()
	var camera: Camera2D=world.player.get_node("Camera2D")
	world.player.set_physics_process(false);camera.top_level=true;camera.offset=Vector2.ZERO;world.hud.hide()
	for i in range(3):
		var field: RefCounted=world.models[i].relief
		var feature: Dictionary=field.features[0]
		camera.position=feature.center-Vector2(0,world.geometry.height_mainland(feature.center));camera.zoom=Vector2.ONE*.85
		await capture("zone%d-bowl"%(i+1))
		var best: Vector2i=field.columns.keys()[0]
		for cell: Vector2i in field.columns:
			if field.columns[cell].height>field.columns[best].height:best=cell
		var point: Vector2=field.center(best)
		camera.position=point-Vector2(0,world.geometry.height_mainland(point));camera.zoom=Vector2.ONE*.9
		await capture("zone%d-ridge"%(i+1))
		var faces: Array=world.art_layers[i].coast.faces
		assert(not faces.is_empty())
		var shore: Dictionary=faces[0]
		for face in faces:
			if face.inward.y<0 and face.a.y>shore.a.y:shore=face
		camera.position=(shore.a+shore.b)*.5;camera.zoom=Vector2.ONE*1.1
		await capture("zone%d-coast"%(i+1))
		var branch: Dictionary=world.models[i].data.local_branches[0]
		var road_point: Vector2=world.models[i].v(branch.points[branch.points.size()/2])
		camera.position=road_point-Vector2(0,world.geometry.height_mainland(road_point));camera.zoom=Vector2.ONE*1.2
		await capture("zone%d-road"%(i+1))
		for station in world.models[i].data.stations:
			if station.kind!="puzzle court":continue
			var at: Vector2=world.models[i].v(station.ground_xy)
			camera.position=at-Vector2(0,float(world.geometry.height_record(at).get("height",0)));camera.zoom=Vector2.ONE*.85
			await capture("zone%d-puzzle-terrace"%(i+1));break
	for source in world.models[0].data.sources:
		var at: Vector2=world.models[0].v(source.origin)
		camera.position=at-Vector2(0,80);camera.zoom=Vector2.ONE*.65
		await capture(source.subregion.to_lower()+"-raised-puzzles")
	camera.position=Vector2(10500,5000);camera.zoom=Vector2.ONE*.057
	await capture("world-stacked")
	# Load/exercise manual inspector as well; it changes camera only, never permissions.
	var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
	driver.inspect_landform();await process_frame
	assert(driver.overview and not world.player.is_physics_processing())
	driver.inspect_coast();await process_frame
	assert(driver.overview and not world.player.is_physics_processing())
	driver.toggle_overview();await process_frame
	assert(not driver.overview and world.player.is_physics_processing())
	camera.top_level=false;camera.position=Vector2.ZERO;world.hud.show()
	for index in range(5):
		if not driver.visit_puzzle_terrace():failures.append("puzzle visit refused "+str(index))
		await physics_frame;await physics_frame
		var support: Dictionary=world.geometry.height_record(world.player.position)
		if support.is_empty() or float(support.height)<40:failures.append("puzzle terrace has no real raised support "+str(index))
		elif not is_equal_approx(world.player._floor_height,float(support.height)):failures.append("actor not grounded on puzzle terrace "+str(index))
		await capture("actual-puzzle-support-%d"%index)
	# Retained geographic jump contracts still use the real actor on raised source floors.
	for source in world.models[0].data.sources:
		for jump in source.jumps:
			var origin: Vector2=world.models[0].v(source.origin)
			var from: Vector2=origin+world.models[0].v(jump.from)
			var toward: Vector2=origin+world.models[0].v(jump.toward)
			if not world.activate(source.subregion,from):failures.append("source jump departure "+jump.id);continue
			var falls: int=world.fall_count
			world.player.set_touch_movement((toward-from).normalized())
			if not world.player.request_jump():failures.append("source jump refused "+jump.id);continue
			for tick in range(90):
				await physics_frame
				if world.player.jump_elapsed<0:break
			world.input_adapter.stop_all("raised_source_jump_checked",true)
			if world.fall_count!=falls or not world.valid_landing(world.player.position):failures.append("source jump landing "+jump.id)
			await capture(jump.id+"-raised-landing")
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","captures":captures,"failures":failures,"scope":"uniform 20px cube unit, no terrain outlines, real retained/planned puzzle terraces and actor grounding, roads/coasts; no physical device acceptance"}
	FileAccess.open("res://../evidence/render-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STACKED GROUND RENDER ",captures.size()," captures; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
