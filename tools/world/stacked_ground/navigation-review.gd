extends SceneTree
var world: Node
var checks:=0
var failures: Array=[]
var captures: Array=[]
var output: String
var distance:=0.0
var original_data: Dictionary={}
var measured_routes: Array=[]
class GeometryProbe extends "res://Scripts/World/phase_device_target_2d.gd":
	func definition() -> Dictionary:return {"max_range":160.0}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func screenshot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func run() -> void:
	output=ProjectSettings.globalize_path("res://../evidence");root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	check(world.geometry!=null,"all terrain composes under isolated019 profile")
	if world.geometry==null:finish();return
	original_data=root.get_node("PlayerSave").data.duplicate(true)
	check(world.chunks.size()==18,"all18 original subregion identities mounted")
	check(world.find_children("*","Camera2D",true,false).size()==1,"one original camera")
	check(world.find_children("*","CharacterBody2D",true,false).size()==1,"one original player")
	check(world.connections.size()==17,"17 original geographic connections")
	if "--manual" in OS.get_cmdline_user_args():
		var driver=load("res://manual_driver.gd").new();driver.review=self;root.add_child(driver)
		print("MANUAL: P visit real puzzle terraces; H landforms; J coast; M return/overview; +/- fixture completions; R reset;1/2/3 eligible zone;N next;F1/F2 resolutions;C carry;B boat;L lift;F8 all-earned inspection. No real progress.")
		return
	await screenshot("start-locked")
	await permission_checks()
	await discovery_checks()
	await connection_checks()
	await transit_checks()
	await fire_checks()
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(0);await physics_frame
	check(profile.data.active_run==original_data.active_run and profile.data.extras==original_data.extras,"geometry/fixtures grant zero attempts/science/rewards/inventory")
	check(not profile.finish_level("melting_and_freezing",1,[],world) and not profile.save_profile(),"isolated profile cannot commit completion or real saves")
	await screenshot("final-locked")
	root.size=Vector2i(640,360);root.content_scale_size=root.size;await screenshot("phone")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	finish()
func permission_checks() -> void:
	var profile=root.get_node("PlayerSave")
	for prefix in range(19):
		var before: Dictionary=world.discovery.document().duplicate(true)
		profile.set_completed_prefix(prefix);await physics_frame
		for i in range(18):
			var row: Dictionary=world.access.rows[i];var allowed: bool=profile.is_level_unlocked(row.zone_id,row.level)
			check(world.access.allowed(row.id)==allowed,"actual prerequisite prefix "+str(prefix)+":"+row.id)
			for body in world.permissions[row.id]:check(body.collision_layer==(0 if allowed else 8),"every relevant physical edge follows own permission")
		check(world.discovery.document()==before,"unlock/relock never edits discovery")
	profile.set_completed_prefix(0);await physics_frame
	for row in world.access.rows.slice(1):
		var p: PackedVector2Array=world.access.polygons[row.id]
		for i in range(p.size()):
			var a: Vector2=p[i];var b: Vector2=p[(i+1)%p.size()];var at: Vector2=(a+b)/2;var normal: Vector2=(b-a).normalized().orthogonal()*24
			var query:=PhysicsRayQueryParameters2D.create(at-normal,at+normal,8,[world.player.get_rid()]);query.hit_from_inside=true
			check(not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"alternate/elevated edge physically blocked "+row.id)
		check(not world.activate(row.id,Vector2(row.entry[0],row.entry[1])),"locked spawn/teleport rejected "+row.id)
	var safe: Vector2=world.player.position;world.player.position=Vector2(17000,4500);await physics_frame;await physics_frame
	check(world.access.point_allowed(world.player.position) and world.player.position.distance_to(safe)<100,"invalid loaded/forced locked position recovers before gameplay")
