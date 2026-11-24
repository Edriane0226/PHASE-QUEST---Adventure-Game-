extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var world=current_scene;root.get_node("PlayerSave").set_completed_prefix(18);await physics_frame
	var box:=Rect2(Vector2(14594.07,4344.98)-Vector2(10,11),Vector2(20,22))
	check(world.access.box_allowed(box) and world.access.box_allowed(box),"repeated full-foot permission query")
	root.get_node("PlayerSave").set_completed_prefix(0)
	check(not world.access.box_allowed(box),"same cached full foot relocks immediately")
	root.get_node("PlayerSave").set_completed_prefix(18)
	check(world.access.box_allowed(box),"same cached full foot unlocks immediately")
	for layer in world.art_layers:
		var model=layer.geometry;var before: bool=model.science_open;var surface=layer.surface
		var floor_count: int=model.floors.size();var body_count: int=model.blockers.size()
		for state in [false,true]:
			model.science_open=state
			check(surface.restore_bake(),"generated geometry validates render cache "+layer.biome+":"+str(state))
			check(surface.meshes.size()==int(surface.stats.render_chunks) and surface.tiles.size()==int(surface.stats.cells),"complete cached terrain coverage "+layer.biome)
			check(model.floors.size()==floor_count and model.blockers.size()==body_count,"render cache grants no support/collision")
		model.science_open=before
		var routes: Array=surface.routes.duplicate(true);surface.set_routes([{"points":[[1,2],[3,4]]}])
		check(not surface.restore_bake(),"changed route rejects stale bake "+layer.biome)
		surface.set_routes(routes);check(surface.restore_bake(),"restored route validates original bake "+layer.biome)
		var biome: String=surface.biome;surface.biome="missing-fixture"
		check(not surface.restore_bake(),"missing bake safely declines "+biome);surface.biome=biome
	var ids: Array=[world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]
	var model=world.chunks["Z2L3.shell"].geometry
	var timings: Array=[];var memory: Array=[]
	for cycle in range(10):
		var start:=Time.get_ticks_usec();check(world.unmount_chunk("Z2L3.shell"),"inactive room chunk unload "+str(cycle))
		var unmount_ms: float=(Time.get_ticks_usec()-start)/1000.0
		await process_frame;await physics_frame
		start=Time.get_ticks_usec()
		var chunk=load("res://World/Zone2/Z2L3Shell.tscn").instantiate();chunk.configure_geometry(model)
		check(world.mount_chunk(chunk),"room chunk remount "+str(cycle))
		var mount_ms: float=(Time.get_ticks_usec()-start)/1000.0
		await process_frame;await physics_frame
		check(world.room_cutaway.rooms.size()==3 and world.geometry.room_solids.size()==85,"bounded room/art/body references "+str(cycle))
		check(world.chunks.size()==18,"eighteen identities restored "+str(cycle))
		timings.append({"cycle":cycle,"unmount_cpu_ms":unmount_ms,"mount_cpu_ms":mount_ms});memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	check([world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]==ids,"streaming retains actor/HUD/camera")
	check(memory[-1]-memory[0]<1024*1024,"ten warm cycles retain less than1MiB additional tracked memory")
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"warm_chunk_cycles":timings,"tracked_memory_bytes":memory,"scope":"Headless cache correctness and actual chunk lifecycle CPU timing; excludes GPU, OS working set, terrain cold startup and Android","streaming_model":"All18 geometry shells resident; renderer spatial culling plus explicit inactive chunk unload/remount. Automatic distance-based residency is not implemented."}
	FileAccess.open("res://../evidence/lifecycle-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("LIFECYCLE022 ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
