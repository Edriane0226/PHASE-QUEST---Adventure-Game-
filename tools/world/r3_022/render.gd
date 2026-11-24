extends SceneTree
const WS=preload("res://Scripts/Content/world_save.gd")
var world: Node
var captures: Array=[]
var failures: Array=[]
var checks:=0
var performance_samples: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/"+name+".png");captures.append(name+".png")
func sample(label: String) -> void:
	for tick in range(20):await process_frame
	var frame_times: Array=[];var process_times: Array=[];var previous:=Time.get_ticks_usec()
	for tick in range(120):
		await process_frame
		var now:=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	frame_times.sort();process_times.sort()
	performance_samples.append({"view":label,"resolution":[root.size.x,root.size.y],"wall_frame_ms_p50":frame_times[60],"wall_frame_ms_p95":frame_times[114],"wall_frame_ms_max":frame_times[-1],"cpu_process_ms_p95":process_times[114],"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"static_peak_bytes":Performance.get_monitor(Performance.MEMORY_STATIC_MAX),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"room_sprite_alpha_overlap":alpha_overlap()})
func alpha_overlap() -> Dictionary:
	# Sample actual Sprite2D alpha coverage every4 screen pixels. TileMaps/effects excluded.
	# This is a reproducible sprite-only fragment proxy, never hardware GPU overdraw.
	var counts: Dictionary={};var fragments:=0;var sprites:=0
	for room in world.room_cutaway.rooms:
		for piece in room.pieces:
			var sprite: Sprite2D=piece.visuals.get_node("Artwork")
			if not sprite.is_visible_in_tree() or sprite.texture==null:continue
			var image:=sprite.texture.get_image();var transform:=sprite.get_global_transform_with_canvas();var inverse:=transform.affine_inverse()
			var box:=transform*Rect2(Vector2.ZERO,Vector2(image.get_size()));box=box.intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
			if not box.has_area():continue
			sprites+=1
			for x in range(ceili(box.position.x/4),ceili(box.end.x/4)):
				for y in range(ceili(box.position.y/4),ceili(box.end.y/4)):
					var local: Vector2=inverse*Vector2(x*4+2,y*4+2)
					if local.x<0 or local.y<0 or local.x>=image.get_width() or local.y>=image.get_height():continue
					if image.get_pixel(int(local.x),int(local.y)).a<.01:continue
					var key:=Vector2i(x,y);counts[key]=counts.get(key,0)+1;fragments+=1
	var maximum:=0
	for value in counts.values():maximum=maxi(maximum,int(value))
	return {"scope":"room-module alpha samples only; excludes terrain, actors, effects, HUD; not hardware overdraw","sample_step_px":4,"visible_sprites":sprites,"sampled_fragment_hits":fragments,"covered_samples":counts.size(),"mean_layers_on_covered_samples":fragments/float(maxi(1,counts.size())),"max_layers":maximum}
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var start:=Time.get_ticks_usec()
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	var compose_ms: float=(Time.get_ticks_usec()-start)/1000.0
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(18);await physics_frame
	for layer in world.art_layers:check(layer.surface.bake_loaded,"source-validated terrain render bake "+layer.biome)
	for row in world.access.rows:world.discovery.observe(Vector2(row.entry[0],row.entry[1]),world.access)
	world.map_provider.refresh_masks()
	for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
		root.size=dimensions;root.content_scale_size=root.size;await process_frame
		for room in world.room_cutaway.rooms:
			for interior in [false,true]:
				var at: Vector2=room.point(Vector2(room.size_cubes.x-3,3.5) if interior else Vector2(room.size_cubes.x+2,3.5))
				check(world.activate(room.subregion_id,at),"rendered entry "+room.room_id)
				for tick in range(4):await process_frame
				world.room_cutaway.recompute()
				check(room.occupied==interior,"rendered cutaway "+room.room_id)
				var camera: Camera2D=world.player.get_node("Camera2D")
				check(camera.zoom.is_equal_approx(Vector2.ONE*1.55) and not camera.top_level,"shared camera scale/frame")
				check(world.hud.supported and world.hud.is_visible_in_tree(),"approved HUD supported "+str(dimensions))
				var label: String=room.room_id+("-inside" if interior else "-outside")+"-"+str(dimensions.x)
				await shot(label)
				if dimensions.x==640:await sample(label)
			# Actor behind retained rear wall and ahead of foreground wall: common ground sort.
			if dimensions.x==640:
				world.activate(room.subregion_id,room.point(Vector2(4,-2)));await shot(room.room_id+"-behind-640")
	var metrics:={"platform":"desktop rendered gl_compatibility; isolated fixture","os":OS.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"cold_world_compose_ms":compose_ms,"samples":performance_samples,"Android":"PENDING: physical device, GPU frame time, overdraw, background/resume, thermal soak","headless":"separate check-results.json; no GPU claim"}
	FileAccess.open("res://../evidence/desktop-performance.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	FileAccess.open("res://../evidence/render-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures},"\t"))
	print("RENDER022 ",checks," checks / ",failures.size()," failures / ",captures.size()," captures");quit(0 if failures.is_empty() else 1)