func discovery_checks() -> void:
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(0);await physics_frame
	world.discovery.cells.clear();world.discovery.revision+=1
	check(world.discovery.observe(world.player.position,world.access),"earned terrain discovery records locally")
	var known: Dictionary=world.discovery.document().duplicate(true);var count: int=world.discovery.cells.size()
	check(not world.discovery.observe(Vector2(17000,4500),world.access) and world.discovery.cells.size()==count,"proximity in locked territory cannot discover it")
	check(world.discovery.save_ledger(),"separate discovery ledger saves")
	var loaded=load("res://Scripts/World/Navigation/world_discovery.gd").new();loaded.path=world.discovery.path
	check(loaded.load_ledger() and loaded.document()==known,"discovery reload persists independently")
	profile.set_completed_prefix(18);await physics_frame
	check(world.discovery.document()==known,"all permissions unlocked without revealing unexplored cells")
	world.map_provider.refresh_masks();world.input_adapter.refresh();await screenshot("unlocked-unexplored")
	check(world.hud.minimap.record.texture is Texture2D and world.hud.minimap.record.fog is Texture2D,"approved circular minimap receives real geography/discovery")
	for marker in world.hud.minimap.record.markers:check(marker.discovered,"minimap exposes discovered markers only")
	profile.set_completed_prefix(0);await physics_frame
	check(world.discovery.document()==known,"relocking hides territory without deleting discovery")
	var bad=load("res://Scripts/World/Navigation/world_discovery.gd").new();bad.path="user://phasequest_profile.save"
	check(not bad.save_ledger() and not bad.load_ledger(),"discovery refuses profile-save namespace")
	bad.path="user://world-discovery/../phasequest_profile.save.json";check(not bad.save_ledger(),"discovery rejects namespace traversal")
	var future_path:="user://world-discovery/future-test.json"
	FileAccess.open(future_path,FileAccess.WRITE).store_string('{"version":99,"future":{"keep":true}}')
	var future_hash:=FileAccess.get_sha256(future_path);var future=load("res://Scripts/World/Navigation/world_discovery.gd").new();future.path=future_path
	check(not future.load_ledger() and future.read_only and not future.save_ledger() and FileAccess.get_sha256(future_path)==future_hash,"unknown future discovery retained byte-for-byte")
	var extra_path:="user://world-discovery/extras-test.json"
	FileAccess.open(extra_path,FileAccess.WRITE).store_string('{"version":1,"cell_size":96,"cells":[[1,1]],"future_extra":{"keep":42}}')
	var extra=load("res://Scripts/World/Navigation/world_discovery.gd").new();extra.path=extra_path
	check(extra.load_ledger(),"current discovery with unknown fields loads")
	extra.revision+=1;check(extra.save_ledger() and JSON.parse_string(FileAccess.get_file_as_string(extra_path)).future_extra.keep==42,"unknown discovery fields survive save")
	FileAccess.open(extra_path+".bak",FileAccess.WRITE).store_string(FileAccess.get_file_as_string(extra_path));FileAccess.open(extra_path,FileAccess.WRITE).store_string("[")
	var restored=load("res://Scripts/World/Navigation/world_discovery.gd").new();restored.path=extra_path
	check(restored.load_ledger() and restored.recovered_backup,"corrupt discovery recovers known-good backup")
	restored.revision+=1;check(restored.save_ledger() and FileAccess.file_exists(extra_path+".corrupt"),"repair preserves corrupt original and good backup")
func connection_checks() -> void:
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(18);await physics_frame
	var player_id: int=world.player.get_instance_id();var hud_id: int=world.hud.get_instance_id();var camera_id: int=world.player.get_node("Camera2D").get_instance_id()
	for zone in range(1,4):
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/zone%d-routes.json"%zone))
		for route in data.routes:
			var destination: String=route.id.get_slice("--",1)
			var index: int=(int(destination.substr(1,1))-1)*6+int(destination.right(1))-1
			profile.set_completed_prefix(index);await physics_frame
			var points:=PackedVector2Array()
			for p in route.points:points.append(Vector2(p[0],p[1]))
			if points.is_empty():continue
			var planner=load("res://path_planner.gd").new();points=planner.route(world.geometry,points)
			check(not points.is_empty(),"minimum-unlock connection has supported route "+route.id)
			if points.is_empty():continue
			var serialized: Array=[]
			for p in points:serialized.append([p.x,p.y])
			measured_routes.append({"id":route.id,"points":serialized,"minimum_completed_prefix":index})
			check(world.activate(world.access.region_at(points[0]),points[0]),"measured departure "+route.id)
			await walk(points,route.id)
			points.reverse();await walk(points,route.id+" return")
			check(world.player.get_instance_id()==player_id and world.hud.get_instance_id()==hud_id and world.player.get_node("Camera2D").get_instance_id()==camera_id,"one actor/HUD/camera across forward/return "+route.id)
		await screenshot("zone"+str(zone))
func walk(points: PackedVector2Array,label: String) -> void:
	var scale_before:=Engine.time_scale;Engine.time_scale=5;var falls: int=world.fall_count;var okay:=true
	for at in points:
		var start: Vector2=world.player.position;var previous:=start;var stalled:=0;var arrived:=false
		for tick in range(160):
			var delta: Vector2=at-world.player.position
			if delta.length()<5:arrived=true;break
			world.player.set_touch_movement(delta.normalized()*minf(1,delta.length()/10));await physics_frame
			if world.player.position.distance_to(previous)<.15:stalled+=1
			else:stalled=0;previous=world.player.position
			if stalled>20:break
		distance+=start.distance_to(world.player.position)
		if not arrived:okay=false;print("STUCK ",label," ",world.player.position," -> ",at);break
	world.input_adapter.stop_all("walk_checked");Engine.time_scale=scale_before
	check(okay and world.fall_count==falls,"real collision-aware walk "+label)
