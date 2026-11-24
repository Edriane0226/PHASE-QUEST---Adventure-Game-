extends SceneTree
const PROVIDER=preload("res://Scripts/World/Zone1/stillwater_world.gd")
const PLANNER=preload("res://path_planner.gd")
var world
var provider
var store
var checks:=0
var failures: Array=[]
var captures: Array=[]
var observations: Array=[]
var rendering:=false
var walking:=false
var distance_walked:=0.0
class WalkPhysics extends RefCounted:
	var world
	func standable(at: Vector2) -> bool:return world.valid_landing(at) and world.geometry.supported_box(Rect2(at-Vector2(22,23),Vector2(44,46)))
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func ticks(n:=3) -> void:
	for i in n:await physics_frame;await process_frame
func close_feedback() -> void:
	if world.input_adapter.modal=="explanation":world.input_adapter._panel_intent("guides.library","explanation_ack",{"view_revision":world.panels.revision})
	elif not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
func shot(label: String) -> void:
	if not rendering:return
	await ticks(6);await RenderingServer.frame_post_draw
	if world.panels.visible:
		for button in world.panels.action_buttons.values():check(button.is_visible_in_tree() and button.size.y>=48 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"touch-sized visible panel action "+label)
	var file: String=label+"-"+str(root.size.x)+".png"
	check(root.get_texture().get_image().save_png("res://../evidence/"+file)==OK,"capture "+file);captures.append(file)
func move_to(point: Vector2) -> bool:
	close_feedback()
	if not walking:return world.activate("Z1L3",point)
	var collision:=WalkPhysics.new();collision.world=world
	var path: PackedVector2Array=PLANNER.new().route(collision,PackedVector2Array([world.player.position,point]))
	if path.is_empty():return false
	path.append(point)
	for target in path:
		var limit:=maxi(180,ceili(world.player.position.distance_to(target)/maxf(30,world.player.movement_speed())*Engine.physics_ticks_per_second*1.6)+60)
		var blocked:=0;var falls: int=world.fall_count
		for tick in range(limit):
			var delta: Vector2=target-world.player.position
			if delta.length()<4:break
			var before: Vector2=world.player.position
			world.input_adapter._move(delta.normalized()*minf(1,delta.length()/24));await physics_frame
			if world.fall_count!=falls:print("ROUTE026 FALL ",before," -> ",target);world.input_adapter._move(Vector2.ZERO);return false
			distance_walked+=before.distance_to(world.player.position);blocked=blocked+1 if before.distance_to(world.player.position)<.05 else 0
			if blocked>90:break
		world.input_adapter._move(Vector2.ZERO)
		if world.player.position.distance_to(target)>6:print("STUCK026 ",world.player.position," -> ",target);return false
	await ticks();return true
func approach(id: String) -> bool:
	close_feedback()
	for radius in [28,34,39]:
		for step in range(24):
			var at: Vector2=provider.points[id]+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(at) or not await move_to(at):continue
			if provider.action_allowed(id):return true
	return false
func tap(id: String) -> bool:
	if not await approach(id):print("NO_APPROACH026 ",id);return false
	await ticks();world.input_adapter.refresh()
	if world.active_chunk().context_record().get("key")!="Z1L3:"+id:return false
	var at: Vector2=world.hud.controls.context.get_global_rect().get_center()
	world.hud.route_touch(201,at,true);world.hud.route_touch(201,at,false);await create_timer(.7).timeout;await ticks();return true
func aim(id: String) -> bool:
	close_feedback();var target=provider.targets[id];var emitter=world.input_adapter.emitter
	var ground: Vector2=target.get_meta("ground_xy")
	for radius in [60,75,85,95]:
		for step in range(24):
			var at: Vector2=ground+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(at) or not await move_to(at):continue
			target=provider.targets.get(id)
			if not is_instance_valid(target):return false
			emitter.facing=(target.global_position-world.player.device_muzzle().global_position).normalized();emitter.release();emitter._aim();await ticks()
			if emitter.selected==target:return true
	return false
func mode(id: String) -> void:
	close_feedback();world.input_adapter.refresh();var at: Vector2=world.hud.rects[id].get_center();world.hud.route_touch(302,at,true);world.hud.route_touch(302,at,false);await ticks()
	check(store.selected_device_mode()==id,"actual mode touch "+id)
