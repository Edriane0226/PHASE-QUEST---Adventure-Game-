extends SceneTree
const PROVIDER=preload("res://Scripts/World/Zone1/frozen_mill_world.gd")
var world
var provider
var store
var checks:=0
var failures: Array=[]
var rendering:=false
var captures: Array=[]
var walking:=false
var device_before: Dictionary={}
var distance_walked:=0.0
var jump_observations: Array=[]
const PLANNER=preload("res://path_planner.gd")
class WalkPhysics extends RefCounted:
	var world
	func standable(at: Vector2) -> bool:return world.valid_landing(at)
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
	for i in range(7):await process_frame
	await RenderingServer.frame_post_draw
	if world.panels.visible:
		for id in world.panels.action_buttons:
			var button: Control=world.panels.action_buttons[id]
			check(button.is_visible_in_tree() and button.size.y>=48 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"visible touch-sized in-viewport panel action "+label+":"+id)
	var file: String=label+"-"+str(root.size.x)+".png"
	check(root.get_texture().get_image().save_png("res://../evidence/"+file)==OK,"capture "+file);captures.append(file)
func move_to(point: Vector2) -> bool:
	close_feedback()
	if not walking:return world.activate("Z1L2",point)
	var collision:=WalkPhysics.new();collision.world=world
	var path: PackedVector2Array=PLANNER.new().route(collision,PackedVector2Array([world.player.position,point]))
	if path.is_empty():return false
	path.append(point)
	for target in path:
		var ticks_allowed:=maxi(180,ceili(world.player.position.distance_to(target)/maxf(30,world.player.movement_speed())*Engine.physics_ticks_per_second*1.6)+60)
		var blocked_ticks:=0
		for tick in range(ticks_allowed):
			var delta: Vector2=target-world.player.position
			if delta.length()<4:break
			var before: Vector2=world.player.position
			world.input_adapter._move(delta.normalized()*minf(1,delta.length()/12));await physics_frame
			distance_walked+=before.distance_to(world.player.position)
			blocked_ticks=blocked_ticks+1 if before.distance_to(world.player.position)<.05 else 0
			if blocked_ticks>90:break
		world.input_adapter._move(Vector2.ZERO)
		if world.player.position.distance_to(target)>6:print("STUCK025 ",world.player.position," -> ",target);return false
	await ticks();return true
func approach(id: String) -> bool:
	close_feedback()
	for radius in [28,34,39]:
		for step in range(24):
			var at: Vector2=provider.points[id]+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(at):continue
			if not await move_to(at):continue
			if provider.action_allowed(id):return true
	return false
func tap(id: String) -> bool:
	if not await approach(id):print("NO_APPROACH025 ",id);return false
	await ticks();world.input_adapter.refresh()
	var record: Dictionary=world.active_chunk().context_record()
	if record.get("key")!="Z1L2:"+id:print("CONTEXT025 ",id," actual=",record.get("key"));return false
	var at: Vector2=world.hud.controls.context.get_global_rect().get_center()
	world.hud.route_touch(201,at,true);world.hud.route_touch(201,at,false)
	await create_timer(.85).timeout;await ticks()
	return true
func target_for(index: int):return provider.targets.get("mill_"+provider.PARTS[index]+"_casing")
func aim(index: int) -> bool:
	close_feedback()
	var target=target_for(index)
	if not is_instance_valid(target):return false
	var emitter=world.input_adapter.emitter
	for radius in [55,65,75,85]:
		for step in range(24):
			var at: Vector2=target.get_meta("ground_xy")+Vector2.from_angle(step*TAU/24)*radius
			if not world.valid_landing(at) or not await move_to(at):continue
			emitter.facing=(target.global_position-world.player.device_muzzle().global_position).normalized();emitter.release();emitter._aim()
			await ticks()
			if emitter.selected==target:return true
	return false
func fire(down: bool) -> void:
	world.input_adapter.refresh();world.hud.route_touch(301,world.hud.rects.fire.get_center(),down)
func heat(index: int) -> void:
	check(await aim(index),"supported native aim for "+provider.PARTS[index])
	fire(true)
	for i in range(360):
		await physics_frame
		if provider._state.legacy.workshop_parts[index]>0:break
	fire(false);await ticks()
	check(provider._state.legacy.workshop_parts[index]==1,"real Fire releases only casing "+provider.PARTS[index])