func transit_checks() -> void:
	var profile=root.get_node("PlayerSave")
	for id in ["Z1L6--Z2L1","Z2L6--Z3L1"]:
		var c: Dictionary=world.connection(id);profile.set_completed_prefix(6 if c.source=="Z1L6" else 12);await physics_frame
		check(world.activate(c.source,Vector2(c.source_anchor[0],c.source_anchor[1])),"geographic transit source "+id)
		world.player.carrying=true;check(not world.start_transit(id),"carried unique item cannot cross transport");world.player.carrying=false
		world.input_adapter.refresh();check(world.input_adapter.interact(),"actual contextual world action starts without selection menu "+id)
		for tick in range(12):await process_frame
		check(not world._transit.is_empty() and world._transit.carrier.visuals.get_child(0).texture!=null,"transport uses production boat/metal carrier")
		await screenshot("boat-transit" if c.source=="Z1L6" else "lift-transit")
		for tick in range(180):
			await process_frame
			if world._transit.is_empty():break
		check(world._transit.is_empty() and world.active_subregion_id==c.destination,"transport arrives at permitted geographic anchor "+id)
		check(world.start_transit(id,true),"earned reverse transport available "+id)
		for tick in range(180):
			await process_frame
			if world._transit.is_empty():break
		check(world._transit.is_empty() and world.active_subregion_id==c.source,"return transport retains source region "+id)
		check(world.start_transit(id),"transport interruption fixture starts")
		world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await physics_frame
		check(world._transit.is_empty() and world.active_subregion_id==c.source,"background cancels transit to safe earned source")
		check(world.start_transit(id),"transport pause fixture starts")
		world.input_adapter.action("pause");check(world._transit.is_empty() and paused,"Pause cancels transit safely before opening menu");world.input_adapter.close_panel()
		check(world.start_transit(id),"authoritative relock during transit starts")
		profile.set_completed_prefix(5 if c.source=="Z1L6" else 11);await physics_frame
		check(world._transit.is_empty() and world.active_subregion_id==c.source,"relock during transit prevents arrival beyond lock")
		world.activate(c.source,Vector2(c.source_anchor[0],c.source_anchor[1]));check(not world.start_transit(id),"locked destination transport rejected "+id)