func fire(down: bool) -> void:
	world.input_adapter.refresh();world.hud.route_touch(301,world.hud.rects.fire.get_center(),down)
func expose(id: String) -> void:
	check(await aim(id),"supported native aim "+id)
	fire(true)
	for i in range(260):
		await physics_frame
		if provider.targets[id].is_committed():break
	fire(false);await ticks();check(provider.targets[id].is_committed(),"native held Fire verified and saved "+id)
func reload_world() -> void:
	close_feedback();check(store.save_world_location(world),"save actual world location/attempt")
	store.load_profile();check(world.restore_saved_world(world.access),"Continue restores same attempt and location");await ticks()
func stage_checks() -> void:
	check(provider.active() and provider.targets.size()==4,"four authored native targets in owning attempt")
	check(provider._reservation_art.size()==4 and provider._reservation_art.all(func(art):return not art.visible),"four reservation sprites yield to independent live modules")
	var kernel=preload("res://Scripts/Content/phase_transition_rules.gd")
	var cryo: Dictionary={"version":1,"unlocked_modes":{"cryo":true,"thermal":true,"pressure":true,"vacuum":true},"learned_capabilities":{"freezing":true,"melting":true},"selected_mode":"cryo"}
	var spec: Dictionary=provider.targets.first_ice.definition();var liquid: Dictionary={"material":"water","state":"liquid","amount":1.0,"phase_region":"freezing","heat_flow":"out"}
	for wrong in ["thermal","vacuum","pressure"]:check(kernel.eligibility(spec,wrong,cryo,liquid,{})=="unsupported_mode","wrong mode cannot freeze water: "+wrong)
	for amount in [0,-1]:
		var empty:=liquid.duplicate(true);empty.amount=amount;check(kernel.eligibility(spec,"cryo",cryo,empty,{})=="empty_sample","Cryo never creates water from absent supply "+str(amount))
	check(store.has_device_capability("melting") and not store.is_device_mode_unlocked("cryo") and not store.has_device_capability("freezing"),"prior melting retained; new Cryo and freezing locked")
	check(not provider.finish() and not provider.commit_action("latch"),"proximity/API cannot bypass unfinished science")
	check(not world.valid_landing(provider.points.court1) and not world.valid_landing(provider.points.court3+Vector2(-56,0)),"filled liquid and empty trays have no landing support")
	var before: Dictionary=store.data.duplicate(true)
	world.input_adapter.select_mode("cryo");check(store.data==before,"locked mode selection leaves exact profile")
	check(provider.discover("freezing","cooling_tool"),"free cooling-tool reference discoverable without granting skill")
	check(not store.is_device_mode_unlocked("cryo"),"Guide discovery cannot unlock Cryo")
	var guide: String=store.instance_id("melting_and_freezing",3,"cooling_tool")+":freezing"
	before=store.data.duplicate(true);world.input_adapter.open_panel("guides");world.input_adapter._open_guide(guide);await ticks(10)
	check(is_instance_valid(world.input_adapter.guide_preview) and world.input_adapter.guide_preview.get_script().resource_path.ends_with("stillwater_guide_preview.gd"),"authored pure Guide preview")
	check(store.data==before and not world.valid_landing(provider.points.court1),"Guide never changes water/support/lesson/rewards")
	await shot("free-guide");world.input_adapter.close_panel()
	check(await tap("professor"),"actual Professor context opens eligible lesson")
	check(world.panels.model.speaker=="professor_z1" and world.panels.model.body.contains("removes heat"),"Zone1 Professor teaches heat removal before use")
	check(not store.is_device_mode_unlocked("cryo"),"lesson opening has no unlock before acknowledgment")
	await shot("professor-lesson")
	var revision: int=world.panels.revision
	world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":revision-1})
	check(not store.is_device_mode_unlocked("cryo"),"stale lesson acknowledgment rejected")
	before=store.data.duplicate(true);store.fail_commit=true
	world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":revision})
	check(store.data==before and not store.is_device_mode_unlocked("cryo"),"failed lesson save retains exact locks/profile")
	store.fail_commit=false
	check(await tap("professor"),"lesson retry stays free")
	world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision});await ticks()
	check(store.is_device_mode_unlocked("cryo") and not store.has_device_capability("freezing"),"acknowledged lesson unlocks mode, capability waits for native outcome")
	check(provider.targets.first_ice.targeting_reason(world,store)=="unsupported_mode","actual learned Thermal cannot freeze first water tray")
	await mode("cryo")
	check(provider.targets.left_ice.targeting_reason(world,store)=="locked_capability","later target cannot substitute for first guided success")
	check(await aim("first_ice"),"guided first tray clear muzzle path")
	var target=provider.targets.first_ice;var body:=StaticBody2D.new();body.collision_layer=8;body.collision_mask=0
	var collider:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(8,35);collider.shape=box;body.add_child(collider);world.add_child(body)
	var ray: Dictionary=world.world_device_ray(world.player.device_muzzle().global_position,target.global_position,target);body.global_position=ray.from.lerp(ray.to,.5);await ticks()
	fire(true);await create_timer(.2).timeout;fire(false)
	check(target.exposure()==0,"physical wall blocks native cooling before exposure")
	body.free();await ticks();check(await aim("first_ice"),"native cooling resumes after physical occlusion removed")
	fire(true);await create_timer(.6).timeout;fire(false);await ticks()
	var partial: float=provider.targets.first_ice.exposure();check(partial>0 and partial<3,"native Cryo accumulates incomplete heat removal")
	await create_timer(.2).timeout;check(is_equal_approx(provider.targets.first_ice.exposure(),partial),"release stops cooling")
	world.input_adapter.open_panel("pause");await create_timer(.2).timeout;check(is_equal_approx(provider.targets.first_ice.exposure(),partial),"pause adds no cooling");world.input_adapter.close_panel()
	await shot("first-cooling")
	await reload_world();check(provider.targets.first_ice.exposure()==0,"unfinished cooling resets on Continue")
	check(not world.valid_landing(provider.points.court1),"unfinished cooling creates no support")
	check(await aim("first_ice"),"aim restored first tray")
	before=store.data.duplicate(true);store.fail_commit=true;fire(true);await create_timer(3.3).timeout;fire(false)
	check(store.data==before and not world.valid_landing(provider.points.court1) and not store.has_device_capability("freezing"),"failed native outcome save creates no floor/capability/receipt")
	store.fail_commit=false;await create_timer(1.2).timeout;await ticks()
	check(provider.targets.first_ice.is_committed() and store.has_device_capability("freezing"),"verified outcome retry teaches freezing atomically")
	check(store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1"] and world.valid_landing(provider.points.court1),"first saved solid grants C1 and rigid supported tray")
	check(world.input_adapter.modal=="explanation" and world.panels.model.body.contains("removed heat"),"once-only scientifically accurate first success")
	await shot("first-success");close_feedback();await ticks()
	var explained: Dictionary=store.data.extras.explained_puzzle_types.duplicate(true)
	await reload_world();check(store.data.extras.explained_puzzle_types==explained and world.input_adapter.modal!="explanation","acknowledged first success survives Continue without repeat")
	check(await move_to(provider.points.court1),"walk onto first secured ice")
	var stable: Vector2=world.player.position;await create_timer(.5).timeout
	check(world.player.position.distance_to(stable)<1 and world.valid_landing(stable),"occupied first tray stays stable")
	await shot("first-secured")
	await mode("thermal")
	check(provider.targets.first_ice.targeting_reason(world,store)=="committed","secured first ice cannot thaw from wrong mode")
	await expose("melt_supply");close_feedback();await ticks()
	check(provider._state.components["supply/water"].phase=="liquid" and provider._state.components["supply/water"].amount==2,"learned Thermal melts finite real supply")
	await shot("meltwater-supply")
	check(await approach("valve"),"valve reachable before fill transaction")
	before=store.data.duplicate(true);store.fail_commit=true;check(await tap("valve"),"fill attempted through actual contact during failed save")
	check(store.data==before and provider._state.components["supply/water"].amount==2 and store.data.active_run.state.checkpoint_progress.latest_unlocked_checkpoint_id=="C1","failed fill rolls back supply/trays/C2 together");store.fail_commit=false
	check(await tap("valve"),"actual context routes meltwater through fixed supply")
	check(provider._state.components["supply/water"].amount==0 and provider._state.components["crossing/left"].amount==1 and provider._state.components["crossing/right"].amount==1,"fill conserves exactly two units; no duplicated water")
	check(store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1","C2"],"both filled trays grant C2 before freezing")
	check(not provider.action_allowed("valve") and not world.valid_landing(provider.points.court3+Vector2(-56,0)),"consumed supply cannot refill or supply landing")
	await mode("cryo")
	check(provider.targets.left_ice.targeting_reason(world,store)=="prerequisite_missing" and not provider.action_allowed("latch"),"connected heater and liquid prevent freezing/latch")
	check(await approach("heater"),"approach real heat shutter")
	await shot("filled-heater-connected")
	check(await tap("heater"),"context mechanically disconnects heater")
	await expose("left_ice");close_feedback();await ticks()
	check(not world.valid_landing(provider.points.court3+Vector2(-56,0)),"solid ice alone lacks secured crossing frame")
	check(not provider.action_allowed("latch"),"one solid tray cannot latch pair")
	await expose("right_ice");close_feedback();await ticks()
	check(await approach("latch"),"latch reachable after both native freezes")
	before=store.data.duplicate(true);store.fail_commit=true;check(await tap("latch"),"actual latch contact during failed save")
	check(store.data==before and not world.valid_landing(provider.points.court3+Vector2(-56,0)),"failed latch save leaves crossing unsupported and state unchanged");store.fail_commit=false
	check(await tap("latch"),"player mechanically secures both verified solid trays")
	check(world.valid_landing(provider.points.court3+Vector2(-56,0)) and world.valid_landing(provider.points.court3+Vector2(56,0)) and not world.valid_landing(provider.points.court3),"secured platforms support full foot; small jump gap remains unsupported")
	close_feedback();check(await move_to(provider.points.court3+Vector2(-110,20)),"safe bankside view of secured crossing");await shot("both-latched")
	await crossing_checks()
	check(not provider.action_allowed("heater"),"secured crossing cannot reconnect heater beneath occupant")
	await reload_world();check(world.valid_landing(world.player.position) and provider._state.crossed,"occupied supported crossing survives Continue")
	await mode("thermal");fire(true);await create_timer(.3).timeout;fire(false)
	check(world.valid_landing(world.player.position) and provider._state.components["crossing/latch"].phase=="latched","wrong mode never removes occupied support")
	await shot("occupied-restored")
	check(provider.world_travel_checkpoint("C0"),"travel to older unlocked checkpoint")
	check(store.data.active_run.state.checkpoint_progress.latest_unlocked_checkpoint_id=="C2","visiting C0 cannot replace newest unlock C2")
	world.traversal_fall();await create_timer(.25).timeout;await ticks()
	check(world.player.position.distance_to(store.WORLD_SAVE.anchor("Z1L3","C2"))<1 and not world.dead,"fall recovers newest C2 with work intact")
	check(provider._state.components["crossing/latch"].phase=="latched" and provider._state.deaths==1,"death preserves committed crossing and counts once")
	await boundary_checks()
	await question_checks()
	if not walking:await stream_checks()
func crossing_checks() -> void:
	var start: Vector2=provider.points.court3+Vector2(-56,0)
	check(await move_to(start),"walk onto secured left platform")
	world.player.landed.connect(func(origin,destination):observations.append({"origin":origin,"destination":destination,"valid":world.valid_landing(destination)}))
	world.input_adapter._move(Vector2.RIGHT);await ticks(2);world.input_adapter.action("jump")
	check(world.player.jump_elapsed>=0,"ordinary shared Jump starts on secured support")
	for i in range(100):
		await physics_frame
		if world.player.jump_elapsed<0:break
	world.input_adapter._move(Vector2.ZERO);await ticks()
	check(provider._state.crossed and not observations.is_empty() and observations.back().valid,"real platform hop commits crossing receipt")
	var at: Vector2=world.player.position;var falls: int=world.fall_count;await create_timer(.5).timeout
	check(world.player.position.distance_to(at)<1 and world.fall_count==falls and world.valid_landing(at),"occupied secured landing remains stable")
func boundary_checks() -> void:
	var before: Dictionary=store.data.duplicate(true)
	for target in provider.targets.values():
		var foreign:=Marker2D.new();world.add_child(foreign)
		check(target.geometry_reason(foreign)=="foreign_muzzle","foreign muzzle rejected "+target.definition().id);foreign.free()
	var row: Dictionary=world.REGISTRY.definition("Z1L4")
	check(not world.activate("Z1L4",Vector2(row.entry[0],row.entry[1])),"unfinished Stillwater cannot enter next locked region")
	check(store.data==before,"border rejection awards no progress")
	var poly: PackedVector2Array=world.access.polygons.Z1L4
	for i in range(poly.size()):
		var at: Vector2=poly[i].lerp(poly[(i+1)%poly.size()],.5)
		check(not world.access.box_allowed(Rect2(at-Vector2(10,11),Vector2(20,22))),"full-foot locked border edge "+str(i))
	var target=provider.targets.melt_supply
	check(not provider.introduction_authorized(target,"z1l3_freezing"),"melting supply cannot impersonate Cryo introduction")
	var found:=false;var from:=Vector2.ZERO;var to:=Vector2.ZERO
	for edge in range(poly.size()):
		if found:break
		var a: Vector2=poly[edge];var b: Vector2=poly[(edge+1)%poly.size()];var normal: Vector2=(b-a).normalized().orthogonal()*35
		for part in range(1,20):
			var mid: Vector2=a.lerp(b,part/20.0)
			for sign_value in [-1,1]:
				var candidate: Vector2=mid+normal*sign_value;var end: Vector2=mid-normal*sign_value
				if world.access.region_at(candidate)!="Z1L3" or world.access.region_at(end)!="Z1L4" or not world.valid_landing(candidate):continue
				from=candidate;to=end;found=true;break
			if found:break
	check(found,"real supported locked-border approach found")
	if found:
		var direction: Vector2=(to-from).normalized()
		for action in ["walk","run","jump"]:
			check(world.activate("Z1L3",from),"real border departure "+action)
			world.input_adapter._move(direction);world.player.set_touch_sprinting(action=="run")
			if action=="jump":check(world.player.request_jump(),"ordinary Jump against locked border starts")
			for tick in range(35):await physics_frame;check(world.access.point_allowed(world.player.position) and world.active_subregion_id=="Z1L3","actual "+action+" stays inside earned territory "+str(tick))
			world.input_adapter.stop_all("border_test",true)
		for height in [0,40,160]:
			var origin: Vector2=from-Vector2(0,height);var end: Vector2=to-Vector2(0,height)
			check(world.world_emission_endpoint(from,origin,end).distance_to(origin)<origin.distance_to(end),"logical elevated Fire clips unearned border "+str(height))
		for selected in ["thermal","cryo"]:
			check(world.activate("Z1L3",from),"Fire border approach "+selected);await mode(selected)
			var emitter=world.input_adapter.emitter;emitter.facing=direction;emitter.release();check(emitter.press(),"actual learned-mode Fire against border "+selected);await ticks(6)
			var snapshot: Dictionary=emitter.snapshot();check(not snapshot.is_empty(),"border beam visible "+selected)
			if not snapshot.is_empty():check(world.access.ray_fraction(world.player.position,world.player.position+snapshot.point-snapshot.origin)>.99,"actual beam ends inside earned territory "+selected)
			emitter.release()
		check(not store.is_level_complete("melting_and_freezing",3) and not world.access.allowed("Z1L4"),"all live bypass attempts award no completion/unlock")
func stream_checks() -> void:
	close_feedback();var attempt: String=store.data.active_run.attempt_id;var saved: Dictionary=provider._state.duplicate(true);var rewards: Dictionary=store.achievement_state().duplicate(true)
	check(store.save_world_location(world),"archive Stillwater before ordinary backtrack")
	var row: Dictionary=world.REGISTRY.definition("Z1L2")
	check(world.activate("Z1L2",Vector2(row.entry[0],row.entry[1])) and store.enter_world_subregion(world,"Z1L2"),"ordinary return to earned Mill")
	await ticks();check(not provider.active(),"inactive Stillwater targets suspended")
	check(world.unmount_chunk("Z1L3.shell"),"inactive Stillwater chunk streams out");await ticks()
	var chunk=load("res://World/Zone1/Z1L3Shell.tscn").instantiate();chunk.configure_geometry(world.models[0]);check(world.mount_chunk(chunk),"Stillwater shell streams back")
	provider=PROVIDER.new();chunk.add_child(provider);check(provider.bind_crossing(world),"rebind independent Stillwater modules after streaming")
	row=world.REGISTRY.definition("Z1L3")
	check(world.activate("Z1L3",Vector2(row.entry[0],row.entry[1])) and store.enter_world_subregion(world,"Z1L3"),"ordinary return restores archived attempt")
	await ticks();check(provider._state==saved and store.data.active_run.attempt_id==attempt,"stream return preserves water/latch/hop/death/attempt")
	check(world.valid_landing(provider.points.court3+Vector2(-56,0)) and store.achievement_state()==rewards,"stream rebuild restores secured support without duplicate rewards")
func question_checks() -> void:
	check(await tap("question"),"optional observation opens with actual context")
	var before: Dictionary=store.data.duplicate(true)
	provider._question_intent("guides.library","stillwater_answer_yes",{"view_revision":world.panels.revision})
	check(world.panels.model.body.contains("Try again") and store.data==before,"wrong answer gives free feedback with no gate/reward mutation")
	provider._question_intent("guides.library","stillwater_answer_no",{"view_revision":world.panels.revision})
	check(world.panels.model.body.contains("Correct") and world.panels.model.body.contains("liquid water") and store.data==before,"correct answer distinguishes feeling cold from water freezing")
	await shot("optional-observation");world.input_adapter.close_panel()
func future_checks() -> void:
	close_feedback();provider.set_process(false)
	var saved: Dictionary=store.data.active_run.state.duplicate(true)
	for invalid in [{"version":99,"future":{"keep":true}},{"version":1,"subregion":"Z1L3","components":{},"items":{}}]:
		store.data.active_run.state={provider.STATE_KEY:invalid,"unknown":{"retain":true}}
		var before: Dictionary=store.data.duplicate(true);provider._restored();await ticks()
		check(provider._state.is_empty() and not provider.commit_action("valve") and store.data==before,"future/malformed records retained with writes disabled")
	store.data.active_run.state=saved;provider._restored();provider.set_process(true);await ticks()
	check(provider.active() and provider._state.crossed,"supported same attempt resumes after invalid-record fixture")
func finish_checks() -> void:
	check(await approach("exit"),"supported exit reached after science and actual hop")
	var before: Dictionary=store.data.duplicate(true);var hash: String=FileAccess.get_sha256(store.save_path);store.fail_commit=true
	check(not provider.finish() and store.data==before and FileAccess.get_sha256(store.save_path)==hash,"failed completion preserves exact disk/profile/attempt")
	store.fail_commit=false
	check(await tap("exit"),"actual exit commits Stillwater completion")
	check(store.is_level_complete("melting_and_freezing",3) and store.total_stars()==3,"one completion star; prior two retained")
	before=store.data.duplicate(true);check(not provider.finish() and store.data==before,"repeat completion cannot farm awards")
	if not walking and not rendering:check(DirAccess.copy_absolute(ProjectSettings.globalize_path(store.save_path),ProjectSettings.globalize_path("res://../fixtures/relaunch.save"))==OK,"retain actual written binary profile for separate-process restore")
func run() -> void:
	root.size=Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await ticks()
	store=root.get_node("PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L3")
	check(world.activate("Z1L3",Vector2(row.entry[0],row.entry[1])),"eligible Stillwater arrival")
	check(store.enter_world_subregion(world,"Z1L3"),"isolated real-writer attempt")
	provider=PROVIDER.new();world.chunks["Z1L3.shell"].add_child(provider)
	check(provider.bind_crossing(world),"production provider binds reserved courts: "+provider.last_error)
	if provider.last_error!="" or provider._state.is_empty():finish_result();return
	await ticks()
	if rendering:
		root.grab_focus()
		for i in range(180):
			if world.input_adapter.allowed():break
			await process_frame
		check(world.input_adapter.allowed(),"render window owns focus and supported HUD before input checks")
		if not world.input_adapter.allowed():finish_result();return
	FileAccess.open("res://../evidence/assembly-contract.json",FileAccess.WRITE).store_string(JSON.stringify({"cube_unit_px":20,"top_px":[40,20],"assemblies":provider.contract.assemblies,"pit_polygons":provider.pits,"first_support":[140,84],"pair_support_each":[80,70],"pair_jump_gap":32,"supply_units":2,"cold_or_heat_seconds":3,"indoor":"Outdoor stations; existing occupied-room cutaways unchanged."},"\t"))
	await stage_checks()
	if not walking:await future_checks()
	await finish_checks()
	check(world.REGISTRY.READY_CHUNKS.is_empty(),"normal readiness remains empty")
	finish_result()
func finish_result() -> void:
	var label: String=("render-compact" if root.size.x==640 else "render") if rendering else ("route" if walking else "check")
	FileAccess.open("res://../evidence/"+label+"-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"walked_world_units":distance_walked,"jump_observations":observations},"\t"))
	print("STILLWATER026 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