func cross_j2() -> bool:
	var jump: Dictionary=provider._jump
	var from: Vector2=world.models[0].v(jump.from)+world.active_chunk().ground_origin
	check(await move_to(from),"approach original J2 takeoff")
	var direction: Vector2=(world.models[0].v(jump.toward)-world.models[0].v(jump.from)).normalized()
	world.input_adapter._move(direction);await ticks(2)
	var observation:={"start":world.player.position,"velocity":world.player.velocity,"allowed":world.input_adapter.allowed(),"action_elapsed":world.player.action_elapsed,"floor":world.player._floor_height,"before_falls":world.fall_count}
	var listener:=func(origin,destination):observation["origin"]=origin;observation["destination"]=destination;observation["takeoff"]=Geometry2D.is_point_in_polygon(origin,world.models[0].polygon(jump.takeoff,provider.chunk.ground_origin));observation["landing"]=Geometry2D.is_point_in_polygon(destination,world.models[0].polygon(jump.landing,provider.chunk.ground_origin));observation["valid"]=world.valid_landing(destination)
	world.player.landed.connect(listener)
	world.input_adapter.action("jump")
	observation["started"]=world.player.jump_elapsed>=0
	for i in range(180):
		await physics_frame
		observation["wait_ticks"]=i+1
		if world.player.jump_elapsed<0:break
	world.input_adapter._move(Vector2.ZERO);await ticks()
	world.player.landed.disconnect(listener)
	observation["end"]=world.player.position;observation["after_falls"]=world.fall_count;observation["dead"]=world.dead;observation["receipt"]=provider._state.legacy.get("jump_records",{}).get("z1_l2_j2",false)
	jump_observations.append(observation);print("J2 observation ",observation)
	return observation.receipt
func reload_world() -> void:
	close_feedback()
	check(store.save_world_location(world),"real world location/attempt save")
	store.load_profile();check(world.restore_saved_world(world.access),"real Continue restores active world attempt")
	await ticks()