func fire_checks() -> void:
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(0);await physics_frame
	check(not world.input_adapter.emitter.available(),"ordinary fixture cannot impersonate live campaign emitter")
	# Elevated projected rays are also clipped in logical ground space, independent of physics ray height.
	for row in world.access.rows.slice(1):
		var p: PackedVector2Array=world.access.polygons[row.id];var at: Vector2=world.player.position
		check(not world.world_contact_allowed(at,Vector2(row.entry[0],row.entry[1])),"locked target never authorizes exposure "+row.id)
	profile.set_completed_prefix(1);await physics_frame
	var from:=Vector2(3500,2100);var to:=Vector2(3700,2100)
	# Exact shared edge search avoids assumptions about axis-aligned routes.
	var a: PackedVector2Array=world.access.polygons.Z1L2
	profile.set_completed_prefix(0);await physics_frame
	var found:=false
	for i in range(a.size()):
		if found:break
		var n: Vector2=(a[(i+1)%a.size()]-a[i]).normalized().orthogonal()*35
		for j in range(1,20):
			var mid: Vector2=a[i].lerp(a[(i+1)%a.size()],j/20.0)
			for sign_value in [-1,1]:
				var candidate: Vector2=mid+n*sign_value;var target: Vector2=mid-n*sign_value
				if not world.valid_landing(candidate) or world.access.region_at(target)!="Z1L2":continue
				var query:=PhysicsRayQueryParameters2D.create(candidate,target,8,[world.player.get_rid()]);var hit: Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.collider in world.permissions.Z1L2:from=candidate;to=target;found=true;break
			if found:break
	check(found,"shared border supports elevated Fire probe")
	if found:
		# Explicit three-state visual fixtures: locked, eligible-unexplored, explored.
		var retained_cells: Dictionary=world.discovery.cells.duplicate();var old_clock: float=world._discovery_clock;world._discovery_clock=-1000
		for key in world.discovery.cells.keys():
			if world.access.region_at(world.discovery.center(key))=="Z1L2":world.discovery.cells.erase(key)
		world.discovery.revision+=1;world.activate("Z1L1",from);world.map_provider.refresh_masks();await screenshot("border-locked")
		var independent: Dictionary=world.discovery.document().duplicate(true);profile.set_completed_prefix(1);await physics_frame
		check(world.discovery.document()==independent,"unlock alone preserves unexplored minimap cells")
		world.map_provider.refresh_masks();world.input_adapter.refresh();await screenshot("border-unlocked-unexplored")
		world.discovery.observe(to,world.access);world.map_provider.refresh_masks();world.input_adapter.refresh();await screenshot("border-discovered")
		check(world.discovery.known(to),"eligible observation reveals separate map cells")
		profile.set_completed_prefix(0);await physics_frame;world.map_provider.refresh_masks();world.input_adapter.refresh()
		for marker in world.hud.minimap.record.markers:check(world.access.allowed(str(marker.id).get_slice(".",0)),"relock hides every unearned minimap marker")
		check(world.discovery.known(to),"relock retains independent discovery history")
		world.discovery.cells=retained_cells;world.discovery.revision+=1;world._discovery_clock=old_clock
		var direction: Vector2=(to-from).normalized();var scale_before:=Engine.time_scale;Engine.time_scale=4
		for action in ["walk","run","jump"]:
			check(world.activate("Z1L1",from),"real locked-border departure "+action)
			world.player.set_touch_movement(direction);world.player.set_touch_sprinting(action=="run")
			if action=="jump":check(world.player.request_jump(),"ordinary Jump toward locked border starts")
			for tick in range(24):await physics_frame;check(world.access.point_allowed(world.player.position),"real "+action+" never crosses locked permission")
			world.input_adapter.stop_all("border_checked",true)
		Engine.time_scale=scale_before;world.activate("Z1L1",from)
		profile.set_completed_prefix(1);await physics_frame;world.player.carrying=true;await physics_frame
		world.player.set_touch_movement(direction);var carry_scale:=Engine.time_scale;Engine.time_scale=4
		for tick in range(24):await physics_frame
		check(world.active_subregion_id=="Z1L1","cargo stays local even across earned border")
		check(not world.player.request_jump(),"cargo cannot jump a border")
		world.input_adapter.stop_all("cargo_checked",true);world.player.carrying=false;Engine.time_scale=carry_scale;profile.set_completed_prefix(0);await physics_frame;world.activate("Z1L1",from)
		for height in [0,40,160,240]:
			var origin: Vector2=from-Vector2(0,height);var end: Vector2=to-Vector2(0,height)
			var clipped: Vector2=world.world_emission_endpoint(from,origin,end)
			check(clipped.distance_to(origin)<origin.distance_to(end),"logical Fire clips locked border at elevation "+str(height))
		profile.fire_probe=true;profile.probe_mode="thermal";profile.changed.emit();await physics_frame
		# The production emitter consumes the geographic hook, including untargeted shots.
		for mode in ["thermal","cryo","vacuum","pressure"]:
			profile.probe_mode=mode;profile.changed.emit();await physics_frame
			var emitter=world.input_adapter.emitter;check(emitter.available(),"isolated noncommitting Fire probe "+mode)
			world.player.set_touch_movement(direction);await physics_frame;world.player.set_touch_movement(Vector2.ZERO)
			emitter.facing=direction;emitter.release();check(emitter.press(),"actual emitter Fire begins "+mode)
			for tick in range(10):await physics_frame
			var shot: Dictionary=emitter.snapshot()
			check(not shot.is_empty(),"actual Fire snapshot "+mode)
			if not shot.is_empty():check(world.access.ray_fraction(world.player.position,world.player.position+shot.point-shot.origin)>.99,"actual elevated beam terminates before locked territory "+mode)
			emitter.release()
		var probe:=GeometryProbe.new();probe.position=to;probe._source=world;world.add_child(probe)
		check(probe.geometry_reason(world.player.device_muzzle())=="locked_border","direct target exposure also rechecks logical territory")
		check(not profile.commit_device_outcome(probe,{},world),"geometry probe cannot grant science outcome")
		probe.queue_free()
		profile.fire_probe=false;profile.changed.emit()
func write_evidence() -> void:
	var hashes: Dictionary={}
	for n in range(1,4):hashes["zone%d-shells.json"%n]=FileAccess.get_sha256("res://World/Data/zone%d-shells.json"%n)
	if failures.is_empty():FileAccess.open(output.path_join("navigation-routes.json"),FileAccess.WRITE).store_string(JSON.stringify({"source_hashes":hashes,"routes":measured_routes,"scope":"minimum authoritative unlock; source puzzle gates remain intact"},"\t"))
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"walked_world_units":snappedf(distance,.1),"scope":"019 connected-world fixture; actual prerequisites, physical locks, independent discovery, walking/return/transit and fire guards; no real save/reward grants"}
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 019 REVIEW ",checks," checks / ",failures.size()," failures")
func finish() -> void:
	write_evidence();quit(0 if failures.is_empty() else 1)
