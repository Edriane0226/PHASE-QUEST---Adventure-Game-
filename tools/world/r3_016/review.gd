extends SceneTree
const WORLD=preload("res://World/Zone1/Zone1ShellWorld.tscn")
const PLANNER=preload("res://path_planner.gd")
var world: Node
var checks:=0
var failures: Array=[]
var captures: Array=[]
var output: String
var planner: RefCounted
var manual:=false
var routes: Array=[]
var route_reports: Array=[]
var walk_distance:=0.0
var jump_count:=0
var profile_before: Dictionary={}
var access: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func screenshot(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence");manual="--manual" in OS.get_cmdline_user_args();root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	change_scene_to_packed(WORLD);await scene_changed;world=current_scene
	await physics_frame;await process_frame
	check(world.geometry!=null,"native shells load only with isolated explicit fixture profile")
	if world.geometry==null:finish();return
	check(world.chunks.size()==6,"six Zone1 chunks share one world host")
	profile_before=root.get_node("PlayerSave").data.duplicate(true)
	await screenshot("garden")
	world.set_fixture_permissions(6,true);await physics_frame
	planner=PLANNER.new();planner.build(world.geometry)
	await route_checks()
	await contract_checks()
	await access_checks()
	await gate_checks()
	await cargo_checks()
	for r in world.geometry.data.regions:
		var at: Vector2=world.geometry.v(r.entry);var nearest: Vector2i=planner.nearest(at)
		check(nearest.x>=0,"supported recovery near "+r.id)
		if nearest.x>=0:
			var safe: Vector2=Vector2(nearest)*planner.STEP
			check(world.activate(r.id,safe),"activate owned shell "+r.id)
			await physics_frame;await screenshot(r.id.to_lower())
	var camera: Camera2D=world.player.get_node("Camera2D");var before:=camera.position;var before_zoom:=camera.zoom
	world.player.set_physics_process(false);camera.top_level=true;camera.global_position=Vector2(5400,4300);camera.zoom=Vector2.ONE*.095;world.hud.hide()
	await screenshot("zone1-overview")
	camera.top_level=false;camera.position=before;camera.zoom=before_zoom;world.hud.show();world.player.set_physics_process(true)
	await manual_driver_checks()
	print("SHELL DIAGNOSTICS / ",checks," checks / ",failures.size()," failures")
	check(root.get_node("PlayerSave").data==profile_before,"all fixture traversal leaves profile/receipts/learning/inventory unchanged")
	if manual:
		world.set_fixture_permissions(6,true);planner.set_prefix(6);world.activate("Z1L1",planner.safe_at(world.geometry.v(world.geometry.data.regions[0].entry)))
		var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
		print("MANUAL:1-6 shell; F1desktop F2phone; Ccarry;7closed8open science fixture;Moverview;Nguided next connection. No campaign progress.")
	else:finish()
func finish() -> void:
	FileAccess.open(output.path_join("physical-routes.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":FileAccess.get_sha256("res://World/Data/zone1-shells.json"),"routes":routes,"scope":"actual supported route samples with source detours; accepted endpoint identities unchanged"},"\t"))
	FileAccess.open(output.path_join("station-access.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":FileAccess.get_sha256("res://World/Data/zone1-shells.json"),"access":access},"\t"))
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"geometry_hash":FileAccess.get_sha256("res://World/Data/zone1-shells.json"),"captures":captures,"route_reports":route_reports,"walked_world_units":snappedf(walk_distance,.1),"actual_jumps":jump_count,"zero_area_bank_fragments":world.zero_area_bank_fragments,"checkpoint_spurs":world.geometry.checkpoint_spurs,"scope":"R3 016 terrain-shell developer review; no normal profile or new puzzle readiness"},"\t"))
	print("R3 016 REVIEW ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func serialize_path(points: PackedVector2Array) -> Array:
	var result: Array=[]
	for point in points:result.append([snappedf(point.x,.01),snappedf(point.y,.01)])
	return result
func route_checks() -> void:
	var geometry=world.geometry
	for source in geometry.data.sources:
		for portal in source.portal_routes:
			var from: Vector2=geometry.v(portal.points[0]);var to: Vector2=geometry.v(portal.points[-1]);var p: PackedVector2Array=planner.walking(from,to)
			print("PORTAL ",source.subregion," ",from," -> ",to," path=",p.size()," endpoint=",geometry.standable(to))
	var outer_a: Vector2=geometry.v(geometry.data.sources[0].portal_routes[0].points[-1]);var outer_b: Vector2=geometry.v(geometry.data.sources[1].portal_routes[0].points[-1])
	print("OUTER PATH ",planner.walking(outer_a,outer_b).size())
	var mask:=Image.create(440,355,false,Image.FORMAT_RGB8);mask.fill(Color("1e2c38"))
	for y in range(355):
		for x in range(440):
			if not planner.grid.is_point_solid(Vector2i(x,y)):mask.set_pixel(x,y,Color("dce9e4"))
	var seed: Vector2i=planner.nearest(outer_a);var target: Vector2i=planner.nearest(outer_b)
	print("OUTER CELLS ",seed," / ",target)
	mask.set_pixelv(seed,Color.RED);mask.set_pixelv(target,Color.BLUE);mask.resize(880,710,Image.INTERPOLATE_NEAREST);mask.save_png(output.path_join("navigation-mask.png"))
	for i in range(5):
		var from: Vector2=geometry.v(geometry.data.regions[i].exit);var to: Vector2=geometry.v(geometry.data.regions[i+1].entry)
		var steps: Array=planner.plan(from,to)
		check(not steps.is_empty(),"continuous supported route "+str(i+1)+" to "+str(i+2))
		var count:=0
		for step in steps:
			if step.kind=="walk":
				routes.append({"id":"Z1L%d--Z1L%d"%[i+1,i+2],"points":serialize_path(step.points)})
				count+=step.points.size()
		route_reports.append({"route":"Z1L%d--Z1L%d"%[i+1,i+2],"parts":steps.size(),"walking_samples":count})
	world.ground_art.routes=routes;world.ground_art.queue_redraw()
	for source in geometry.data.sources:
		var region: Dictionary=geometry.data.regions[int(source.subregion.right(1))-1]
		var steps: Array=planner.plan(geometry.v(region.entry),geometry.v(region.exit))
		check(not steps.is_empty(),"retained source route traversable with explicit fixture support "+source.subregion)
		print("SOURCE ROUTE ",source.subregion," / ",steps.size()," parts")
		if not steps.is_empty():
			world.activate(source.subregion,planner.safe_at(geometry.v(region.entry)))
			await walk_steps(steps,"source "+source.subregion)
	# Cross all intended shells using the actual player, not per-shell scene replacement.
	var player_id: int=world.player.get_instance_id();var hud_id: int=world.hud.get_instance_id();var camera_id: int=world.player.get_node("Camera2D").get_instance_id()
	for i in range(5):
		var from: Vector2=planner.safe_at(geometry.v(geometry.data.regions[i].exit));var to: Vector2=geometry.v(geometry.data.regions[i+1].entry)
		if not world.activate(geometry.data.regions[i].id,from):check(false,"route departure "+str(i));continue
		var steps: Array=planner.plan(from,to)
		if steps.is_empty():continue
		await walk_steps(steps,"shell "+str(i+1)+" to "+str(i+2))
		check(world.player.get_instance_id()==player_id and world.hud.get_instance_id()==hud_id and world.player.get_node("Camera2D").get_instance_id()==camera_id,"one actor/HUD/camera across shell route "+str(i))
	FileAccess.open(output.path_join("physical-routes.json"),FileAccess.WRITE).store_string(JSON.stringify({"routes":routes,"scope":"actual supported route samples with source detours; accepted endpoint identities unchanged"},"\t"))
func walk_steps(steps: Array,label: String) -> void:
	var old_scale:=Engine.time_scale;Engine.time_scale=5
	var before_falls: int=world.fall_count;var okay:=true
	for step in steps:
		if step.kind=="walk":
			for target in step.points:
				if not await walk_to(target):okay=false;print("STUCK ",label," at ",world.player.position," target ",target);break
		elif step.kind=="jump":
			if not await walk_to(step.from):okay=false;break
			var direction: Vector2=(step.to-step.from).normalized();world.player.set_touch_movement(direction)
			if not world.player.request_jump():okay=false;break
			jump_count+=1
			for tick in range(90):
				await physics_frame
				if world.player.jump_elapsed<0:break
			world.player.set_touch_movement(Vector2.ZERO)
		if not okay:break
	world.input_adapter.stop_all("route_complete");Engine.time_scale=old_scale
	check(okay and world.fall_count==before_falls,"actual collision-aware developer traversal "+label)
func walk_to(target: Vector2) -> bool:
	var before: Vector2=world.player.position;var progress:=0;var last:=before
	for tick in range(150):
		var gap: Vector2=target-world.player.position
		if gap.length()<5:world.player.set_touch_movement(Vector2.ZERO);walk_distance+=before.distance_to(world.player.position);return true
		world.player.set_touch_movement(gap.normalized()*minf(1,gap.length()/10))
		await physics_frame
		if world.player.position.distance_to(last)<.15:progress+=1
		else:progress=0;last=world.player.position
		if progress>20:return false
	return false
func contract_checks() -> void:
	var g=world.geometry
	check(world.professor!=null and world.professor.name=="SharedProfessorZ1","one shared Professor identity for all six placement anchors")
	check(world.get_node("GroundSort").find_children("FinnCapstone","",true,false).size()==1,"Finn appears once at Zone1 capstone")
	for art in world.props:
		var asset_id: String=art.get_meta("asset_id","")
		check(art.visuals.get_node("Artwork").texture!=null,"placed production asset texture "+asset_id)
	for station in g.data.stations:
		var chunk: Node=world.chunks[station.subregion+".shell"]
		check(chunk.anchors.has(station.id),"station anchor "+station.id)
		if chunk.anchors.has(station.id):check(chunk.anchors[station.id].global_position.distance_to(g.v(station.ground_xy))<.01,"accepted station coordinate "+station.id)
	var crystals: Array=g.data.stations.filter(func(s):return s.subregion=="Z1L1" and s.kind=="crystal")
	check(crystals.size()==6,"exact six Garden crystal footprints retained")
	for crystal in crystals:check(world.chunks["Z1L1.shell"].anchors[crystal.id].get_meta("kind")=="crystal","retained stable crystal identity "+crystal.id)
	for source in g.data.sources:
		var chunk: Node=world.chunks[source.subregion+".shell"]
		for anchor in source.source_anchors:
			check(g.v(anchor.world_xy).is_equal_approx(g.v(anchor.local_xy)+chunk.ground_origin),"source translation only "+anchor.path)
	for r in g.data.regions:
		var chunk: Node=world.chunks[r.id+".shell"]
		check(chunk.frame_valid() and chunk.fixture_only and chunk.y_sort_enabled,"valid unready chunk frame "+r.id)
		for id in r.checkpoint_ids:
			var anchor: Node2D=chunk.anchors[r.id+"."+id];var safe: Vector2=planner.safe_at(anchor.global_position)
			check(safe.is_finite() and safe.distance_to(anchor.global_position)<=96,"safe local recovery reserve "+r.id+"."+id)
			check(world.valid_landing(anchor.global_position),"authored checkpoint itself has full safe standing support "+r.id+"."+id)
		check(not preload("res://Scripts/Content/world_subregions.gd").definition(r.id).world_ready,"normal readiness remains closed "+r.id)
	for floor in g.floors:
		check(not Geometry2D.triangulate_polygon(floor.polygon).is_empty(),"valid support mesh polygon")
		if floor.kind in ["mainland","bridge"]:
			for source in g.data.sources:
				var points: PackedVector2Array=g.polygon(source.protected_envelope)
				check(Geometry2D.intersect_polygons(floor.polygon,points).is_empty(),"new terrain does not fill protected source route/gaps")
	for body in world.get_node("GroundSort").find_children("*","StaticBody2D",true,false):check(body.get_child_count()>0,"physical solid has valid collision shape "+body.name)
func gate_checks() -> void:
	var g=world.geometry
	world.set_fixture_permissions(1,false);planner.refresh_gate_cells();await physics_frame
	var source: Dictionary=g.data.regions[0]
	check(planner.plan(g.v(source.entry),g.v(source.exit)).is_empty(),"closed Garden science seals cannot be bypassed through new surrounding ground")
	for i in range(1,6):
		for body in world.permission_bodies[i]:check(body.collision_layer==8,"unearned organic boundary blocks walking and jumping")
	var rays:=0
	for i in range(1,6):
		var p: PackedVector2Array=g.region_polygons[i]
		for j in range(p.size()):
			var at: Vector2=(p[j]+p[(j+1)%p.size()])/2;var normal: Vector2=(p[(j+1)%p.size()]-p[j]).normalized().orthogonal()*24
			var query:=PhysicsRayQueryParameters2D.create(at-normal,at+normal,8,[world.player.get_rid()]);query.hit_from_inside=true
			check(not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"physical barrier covers alternate border approach "+str(i)+":"+str(j));rays+=1
	for body in world.portal_bodies:check(body.collision_layer==8,"closed supported source portal retains tall seal")
	for record in world.source_gate_bodies:check(record.body.collision_layer==record.layer,"original science/traversal gate retained closed")
	check(not g.permitted(g.v(g.data.regions[5].center)),"off-road point in unearned Dock denied")
	world.set_fixture_permissions(6,true);planner.refresh_gate_cells();await physics_frame
	print("GATE CHECKS / ",rays," alternate boundary rays / closed-source detour rejected")
func cargo_checks() -> void:
	var g=world.geometry
	var cargo=PLANNER.new();cargo.build(g,true)
	var deliveries: Array=[{"id":"Garden wood to fueled heater","region":"Z1L1","from":Vector2(2820,1570),"to":Vector2(2900,2190)},{"id":"Garden blades to fan","region":"Z1L1","from":Vector2(2910,1840),"to":Vector2(2970,2085)}]
	for i in range(3):deliveries.append({"id":"Mill intact part "+str(i),"region":"Z1L2","from":[Vector2(4920,1920),Vector2(5090,1955),Vector2(5280,2185)][i],"to":[Vector2(5035,2080),Vector2(5120,2130),Vector2(5200,2100)][i]})
	for r in g.data.regions.slice(2):
		for route in r.local_cargo_paths:deliveries.append({"id":route.id,"region":r.id,"from":g.v(route.points[0]),"to":g.v(route.points[-1])})
	for delivery in deliveries:
		var start: Vector2=cargo.safe_at(delivery.from);var end: Vector2=cargo.safe_at(delivery.to)
		var route: PackedVector2Array=cargo.walking(start,end)
		check(not route.is_empty(),"walking cargo return "+delivery.id)
		for p in route:check(g.standable(p,true),"full 27x36 cargo envelope supported/clear "+delivery.id)
		if route.is_empty():continue
		check(world.activate(delivery.region,start),"cargo recovery in owning shell "+delivery.id)
		world.player.carrying=true
		check(not world.player.request_jump(),"carry cannot invoke Jump "+delivery.id)
		await walk_steps([{"kind":"walk","points":route}],"cargo "+delivery.id)
		world.player.carrying=false
	print("CARGO CHECKS / ",deliveries.size()," walking returns / no carry jumps")
func access_checks() -> void:
	var g=world.geometry
	var prefix:=0
	var activities: Array=g.data.stations+g.data.exploration_stops
	activities.sort_custom(func(a,b):return a.subregion<b.subregion if a.subregion!=b.subregion else a.id<b.id)
	for station in activities:
		if station.kind=="catalog reservation":continue
		var owner: int=int(station.subregion.right(1))
		if prefix!=owner:planner.set_prefix(owner);prefix=owner
		var requested: Vector2=g.v(station.ground_xy);var safe: Vector2=planner.safe_in_region(requested,station.subregion)
		var r: Dictionary=g.data.regions[int(station.subregion.right(1))-1]
		check(safe.is_finite() and safe.distance_to(requested)<=180,"safe approach to activity "+station.id)
		check(g.region_at(safe)==station.subregion,"activity approach remains inside its owning area "+station.id)
		var steps: Array=planner.plan(g.v(r.entry),safe)
		check(not steps.is_empty(),"activity connected to own shell arrival "+station.id)
		var jumps:=0
		for step in steps:
			if step.kind=="jump":jumps+=1
			elif step.kind=="walk":
				for p in step.points:check(g.permitted(p),"activity route needs no later area "+station.id)
		access.append({"id":station.id,"subregion":station.subregion,"anchor":station.ground_xy,"safe_ground":[safe.x,safe.y],"distance_from_anchor":snappedf(safe.distance_to(requested),.01),"route_parts":steps.size(),"authored_jumps":jumps})
	print("ACTIVITY ACCESS / ",access.size()," owned station/exploration approaches")
	planner.set_prefix(6)
func manual_driver_checks() -> void:
	var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
	var camera: Camera2D=world.player.get_node("Camera2D");var camera_id:=camera.get_instance_id()
	driver.toggle_overview()
	check(not world.hud.visible and camera.top_level and not world.player.is_physics_processing(),"review overview uses existing camera and suspends movement")
	driver.toggle_overview()
	check(world.hud.visible and not camera.top_level and camera.zoom==Vector2.ONE*1.55 and camera.get_instance_id()==camera_id,"review overview restores same gameplay camera/scale")
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_1;driver._unhandled_key_input(key)
	check(world.active_subregion_id=="Z1L1","manual shell selection works without progress writes")
	key.physical_keycode=KEY_7;driver._unhandled_key_input(key)
	check(not world.geometry.science_open,"manual closed science-seal preset")
	key.physical_keycode=KEY_8;driver._unhandled_key_input(key)
	check(world.geometry.science_open,"manual open science-seal preset is explicit")
	driver.extent(Vector2i(640,360));await process_frame;world.input_adapter.refresh();await screenshot("phone")
	check(world.hud.supported and world.hud.visible_quest_count==2,"actual shell retains compact approved HUD")
	driver.extent(Vector2i(1280,720));await process_frame;world.input_adapter.refresh();driver.queue_free()
