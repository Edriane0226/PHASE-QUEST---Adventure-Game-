extends SceneTree
## Focused visual QA after the metal-deck drawing correction; preserves full traversal results.
var world: Node
var checks:=0
var failures: Array=[]
var captures: Array=[]
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func capture(name: String) -> void:
	# Teleport fixtures need two frames for the existing Camera2D scroll to settle.
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Zone3/Zone3ShellWorld.tscn");await scene_changed;world=current_scene
	world.set_fixture_permissions(6,true);await physics_frame
	var before: Dictionary=root.get_node("PlayerSave").data.duplicate(true)
	for r in world.geometry.data.regions:
		check(world.activate(r.id,world.geometry.v(r.entry)),"exact supported arrival "+r.id)
		await capture(r.id.to_lower())
	for id in ["Z3L1.court1","Z3L3.court1","Z3L3.court3","Z3L4.court3","Z3L5.court2","Z3L6.court4","Z3L6.court5"]:
		for s in world.geometry.data.stations:
			if s.id!=id:continue
			check(world.activate(s.subregion,world.geometry.v(s.ground_xy)),"supported worksite "+id)
			await capture(id.to_lower().replace(".","-"))
	for platform in world.geometry.data.platforms:
		var at: Vector2=world.geometry.box_of(world.geometry.polygon(platform.polygon)).get_center()
		check(world.activate(platform.subregion,at),"actual metal deck supports actor")
		check(is_equal_approx(float(world.geometry.height_record(at).height)-world.geometry.height_mainland(at),8),"metal deck rises8wu above existing graded foundation")
		await capture("metal-platform")
	var camera: Camera2D=world.player.get_node("Camera2D");var camera_id:=camera.get_instance_id()
	for s in world.geometry.data.stations:
		if s.id!="Z3L1.court1":continue
		var wall: Node2D=world.equipment_art[s.id+":lab_wall"];world.player.set_physics_process(false)
		for offset in [-12,12]:
			world.player.position=wall.position+Vector2(0,offset);world.player._sync_ground_support();world.player._display_floor=world.player._floor_height
			world.player.animated_sprite.position=world.player._visual_home-Vector2(0,world.player._floor_height)
			await capture("sorting-back" if offset<0 else "sorting-front")
		world.player.set_physics_process(true)
	world.activate("Z3L1",world.geometry.v(world.geometry.data.regions[0].entry))
	for size in [Vector2i(1280,720),Vector2i(640,360)]:
		root.size=size;root.content_scale_size=size;await process_frame
		await capture("desktop" if size.x==1280 else "phone")
		var screen: Vector2=root.canvas_transform*(world.player.position-Vector2(0,world.player._display_floor))
		check(Rect2(Vector2(48,72),Vector2(size)-Vector2(96,120)).has_point(screen),"high deck fully visible at "+str(size))
		check(camera.get_instance_id()==camera_id and camera.zoom==Vector2.ONE*1.55,"original camera and zoom retained")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await process_frame
	world.player.set_physics_process(false);camera.top_level=true;camera.offset=Vector2.ZERO;camera.position=Vector2(16200,4600);camera.zoom=Vector2.ONE*.075;world.hud.hide()
	await capture("zone3-overview")
	check(root.get_node("PlayerSave").data==before,"render review never changes profile")
	var sources: Dictionary={}
	for name in ["zone3_geometry.gd","zone3_ground_art.gd","zone3_shell.gd","zone3_shell_world.gd"]:sources[name]=FileAccess.get_sha256("res://Scripts/World/Zone3/"+name)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"geometry_hash":FileAccess.get_sha256("res://World/Data/zone3-shells.json"),"sources":sources,"scope":"focused final deck rendering, actual player/prop front-back captures, original camera scale and high-floor desktop/compact framing; traversal evidence retained separately"}
	FileAccess.open(output.path_join("render-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 018 RENDER ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
