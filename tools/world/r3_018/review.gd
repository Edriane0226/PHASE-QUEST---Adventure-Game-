extends SceneTree
const WORLD=preload("res://World/Zone3/Zone3ShellWorld.tscn")
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
var chamber_attempts:=0
var equipment_access: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func screenshot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence");manual="--manual" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	change_scene_to_packed(WORLD);await scene_changed;world=current_scene
	await physics_frame;await process_frame
	check(world.geometry!=null,"Zone3 shells require explicit isolated fixture permissions")
	if world.geometry==null:finish();return
	profile_before=root.get_node("PlayerSave").data.duplicate(true)
	world.set_fixture_permissions(6,true);await physics_frame
	planner=PLANNER.new();planner.build(world.geometry)
	await contract_checks()
	await route_checks()
	await activity_checks()
	await chamber_checks()
	await sorting_checks()
	await cargo_checks()
	await gate_checks()
	await manual_checks()
	for r in world.geometry.data.regions:
		check(world.activate(r.id,world.geometry.v(r.entry)),"safe exact C0 arrival "+r.id)
		await physics_frame;await screenshot(r.id.to_lower())
	var camera: Camera2D=world.player.get_node("Camera2D");var before:=camera.position
	world.player.set_physics_process(false);camera.top_level=true;camera.offset=Vector2.ZERO;camera.position=Vector2(16200,4600);camera.zoom=Vector2.ONE*.075;world.hud.hide()
	await screenshot("zone3-overview")
	camera.top_level=false;camera.position=before;camera.zoom=Vector2.ONE*1.55;world.hud.show();world.player.set_physics_process(true)
	# Capture actual future worksites, rather than only empty entry clearings.
	for id in ["Z3L1.court1","Z3L3.court1","Z3L3.court3","Z3L4.court3","Z3L5.court2","Z3L6.court4","Z3L6.court5"]:
		for s in world.geometry.data.stations:
			if s.id!=id:continue
			world.activate(s.subregion,world.geometry.v(s.ground_xy));await physics_frame;await screenshot(id.to_lower().replace(".","-"))
	world.activate("Z3L1",world.geometry.v(world.geometry.data.regions[0].entry))
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360);await process_frame;world.input_adapter.refresh();await screenshot("phone")
	check(world.hud.supported and world.hud.visible_quest_count==2,"approved compact HUD remains usable")
	var screen: Vector2=root.canvas_transform*(world.player.position-Vector2(0,world.player._display_floor))
	check(Rect2(Vector2(48,72),Vector2(544,240)).has_point(screen),"high lab floor keeps player fully visible inside compact camera")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	check(root.get_node("PlayerSave").data==profile_before,"geometry traversal never changes profile/science/completion/inventory")
	finish_data()
	if manual:
		var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
		print("MANUAL:1-6 area; N next connection; O sealed observations; L scanner; P metal step; M overview; C carry; F1 desktop F2 phone; 7/8 fixture permissions. No science grants.")
	else:finish()
func serialize_path(points: PackedVector2Array) -> Array:
	var result: Array=[]
	for p in points:result.append([snappedf(p.x,.01),snappedf(p.y,.01)])
	return result
