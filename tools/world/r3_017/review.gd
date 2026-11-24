extends SceneTree
const WORLD=preload("res://World/Zone2/Zone2ShellWorld.tscn")
const PLANNER=preload("res://path_planner.gd")
var world: Node
var planner: RefCounted
var checks:=0
var failures: Array=[]
var captures: Array=[]
var routes: Array=[]
var access: Array=[]
var route_reports: Array=[]
var walk_distance:=0.0
var jump_count:=0
var output: String
var manual:=false
var profile_before: Dictionary
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func screenshot(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence");manual="--manual" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	change_scene_to_packed(WORLD);await scene_changed;world=current_scene
	await physics_frame;await process_frame
	check(world.geometry!=null,"Zone2 shells require explicit isolated fixture permissions")
	if world.geometry==null:finish();return
	profile_before=root.get_node("PlayerSave").data.duplicate(true)
	world.set_fixture_permissions(6,true);await physics_frame
	planner=PLANNER.new();planner.build(world.geometry)
	await contract_checks()
	await route_checks()
	await activity_checks()
	await cargo_checks()
	await gate_checks()
	for r in world.geometry.data.regions:
		check(world.activate(r.id,world.geometry.v(r.entry)),"safe exact C0 arrival "+r.id)
		await physics_frame;await screenshot(r.id.to_lower())
	var camera: Camera2D=world.player.get_node("Camera2D");var before:=camera.position
	world.player.set_physics_process(false);camera.top_level=true;camera.position=Vector2(11600,4900);camera.zoom=Vector2.ONE*.072;world.hud.hide()
	await screenshot("zone2-overview")
	camera.top_level=false;camera.position=before;camera.zoom=Vector2.ONE*1.55;world.hud.show();world.player.set_physics_process(true)
	# Capture actual future worksites, rather than only empty entry clearings.
	for id in ["Z2L2.court1","Z2L3.court1","Z2L5.court3","Z2L6.court4","Z2L6.exit"]:
		for s in world.geometry.data.stations:
			if s.id!=id:continue
			world.activate(s.subregion,world.geometry.v(s.ground_xy));await physics_frame;await screenshot(id.to_lower().replace(".","-"))
	world.activate("Z2L1",world.geometry.v(world.geometry.data.regions[0].entry))
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360);await process_frame;world.input_adapter.refresh();await screenshot("phone")
	check(world.hud.supported and world.hud.visible_quest_count==2,"approved compact HUD remains usable")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	check(root.get_node("PlayerSave").data==profile_before,"geometry traversal never changes profile/science/completion/inventory")
	finish_data()
	if manual:
		var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
		print("MANUAL:1-6 area; N next measured connection; M overview; C carry; F1 desktop F2 phone; 7/8 fixture presets. No campaign progress.")
	else:finish()
func serialize_path(points: PackedVector2Array) -> Array:
	var result: Array=[]
	for p in points:result.append([snappedf(p.x,.01),snappedf(p.y,.01)])
	return result
func contract_checks() -> void:
	var g=world.geometry
	check(world.chunks.size()==6,"six translated sunny shells in one shared world")
	check(world.professor.name=="SharedProfessorZ2","one Marisol Reed actor moves between six Professor anchors")
	check(world.get_node("GroundSort").find_children("FinnCapstone","",true,false).size()==1,"Finn only at Engine capstone")
	for art in world.props:check(art.visuals.get_node("Artwork").texture!=null,"production texture "+str(art.get_meta("asset_id")))
	for r in g.data.regions:
		var chunk: Node=world.chunks[r.id+".shell"]
		check(chunk.frame_valid() and chunk.fixture_only and chunk.surface_name=="grass","translation-only grass chunk "+r.id)
		check(not preload("res://Scripts/Content/world_subregions.gd").definition(r.id).world_ready,"normal registration remains unavailable "+r.id)
		for id in r.checkpoint_ids:
			var station: Node2D=chunk.anchors[r.id+"."+id]
			check(world.valid_landing(station.global_position),"exact checkpoint has full support and clear collision "+r.id+"."+id)
	for s in g.data.stations:
		var marker: Node2D=world.chunks[s.subregion+".shell"].anchors[s.id]
		check(marker.global_position.distance_to(g.v(s.ground_xy))<.01,"retained accepted station anchor "+s.id)
		check(g.standable(g.v(s.ground_xy),true),"station working center supports cargo "+s.id)
		var at: Vector2=g.v(s.ground_xy)
		check(g.supported_box(Rect2(at-Vector2(48,48),Vector2(96,96))) and not g.blocked_box(Rect2(at-Vector2(48,48),Vector2(96,96))),"96wu touch/turning working clearing "+s.id)
	for e in g.data.equipment:
		check(g.region_at(g.v(e.at))==e.subregion,"equipment stays in owning area "+e.station+":"+e.group)
		if e.hot_guard:
			check(g.v(e.at).distance_to(g.v(e.safe_working_center))>=128,"hot machinery separated from safe interaction lane "+e.station+":"+e.group)
	for reserve in g.data.travel_reserves:
		check(g.standable(g.v(reserve.local_anchor),true),"geographic boat/lift anchor safely grounded "+reserve.id)
		check(not world.get_node("GroundSort").get_node(reserve.id.validate_node_name()).has_method("world_context"),"travel reservation grants no travel action "+reserve.id)
	for f in g.floors:check(not Geometry2D.triangulate_polygon(f.polygon).is_empty(),"valid support mesh")