func stage_checks() -> void:
	if not walking:
		var before_help: Dictionary=store.data.duplicate(true)
		check(world.input_adapter.open_lesson("resonance"),"free contextual help opens before unresolved bells")
		check(store.data==before_help,"opening contextual help grants no reward before acknowledgment")
		store.fail_commit=true
		world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
		check(store.data==before_help,"failed acknowledged-help transaction retains exact profile")
		store.fail_commit=false
		check(world.input_adapter.open_lesson("resonance"),"free help remains available for retry")
		world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
		check(store.achievement_state().unlocks.has("good_question") and not provider._state.legacy.clear,"actual guidance acknowledgment preserves Good Question without solving task")
		await ticks()
	for target in provider.targets.values():check(target.targeting_reason(world,store)=="prerequisite_missing","Thermal cannot bypass mechanical bell yard "+target.definition().id)
	check(await tap("HeaterCartridge"),"touch wrong high bell")
	check(provider._state.legacy.bell_count==0,"wrong sequence restarts without opening gate")
	for id in provider.BELLS:check(await tap(id),"actual touch bell "+id)
	check(provider._state.legacy.furnace_on and not provider._state.legacy.clear,"ordered bells start mechanical fracture timer")
	await create_timer(3.2).timeout;await ticks()
	check(provider._state.legacy.clear and store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1"],"bell mechanism opens bridge and C1")
	check(store.data.extras.get("independent_phase_evidence",{}).is_empty(),"vibration/fracture grants no melting evidence")
	check(world.input_adapter.modal=="explanation" and world.panels.model.body.contains("not evidence"),"accurate mechanical first-success feedback")
	await shot("bell-fracture");close_feedback();await ticks()
	# Free demo: actual shared Guides entry uses provider prose and pure preview.
	var key: String=store.instance_id("melting_and_freezing",2,"mill_reference_melting")+":melting"
	var before: Dictionary=store.data.duplicate(true)
	world.input_adapter.open_panel("guides");world.input_adapter._open_guide(key);await ticks(15)
	check(is_instance_valid(world.input_adapter.guide_preview) and world.input_adapter.guide_preview.get_script().resource_path.ends_with("mill_guide_preview.gd"),"free Mill Guide uses disposable native-kernel demonstration")
	check(store.data==before and provider._state.legacy.workshop_parts==[0,0,0],"demonstration writes no live stage proof capability or rewards")
	await shot("free-thermal-guide");world.input_adapter.close_panel();await ticks()
	var dial: Vector2=world.hud.rects.thermal.get_center()
	world.hud.route_touch(302,dial,true);world.hud.route_touch(302,dial,false)
	check(store.selected_device_mode()=="thermal","actual mode-cluster touch retains learned Thermal selection")
	check(await aim(0),"first casing reachable after mechanical bridge")
	var target=target_for(0)
	fire(true);await create_timer(1.2).timeout;await shot("thermal-contact");fire(false)
	var partial: float=target.exposure()
	check(partial>0 and partial<4 and provider._state.legacy.workshop_parts[0]==0,"held touch Fire accumulates valid incomplete heat")
	await create_timer(.4).timeout;check(is_equal_approx(target.exposure(),partial),"release holds cumulative heat")
	await shot("partial-ice")
	if not walking:
		var body:=StaticBody2D.new();body.collision_layer=8;body.collision_mask=0
		var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(10,32);shape.shape=box;body.add_child(shape);world.add_child(body)
		var ray: Dictionary=world.world_device_ray(world.player.device_muzzle().global_position,target.global_position,target)
		body.global_position=ray.from.lerp(ray.to,.5);await ticks()
		fire(true);await create_timer(.3).timeout;fire(false)
		check(is_equal_approx(target.exposure(),partial),"actual wall blocks valid Thermal hit without erasing earlier heat")
		body.free();await ticks();check(await aim(0),"same casing can resume after occlusion")
		fire(true);await create_timer(.2).timeout;world.input_adapter._move(-world.input_adapter.emitter.facing);await ticks(4)
		partial=target.exposure();await create_timer(.25).timeout;world.input_adapter._move(Vector2.ZERO);fire(false)
		check(is_equal_approx(target.exposure(),partial) and partial>0,"lost aimed hit stops further heat but retains session credit")
	world.input_adapter.open_panel("pause");await create_timer(.25).timeout
	check(is_equal_approx(target.exposure(),partial),"pause adds no heat")
	world.input_adapter.close_panel();await ticks()
	if not walking:
		before=store.data.duplicate(true);var fall_hash: String=FileAccess.get_sha256(store.save_path)
		store.fail_commit=true;world.traversal_fall()
		check(world.dead and store.data==before and FileAccess.get_sha256(store.save_path)==fall_hash,"failed real fall recovery preserves profile/disk and blocks unsafe fallback")
		store.fail_commit=false;await create_timer(1.3).timeout;await ticks()
		check(not world.dead and target_for(0).exposure()==0 and world.player.position.distance_to(store.WORLD_SAVE.anchor("Z1L2","C1"))<2,"real fall retries newest C1 and clears unfinished native heat")
	await reload_world();target=target_for(0)
	check(target.exposure()==0 and provider._state.legacy.workshop_parts==[0,0,0],"reload resets unfinished exposure without inventing a thaw")
	await heat(0);close_feedback();await ticks()
	check(await tap("runtime_gear") and world.player.carrying,"contextual lift carries one released gear")
	check(provider._held.is_visible_in_tree() and not provider.pieces.runtime_gear.visible,"carried gear immediately visible with ground copy absent")
	check(not world.player.request_jump() and not world.input_adapter.emitter.available(),"carried metal blocks Jump and Fire")
	before=store.data.duplicate(true)
	check(await tap("runtime_tray_crank"),"wrong matching tray remains recoverable")
	check(store.data==before and provider._state.legacy.workshop_held==0 and world.player.carrying,"wrong placement retains exact profile and unique gear")
	await shot("wrong-tray")
	await reload_world()
	check(provider._state.legacy.workshop_held==0 and provider._held.get_meta("unique_item_id")=="gear","Continue retains exact carried identity")
	if not walking:
		var home: Vector2=world.player.position
		var connection: Dictionary=world.connection("Z1L1--Z1L2")
		var crossing: Vector2=Vector2(connection.border.trail_crossings[0].at[0],connection.border.trail_crossings[0].at[1])
		check(world.activate("Z1L2",crossing+Vector2(45,0)),"carried boundary inspection starts on supported Mill ground")
		for i in range(90):world.input_adapter._move(Vector2.LEFT);await physics_frame
		world.input_adapter._move(Vector2.ZERO)
		check(world.active_subregion_id=="Z1L2" and world.player.carrying and provider._state.legacy.workshop_held==0,"real movement cannot carry unique gear across local boundary")
		world.activate("Z1L2",home);await ticks()
	world.dead=true;await ticks()
	check(world.recover_world_checkpoint(world.access),"death uses real world checkpoint recovery")
	await ticks()
	check(provider._state.legacy.workshop_parts[0]==1 and provider._state.legacy.workshop_held==0 and world.player.carrying,"death retains completed thaw and one carried item")
	check(world.player.position.distance_to(store.WORLD_SAVE.anchor("Z1L2","C1"))<2,"death returns newest C1")
	check(provider._state.legacy.deaths==(1 if walking else 2) and not provider._state.legacy.death_pending,"fall/death facts persist once; recovery clears pending death")
	check(await approach("runtime_tray_gear"),"supported contact pose for interruption test")
	world.input_adapter.refresh();var contact: Vector2=world.hud.controls.context.get_global_rect().get_center()
	before=store.data.duplicate(true);world.hud.route_touch(202,contact,true);world.hud.route_touch(202,contact,false)
	check(world.player.action_elapsed>=0,"context starts actual place pose before hand contact")
	world.input_adapter.open_panel("pause");await create_timer(.9).timeout;world.input_adapter.close_panel();await ticks()
	check(store.data==before and provider._state.legacy.workshop_held==0 and world.player.carrying,"pause before hand contact cancels stale placement without item loss")
	check(await tap("runtime_tray_gear") and provider._state.legacy.workshop_parts[0]==2,"contextual place fits gear uniquely")
	# Fail final native save: completed proof must not release the part on disk.
	check(await aim(1),"second native casing aim")
	before=store.data.duplicate(true);var hash: String=FileAccess.get_sha256(store.save_path);store.fail_commit=true
	fire(true);await create_timer(4.9).timeout;fire(false)
	check(not target_for(1).verified_outcome(store,world).is_empty(),"four valid seconds produce verified second casing outcome")
	check(store.data==before and FileAccess.get_sha256(store.save_path)==hash and provider._state.legacy.workshop_parts[1]==0 and provider.pieces.runtime_crank.visuals.get_node("Artwork").texture==world.kits[0].get_meta("tiles")["crank_thaw_2"],"failed thaw save keeps exact profile/disk/ownership and late ice art closed")
	store.fail_commit=false;await create_timer(1.3).timeout;await ticks()
	check(provider._state.legacy.workshop_parts[1]==1,"verified native thaw retries without extra heating")
	check(await tap("runtime_crank") and world.player.carrying,"lift released crank")
	check(await tap("runtime_tray_crank") and provider._state.legacy.workshop_parts[1]==2,"place crank in matching tray")
	await heat(2);close_feedback();await ticks()
	check(await tap("runtime_brake_shoe"),"lift released brake shoe")
	check(await tap("runtime_tray_brake_shoe"),"place brake shoe in matching tray")
	check(provider._state.legacy.workshop_parts==[2,2,2] and provider._state.legacy.latch_thawed and store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1","C2"],"only three unique placements release maintenance route and C2")
	check(store.data.active_run.state.device_outcomes.size()==3 and store.data.extras.independent_phase_evidence.size()==3,"three unique native thaw receipts")
	await shot("three-placed");close_feedback();await ticks()
	await lift_checks()
func lift_checks() -> void:
	check(not provider._state.legacy.cache_thawed,"freight lift stays unbalanced before controls")
	close_feedback();await ticks()
	var crossed:=await cross_j2()
	check(crossed,"real Jump earns original marked far-side landing")
	if not crossed:finish_result();return
	check(await tap("ReflectorA"),"operate heavy winch")
	check(await tap("ReflectorB"),"operate light winch once")
	await create_timer(.5).timeout
	check(provider.weight_total()==4 and not provider._state.legacy.cache_thawed,"wrong four-unit load cannot raise lift")
	check(await tap("ReflectorB"),"operate light winch twice")
	await create_timer(3.2).timeout;await ticks()
	check(provider.weight_total()==5 and provider._state.legacy.cache_thawed,"actual 3+2 counterweights raise five-unit load")
	check(not provider.action_allowed("MillCrankRecovery"),"pin pickup requires opened grounded return")
	check(await tap("WalkbackLever") and provider._state.legacy.walkback_open,"actual context lowers permanent cargo return")
	check(await tap("MillCrankRecovery") and provider._state.legacy.crank=="held" and world.player.carrying,"lift raises unique brake pin; real context carries it")
	await shot("brake-pin-held")
	await reload_world()
	check(provider._state.legacy.crank=="held" and provider._state.legacy.walkback_open and world.player.carrying,"Continue retains opened return and unique held brake pin")
	check(await tap("CrankSocket") and provider._state.legacy.crank=="installed" and not world.player.carrying,"walk/return and contextual installation secure lift exit")
	await shot("lift-secured")
	check(provider.PROGRESS.complete(provider._state.legacy),"all required stages complete before any optional question")
	var before: Dictionary=store.data.duplicate(true)
	check(provider.open_question(),"optional question opens")
	provider._question_intent("guides.library","mill_answer_1",{"view_revision":world.panels.revision})
	check(world.panels.model.body.contains("Try again"),"wrong optional answer gives inline feedback")
	provider._question_intent("guides.library","mill_answer_0",{"view_revision":world.panels.revision})
	check(world.panels.model.body.contains("Correct") and store.data==before,"correct optional answer changes no progress/reward predicate")
	await shot("optional-question");world.input_adapter.close_panel();await ticks()
	check(provider.PROGRESS.complete(provider._state.legacy),"all actual stage predicates complete independently of question")
	check(store.device_state()==device_before,"Mill grants no new capability or mode")
func boundary_checks() -> void:
	close_feedback()
	var attempt: String=store.data.active_run.attempt_id
	var state: Dictionary=provider._state.duplicate(true)
	var rewards: Dictionary=store.achievement_state().duplicate(true)
	check(store.save_world_location(world),"archive Mill before boundary return")
	var connection: Dictionary=world.connection("Z1L1--Z1L2")
	var crossing:=Vector2(connection.border.trail_crossings[0].at[0],connection.border.trail_crossings[0].at[1])
	check(world.activate("Z1L2",crossing+Vector2(45,0)),"unladen geographic return starts on real border ground")
	for i in range(150):
		world.input_adapter._move(Vector2.LEFT);await physics_frame
		if world.active_subregion_id=="Z1L1":break
	world.input_adapter._move(Vector2.ZERO)
	check(world.active_subregion_id=="Z1L1" and store.data.active_run.level==1,"actual movement crosses boundary and archives Mill automatically")
	await ticks()
	check(not provider.active() and not world.input_adapter.emitter.held,"leaving subregion suspends all Mill targets/Fire")
	check(world.unmount_chunk("Z1L2.shell"),"inactive Mill streams out")
	await ticks()
	check(store.save_world_location(world),"save during streamed-out source bodies")
	var chunk=load("res://World/Zone1/Z1L2Shell.tscn").instantiate();chunk.configure_geometry(world.models[0])
	check(world.mount_chunk(chunk),"Mill source geometry streams back")
	provider=PROVIDER.new();world.chunks["Z1L2.shell"].add_child(provider);check(provider.bind_mill(world),"reloaded provider binds new physical source bodies")
	check(world.activate("Z1L1",crossing-Vector2(45,0)),"supported reverse boundary approach")
	for i in range(150):
		world.input_adapter._move(Vector2.RIGHT);await physics_frame
		if world.active_subregion_id=="Z1L2":break
	world.input_adapter._move(Vector2.ZERO)
	check(world.active_subregion_id=="Z1L2" and store.data.active_run.level==2,"actual reverse movement restores archived Mill attempt")
	await ticks()
	check(provider.active() and store.data.active_run.attempt_id==attempt and provider._state.legacy==state.legacy,"stream/return retains every committed stage and stable attempt")
	check(store.achievement_state()==rewards and store.device_state()==device_before,"boundary return awards nothing and grants no capability")
	check(is_instance_valid(world.source_bodies.get("Z1L2:SolidBarriers/ExitBridgeGate/Body")) and world.source_bodies["Z1L2:SolidBarriers/ExitBridgeGate/Body"].is_inside_tree(),"stream rebinds actual source collision identity")
func migration_checks() -> void:
	provider.set_process(false);close_feedback()
	var original_completed: Dictionary=store.data.completed.duplicate(true)
	var earned: Dictionary=store.data.extras.duplicate(true)
	var rows: Array=[
		{"name":"retired opening module held","raw":{"part":"held","clear":false},"parts":[0,0,0],"bell":1,"held":-1},
		{"name":"retired opening module docked","raw":{"part":"docked","clear":false},"parts":[0,0,0],"bell":2,"held":-1},
		{"name":"old completed first thaw","raw":{"part":"docked","clear":true,"gear_thawed":true},"parts":[1,0,0],"bell":3,"held":-1},
		{"name":"old earned C2","raw":{"part":"docked","clear":true,"gear_thawed":true,"latch_thawed":true,"checkpoint":"C2","mirror_a":1,"mirror_b":2},"parts":[2,2,2],"bell":3,"held":-1},
		{"name":"saved modern held metal","raw":{"route_version":2,"part":"docked","clear":true,"bell_count":3,"workshop_version":1,"workshop_parts":[2,1,0],"workshop_held":1},"parts":[2,1,0],"bell":3,"held":1},
		{"name":"old lifted brake pin","raw":{"part":"docked","clear":true,"gear_thawed":true,"latch_thawed":true,"cache_thawed":true,"crank":"held","walkback_open":true,"checkpoint":"C2"},"parts":[2,2,2],"bell":3,"held":-1},
		{"name":"old installed brake pin","raw":{"part":"docked","clear":true,"gear_thawed":true,"latch_thawed":true,"cache_thawed":true,"crank":"installed","walkback_open":true,"checkpoint":"C2"},"parts":[2,2,2],"bell":3,"held":-1}
	]
	for row in rows:
		close_feedback();var entry: Dictionary=world.REGISTRY.definition("Z1L2")
		check(world.activate("Z1L2",Vector2(entry.entry[0],entry.entry[1])),"safe migration fixture arrival "+row.name)
		var raw: Dictionary=row.raw.duplicate(true);raw.future_record={"retain":[1,2,3]}
		store.data.active_run.state=raw;store.data.active_run.attempt_id="migration025:"+row.name;store.data.active_run.achievement_history_known=false
		provider._restored();await ticks()
		check(not provider._state.is_empty(),"legacy accepted "+row.name)
		if provider._state.is_empty():continue
		check(provider._state.legacy.workshop_parts==row.parts and provider._state.legacy.bell_count==row.bell and provider._state.legacy.workshop_held==row.held,"earned stages/unique metal retained "+row.name)
		check(provider._state.legacy.future_record==raw.future_record and provider._state.legacy_original==raw,"exact source and unknown fields retained "+row.name)
		check(provider._commit(provider._state),"versioned migration writes "+row.name)
		var once: Dictionary=store.data.duplicate(true);provider._restored();await ticks()
		check(store.data==once and provider._state.legacy.workshop_parts==row.parts,"second migration idempotent "+row.name)
		if row.held>=0:check(world.player.carrying and provider._held.is_visible_in_tree() and provider._held.get_meta("unique_item_id")==provider.PARTS[row.held],"modern held part restores visibly once")
		if row.name=="old earned C2":check(store.data.active_run.state.checkpoint_progress.latest_unlocked_checkpoint_id=="C2" and provider.weight_total()==4 and not provider._state.legacy.cache_thawed,"C2 survives; partial balance never auto-completes")
		if row.name=="old lifted brake pin":check(world.player.carrying and provider._held.get_meta("unique_item_id")=="brake_pin" and provider._state.legacy.walkback_open,"old pin retains opened grounded return")
	for key in ["achievement_unlocks","achievement_progress","achievement_toasts","solved_puzzle_ids","explained_puzzle_types","independent_phase_evidence"]:check(store.data.extras.get(key)==earned.get(key),"migration retains earned profile field "+key)
	store.data.completed["melting_and_freezing:2"]=true;store.data.active_run.state={};provider._restored();await ticks()
	check(provider.PROGRESS.complete(provider._state.legacy) and not world.player.carrying and provider.targets.is_empty(),"completion-only legacy profile recovers solved Mill without replay")
	var good: Dictionary=provider._state.duplicate(true)
	for invalid in [{"version":99,"future":"retain"},{"version":1,"subregion":"Z1L2","legacy":{"workshop_version":99}}]:
		store.data.active_run.state={provider.STATE_KEY:invalid,"future_outer":{"keep":true}}
		var before: Dictionary=store.data.duplicate(true);provider._restored();await ticks()
		check(provider._state.is_empty() and not provider.commit_action("ReflectorA") and store.data==before,"future modular state retained with writes disabled")
	store.data.completed=original_completed
	store.data.active_run.state={provider.STATE_KEY:good};provider._restored();await ticks()
	check(provider.active() and provider.PROGRESS.complete(provider._state.legacy),"valid state can resume after disposable future-record checks")
	provider.set_process(true)
func finish_checks() -> void:
	close_feedback()
	check(await approach("exit"),"actual supported exit approach")
	var before: Dictionary=store.data.duplicate(true);var hash: String=FileAccess.get_sha256(store.save_path)
	store.fail_commit=true
	check(not provider.finish() and store.data==before and FileAccess.get_sha256(store.save_path)==hash and store.session_active,"failed final completion retains attempt/disk/earned stages")
	store.fail_commit=false
	check(await tap("exit"),"actual context completes all three stages at exit")
	check(store.is_level_complete("melting_and_freezing",2) and store.total_stars()==2,"one Mill completion star, original L1 star retained")
	before=store.data.duplicate(true)
	check(not provider.finish() and store.data==before,"repeated exit cannot farm completion or awards")
func write_contract() -> void:
	var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://cube-inventory.json"))
	var components: Array=[];var support: Array=[]
	for id in provider.pieces:
		var piece=provider.pieces[id];var asset: String=piece.get_meta("asset_id","")
		var entries: Array=inventory.existing_modules.filter(func(entry):return entry.id==asset)
		if entries.is_empty():continue
		components.append({"id":id,"asset":asset,"ground_xy":[piece.position.x,piece.position.y],"elevation":piece.elevation,"footprint_cubes":entries[0].ground_envelope_cubes,"height_layers":entries[0].height_envelope_layers,"pivot_px":entries[0].pivot_px,"scale":entries[0].world_scale,"interaction_range":42,"source_inventory":entries[0]})
	for record in provider._conditional:support.append({"kind":record.get("mill_kind"),"polygon":Array(record.polygon),"base_height_layers":record.height/20.0})
	FileAccess.open("res://../evidence/assembly-contract.json",FileAccess.WRITE).store_string(JSON.stringify({"cube_unit_px":20,"cap_px":[40,20],"components":components,"source_support":support,"unique_items":["gear","crank","brake_shoe","brake_pin"],"fire_range":100,"thermal_seconds":4,"legacy_signs":{"footprint_cubes":[1,1],"ground_collision":false,"contact_range":42,"note":"Existing marker sign artwork/scale preserved; decorative placement envelope grants no support/collision."},"contract":"Independent existing parts/trays/bells/winches/pin/housing/lift; exact fractional legacy ground XY, original pivots and actual source support. Outdoor installation; existing indoor cutaways unchanged. Cube envelopes never create collision/floor from a texture."},"\t"))
func run() -> void:
	root.size=Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await ticks()
	store=root.get_node("PlayerSave")
	var row: Dictionary=world.REGISTRY.definition("Z1L2")
	check(world.activate("Z1L2",Vector2(row.entry[0],row.entry[1])),"actual Mill arrival")
	check(store.enter_world_subregion(world,"Z1L2"),"disposable Mill attempt")
	provider=PROVIDER.new();world.chunks["Z1L2.shell"].add_child(provider)
	check(provider.bind_mill(world),"Mill provider binds original world pieces")
	await ticks()
	check(provider.active(),"exact source/chunk/attempt authority")
	check(provider.targets.size()==3 and provider.targets.values().all(func(target):return target.definition().required_exposure==4.0),"three explicit native casings each require four valid seconds")
	for part in provider.PARTS:
		var tiles: Dictionary=world.kits[0].get_meta("tiles",{})
		check(range(4).all(func(frame):return tiles.has(part+"_thaw_"+str(frame))),"all four approved ice frames retained for "+part)
	check(store.has_device_capability("melting") and not store.is_device_mode_unlocked("cryo"),"retained L1 powers, no new capability")
	device_before=store.device_state().duplicate(true)
	write_contract()
	await stage_checks()
	if not walking:
		await boundary_checks()
	await finish_checks()
	if not walking:
		check(store.enter_world_subregion(world,"Z1L2"),"completed Mill can reopen its archived attempt for isolated migration fixtures")
		provider.refresh_binding();await ticks()
		await migration_checks()
	check(world.REGISTRY.READY_CHUNKS.is_empty(),"normal readiness gated")
	finish_result()
func finish_result() -> void:
	var label: String=("render-compact" if root.size.x==640 else "render") if rendering else ("route" if walking else "check")
	FileAccess.open("res://../evidence/"+label+"-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"walked_world_units":distance_walked,"jump_observations":jump_observations},"\t"))
	print("MILL025 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