func contract_checks() -> void:
	var g=world.geometry
	check(world.chunks.size()==6,"six translated lab shells in one shared world")
	check(world.player.animated_sprite.scale.is_equal_approx(Vector2.ONE*.2923077) and world.player.get_node("Camera2D").zoom==Vector2.ONE*1.55,"original explorer scale and camera retained")
	check(world.professor.name=="SharedProfessorZ2","one Ivo Aster actor moves between six Professor anchors")
	check(world.get_node("GroundSort").find_children("FinnCapstone","",true,false).size()==1,"Finn only at Core capstone")
	for art in world.props:check(art.visuals.get_node("Artwork").texture!=null,"production texture "+str(art.get_meta("asset_id")))
	for r in g.data.regions:
		var chunk: Node=world.chunks[r.id+".shell"]
		check(chunk.frame_valid() and chunk.fixture_only and chunk.surface_name=="metal","translation-only metal chunk "+r.id)
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
		var art: Node2D=world.equipment_art[e.id]
		check(art.position==g.v(e.at) and is_equal_approx(art.elevation,float(g.height_record(art.position).get("height",0))) and art.get_parent().y_sort_enabled,"device uses logical ground sorting and separate visual elevation "+e.id)
	for floor in g.floors:check(floor.kind in ["mainland","bridge","platform"] and not floor.conditional,"only permanent physical floors provide support")
	for platform in g.data.platforms:
		check(platform.material=="permanent metal housing" and not platform.frost_support,"mechanical platform bears load; frost never floor")
		var at: Vector2=g.box_of(g.polygon(platform.polygon)).get_center()
		check(g.standable(at,true) and g.height_record(at).kind=="platform","metal step has full cargo support")
		check(world.activate(platform.subregion,at),"actor stands on actual metal step")
		world.player.carrying=true
		await walk_steps([{"kind":"walk","points":PackedVector2Array([at+Vector2(0,88),at])}],"permanent metal step cargo approach/return")
		world.player.carrying=false
		check(world.equipment_art[platform.id].z_index<world.player.z_index,"support art remains below standing player")
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
		routes.append({"id":"Z3L%d--Z3L%d"%[i+1,i+2],"points":serialize_path(path)})
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
		var at: Vector2=g.v(e.at);var safe: Vector2=g.v(e.observation)
		check(g.standable(safe) and safe.distance_to(at)<=48,"exact supported device touch point within 48wu "+e.id)
		var entry: Vector2=g.v(g.data.regions[int(e.subregion.right(1))-1].entry)
		check(not planner.walking(entry,safe).is_empty(),"device reachable without later area "+e.station+":"+e.group)
		equipment_access.append({"id":e.id,"subregion":e.subregion,"at":e.at,"safe_ground":e.observation,"reach":snappedf(safe.distance_to(at),.01)})
	planner.set_prefix(6)
	print("ACTIVITY ACCESS ",access.size())
func chamber_checks() -> void:
	var g=world.geometry
	world.set_fixture_permissions(6,true);planner.set_prefix(6);await physics_frame
	for chamber in g.data.chambers:
		var center: Vector2=g.v(chamber.at);var box: Rect2=g.box_of(g.polygon(chamber.barrier))
		check(world.sealed_bodies.has(chamber.id) and world.sealed_bodies[chamber.id].collision_layer==8,"sealed vessel/wall keeps tall collision "+chamber.id)
		check(not g.standable(center) and not world.valid_landing(center),"sealed interior rejected for standing/spawn/landing "+chamber.id)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var from: Vector2=center+direction*(maxf(box.size.x,box.size.y)+24)
			var query:=PhysicsRayQueryParameters2D.create(from,center,8,[world.player.get_rid()])
			check(not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"sealed barrier blocks every cardinal approach "+chamber.id)
		var loop: PackedVector2Array=g.polygon(chamber.service_loop)
		for i in range(1,loop.size()):
			var count:=ceili(loop[i-1].distance_to(loop[i])/6)
			for j in range(count+1):check(g.standable(loop[i-1].lerp(loop[i],float(j)/count),true),"full cargo envelope fits observation/service ring "+chamber.id)
		# Real actor walks, runs and jumps into every tall boundary. No fixture opens vessels.
		var start:=Vector2(box.position.x-26,center.y)
		check(world.activate(chamber.subregion,start),"safe chamber test approach "+chamber.id)
		var falls: int=world.fall_count;var scale_before:=Engine.time_scale;Engine.time_scale=4
		world.player.set_touch_movement(Vector2.RIGHT);world.player.set_touch_sprinting(true)
		for tick in range(18):await physics_frame
		check(world.player.position.x<box.position.x,"real run cannot enter sealed boundary "+chamber.id)
		world.player.set_touch_sprinting(false)
		check(world.player.request_jump(),"ordinary Jump attempt against sealed boundary "+chamber.id)
		chamber_attempts+=1
		for tick in range(25):
			await physics_frame
			check(not box.has_point(world.player.position),"jump never enters sealed chamber "+chamber.id)
			if world.player.jump_elapsed<0:break
		world.input_adapter.stop_all("chamber_checked",true);Engine.time_scale=scale_before
		check(world.player.position.x<box.position.x and world.fall_count==falls,"sealed jump safely blocked without recovery fall "+chamber.id)
	# Removing sample graphics cannot create, remove or alter structural support.
	var floor_count: int=g.floors.size()
	for art in world.equipment_art.values():art.hide()
	for s in g.data.stations:check(g.standable(g.v(s.ground_xy),true),"sample art visibility cannot affect supported station floor "+s.id)
	check(g.floors.size()==floor_count,"frost/sample artwork contributes zero support polygons")
	for art in world.equipment_art.values():art.show()
	print("SEALED BOUNDARIES ",g.data.chambers.size()," / real Jump attempts ",chamber_attempts)
