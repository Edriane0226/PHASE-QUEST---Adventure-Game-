extends SceneTree
var world: Node
var output: String
var captures: Array=[]
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func capture(name: String) -> void:
	await process_frame;await process_frame;world.input_adapter.refresh();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence");root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	var profile=root.get_node("PlayerSave");var before: Dictionary=profile.data.duplicate(true);var stored_cells: Dictionary=world.discovery.cells.duplicate()
	world._discovery_clock=-10000;world.discovery.cells.clear();world.discovery.revision+=1;world.discovery.observe(world.player.position,world.access);world.map_provider.refresh_masks()
	await capture("desktop-start")
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"));var route: Dictionary=routes.routes[0];var crossing:=-1
	for i in range(3,route.points.size()-3):
		var a:=Vector2(route.points[i-1][0],route.points[i-1][1]);var b:=Vector2(route.points[i][0],route.points[i][1])
		if world.access.region_at(a)=="Z1L1" and world.access.region_at(b)=="Z1L2":crossing=i;break
	check(crossing>=0,"actual measured first border located")
	if crossing>=0:
		var from:=Vector2(route.points[crossing-3][0],route.points[crossing-3][1]);var to:=Vector2(route.points[crossing+3][0],route.points[crossing+3][1])
		check(world.activate("Z1L1",from),"safe physical border approach")
		world.discovery.observe(from,world.access);world.map_provider.refresh_masks();await capture("locked-frontier")
		var known: Dictionary=world.discovery.document().duplicate(true);profile.set_completed_prefix(1);await physics_frame
		check(world.discovery.document()==known,"unlock leaves unexplored cells unchanged")
		world.map_provider.refresh_masks();await capture("unlocked-frontier")
		check(world.activate("Z1L2",to),"unlocked crossing uses same actor")
		world.discovery.observe(to,world.access);world.map_provider.refresh_masks();await capture("discovered-frontier")
		for g in world.gate_bodies:
			if g.region=="Z1L2" and not g.get("portal_entry",false):check(g.body.collision_layer==g.layer,"Mill task gates stay closed while fresh arrival opens")
		check(world.discovery.save_ledger(),"discovered frontier persists separately")
		var loaded=load("res://Scripts/World/Navigation/world_discovery.gd").new();loaded.path=world.discovery.path
		check(loaded.load_ledger() and loaded.document()==world.discovery.document(),"frontier fog/minimap survives reload")
		profile.set_completed_prefix(0);await physics_frame;world.map_provider.refresh_masks();world.input_adapter.refresh()
		check(world.discovery.known(to),"relock preserves discovered history")
		for marker in world.hud.minimap.record.markers:check(world.access.allowed(str(marker.id).get_slice(".",0)),"relocked markers hidden")
	var camera: Camera2D=world.player.get_node("Camera2D");var home:=camera.position
	world.player.set_physics_process(false);camera.top_level=true;camera.offset=Vector2.ZERO;camera.position=Vector2(10500,5000);camera.zoom=Vector2.ONE*.057;world.hud.hide();await capture("world-locked")
	profile.set_completed_prefix(18)
	for y in range(world.discovery.SIZE.y):
		for x in range(world.discovery.SIZE.x):
			var key:=Vector2i(x,y)
			if world.access.point_allowed(world.discovery.center(key)):world.discovery.cells[key]=true
	world.discovery.revision+=1;world.map_provider.refresh_masks();await capture("world-earned-inspection")
	camera.top_level=false;camera.position=home;camera.zoom=Vector2.ONE*1.55;world.hud.show();world.player.set_physics_process(true)
	for id in ["Z1L6--Z2L1","Z2L6--Z3L1"]:
		var c: Dictionary=world.connection(id);world.discovery.cells.clear();world.discovery.revision+=1
		check(world.activate(c.source,Vector2(c.source_anchor[0],c.source_anchor[1])),"final carrier source "+id)
		world.discovery.observe(world.player.position,world.access);world.map_provider.refresh_masks()
		check(world.start_transit(id),"final production carrier presentation "+id)
		for tick in range(16):await process_frame
		await capture("boat-transit" if c.source=="Z1L6" else "lift-transit")
		world._cancel_transit()
	var lab: Dictionary=world.REGISTRY.definition("Z3L1");check(world.activate("Z3L1",Vector2(lab.entry[0],lab.entry[1])),"shared camera reaches elevated lab")
	world.discovery.observe(world.player.position,world.access);world.map_provider.refresh_masks()
	root.size=Vector2i(640,360);root.content_scale_size=root.size;await capture("phone-lab")
	var screen: Vector2=root.canvas_transform*(world.player.position-Vector2(0,world.player._display_floor))
	check(Rect2(48,64,544,240).has_point(screen),"elevated lab fully visible on compact screen")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	world.discovery.cells=stored_cells;world.discovery.revision+=1;profile.set_completed_prefix(0)
	check(profile.data==before,"final visual fixtures leave profile byte-model unchanged")
	var sources: Dictionary={}
	for file in ["Scripts/World/Navigation/connected_world.gd","Scripts/World/Navigation/world_access.gd","Scripts/World/Navigation/world_geometry.gd","Scripts/World/Navigation/world_discovery.gd","Scripts/World/Navigation/world_map.gd","Scripts/World/Navigation/navigation_input.gd","Scripts/World/Navigation/travel_provider.gd","assets/shaders/world/navigation_fog.gdshader","World/Data/navigation-routes.json","World/Data/world-connections.json","Scripts/World/phase_device_emitter.gd","Scripts/World/phase_device_target_2d.gd"]:sources[file]=FileAccess.get_sha256("res://"+file)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"sources":sources,"scope":"final actual atmospheric locked/eligible/explored states, retained Mill gates, minimap reload/hidden markers,full-world overview and compact elevated camera; explicit isolated inspection only"}
	FileAccess.open(output.path_join("render-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 019 RENDER ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