func route_checks() -> void:
	var g=world.geometry
	var player_id: int=world.player.get_instance_id();var hud_id: int=world.hud.get_instance_id();var camera_id: int=world.player.get_node("Camera2D").get_instance_id()
	for i in range(5):
		world.set_fixture_permissions(i+2,true);planner.set_prefix(i+2);await physics_frame
		var from: Vector2=g.v(g.data.regions[i].exit);var to: Vector2=g.v(g.data.regions[i+1].entry)
		var path: PackedVector2Array=planner.walking(from,to)
		check(not path.is_empty(),"connected earned terrain "+str(i+1)+" to "+str(i+2))
		if path.is_empty():continue
		for p in path:check(g.standable(p),"supported permission-safe connection sample")
		routes.append({"id":"Z2L%d--Z2L%d"%[i+1,i+2],"points":serialize_path(path)})
		route_reports.append({"id":routes[-1].id,"samples":path.size()})
		check(world.activate(g.data.regions[i].id,path[0]),"connection departure "+str(i))
		await walk_steps([{"kind":"walk","points":path}],routes[-1].id)
		check(world.active_subregion_id==g.data.regions[i+1].id,"walking changes geographic owner "+str(i))
		check(world.player.get_instance_id()==player_id and world.hud.get_instance_id()==hud_id and world.player.get_node("Camera2D").get_instance_id()==camera_id,"actor/HUD/camera persist through connection")
	world.set_fixture_permissions(6,true);planner.set_prefix(6)
	world.ground_art.routes=routes;world.ground_art.queue_redraw()
func activity_checks() -> void:
	var g=world.geometry;var owner:=0
	var activities: Array=g.data.stations+g.data.exploration_stops
	activities.sort_custom(func(a,b):return a.subregion<b.subregion if a.subregion!=b.subregion else a.id<b.id)
	for s in activities:
		var level:=int(s.subregion.right(1))
		if owner!=level:planner.set_prefix(level);owner=level
		var at: Vector2=g.v(s.ground_xy);var safe: Vector2=planner.safe_in_region(at,s.subregion)
		check(safe.is_finite() and safe.distance_to(at)<=48,"touch approach within 48wu "+s.id)
		var path: PackedVector2Array=planner.walking(g.v(g.data.regions[level-1].entry),safe)
		check(not path.is_empty(),"activity reachable without later territory "+s.id)
		for p in path:check(g.permitted(p) and g.standable(p),"activity route stays supported/earned "+s.id)
		access.append({"id":s.id,"subregion":s.subregion,"anchor":s.ground_xy,"safe_ground":[safe.x,safe.y],"distance_from_anchor":snappedf(safe.distance_to(at),.01),"walking_samples":path.size()})
	# Each decorative device has real nearby standing room for its later touch provider.
	for e in g.data.equipment:
		planner.set_prefix(int(e.subregion.right(1)))
		var at: Vector2=g.v(e.at);var safe: Vector2=planner.safe_in_region(at,e.subregion)
		check(safe.is_finite() and safe.distance_to(at)<=128,"device approach within local camera/touch reserve "+e.station+":"+e.group)
		var entry: Vector2=g.v(g.data.regions[int(e.subregion.right(1))-1].entry)
		check(not planner.walking(entry,safe).is_empty(),"device reachable without later area "+e.station+":"+e.group)
	planner.set_prefix(6)
	print("ACTIVITY ACCESS ",access.size())
func cargo_checks() -> void:
	var g=world.geometry;var cargo=PLANNER.new();cargo.build(g,true);var count:=0
	for r in g.data.regions:
		for delivery in r.local_cargo_paths:
			var start: Vector2=g.v(delivery.points[0]);var end: Vector2=g.v(delivery.points[-1])
			check(g.standable(start,true) and g.standable(end,true),"authored cargo endpoints safe "+delivery.id)
			# Test exact authored 40wu return, including swept cargo clearance.
			for step in range(21):check(g.standable(start.lerp(end,step/20.0),true),"full 27x36 cargo support "+delivery.id)
			check(world.activate(r.id,start),"local cargo recovery "+delivery.id)
			world.player.carrying=true;check(not world.player.request_jump(),"Jump denied while carrying")
			await walk_steps([{"kind":"walk","points":PackedVector2Array([start,end])}],delivery.id)
			world.player.carrying=false;count+=1
	print("CARGO RETURNS ",count)
func gate_checks() -> void:
	world.set_fixture_permissions(1,false);await physics_frame
	for i in range(1,6):
		var p: PackedVector2Array=world.geometry.region_polygons[i]
		for j in range(p.size()):
			var at: Vector2=(p[j]+p[(j+1)%p.size()])/2;var normal: Vector2=(p[(j+1)%p.size()]-p[j]).normalized().orthogonal()*24
			var query:=PhysicsRayQueryParameters2D.create(at-normal,at+normal,8,[world.player.get_rid()]);query.hit_from_inside=true
			check(not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"alternate approach blocked by tall permission boundary")
		check(not world.geometry.permitted(world.geometry.v(world.geometry.data.regions[i].entry)),"locked entry denied")
	world.set_fixture_permissions(6,true);await physics_frame
func finish_data() -> void:
	var hash:=FileAccess.get_sha256("res://World/Data/zone2-shells.json")
	FileAccess.open(output.path_join("physical-routes.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":hash,"routes":routes},"\t"))
	FileAccess.open(output.path_join("station-access.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":hash,"access":access},"\t"))
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"geometry_hash":hash,"captures":captures,"route_reports":route_reports,"activity_count":access.size(),"walked_world_units":snappedf(walk_distance,.1),"actual_jumps":jump_count,"scope":"isolated Zone2 shell traversal; no normal campaign/puzzle/save grants"},"\t"))
func finish() -> void:
	finish_data();print("R3 017 REVIEW ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
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