func sorting_checks() -> void:
	var g=world.geometry;var placement: Dictionary={}
	for e in g.data.equipment:
		if e.group=="lab_wall" and e.station=="Z3L1.court1":placement=e;break
	check(not placement.is_empty(),"real production wall available for sorting review")
	if placement.is_empty():return
	var at: Vector2=g.v(placement.at)
	var old_position: Vector2=world.player.position;var old_region: String=world.active_subregion_id
	world.player.set_physics_process(false)
	# Inspect actual original player against actual lab wall in both ground-Y orders.
	for offset in [-12,12]:
		world.player.position=at+Vector2(0,offset);world.player._sync_ground_support();world.player._display_floor=world.player._floor_height
		world.player.animated_sprite.position=world.player._visual_home-Vector2(0,world.player._floor_height)
		check(world.player.get_parent()==world.equipment_art[placement.id].get_parent(),"actual player/prop share GroundSort")
		await physics_frame;await screenshot("sorting-back" if offset<0 else "sorting-front")
	world.player.set_physics_process(true);world.activate(old_region,old_position)
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
func manual_checks() -> void:
	var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
	for keycode in [KEY_O,KEY_L,KEY_P,KEY_7,KEY_8]:
		var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=keycode;driver._unhandled_key_input(event)
		await physics_frame
		check(world.valid_landing(world.player.position),"manual inspection key retains grounded safe actor "+str(keycode))
		if keycode==KEY_7:check(world.geometry.prefix==1 and world.active_subregion_id=="Z3L1","manual lock fixture returns to eligible C0")
	var camera_id: int=world.player.get_node("Camera2D").get_instance_id()
	driver.toggle_overview();check(not world.hud.visible and not world.player.is_physics_processing(),"overview suspends original actor")
	driver.toggle_overview();check(world.hud.visible and world.player.get_node("Camera2D").get_instance_id()==camera_id,"overview restores same camera and HUD")
	driver.queue_free()
func finish_data() -> void:
	var hash:=FileAccess.get_sha256("res://World/Data/zone3-shells.json")
	FileAccess.open(output.path_join("physical-routes.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":hash,"routes":routes},"\t"))
	FileAccess.open(output.path_join("station-access.json"),FileAccess.WRITE).store_string(JSON.stringify({"geometry_hash":hash,"access":access,"equipment_access":equipment_access},"\t"))
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"geometry_hash":hash,"captures":captures,"route_reports":route_reports,"activity_count":access.size(),"equipment_approaches":equipment_access.size(),"walked_world_units":snappedf(walk_distance,.1),"actual_jumps":jump_count,"sealed_jump_attempts":chamber_attempts,"falls":world.fall_count,"scope":"isolated Zone3 shell traversal; no normal campaign/puzzle/save grants; sample/frost supplies no floor"},"\t"))
func finish() -> void:
	finish_data();print("R3 018 REVIEW ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
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

