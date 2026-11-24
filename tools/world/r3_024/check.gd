extends SceneTree
const PROVIDER=preload("res://Scripts/World/Zone1/melting_garden_world.gd")
var world
var provider
var store
var checks:=0
var failures: Array=[]
var captures: Array=[]
var rendering:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func ticks(n:=3) -> void:
	for i in n: await physics_frame;await process_frame
func shot(label: String) -> void:
	if not rendering:return
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var path: String=label+"-"+str(root.size.x)+".png"
	check(root.get_texture().get_image().save_png("res://../evidence/"+path)==OK,"capture "+path);captures.append(path)
func close_feedback() -> void:
	if world.input_adapter.modal=="explanation":world.input_adapter._panel_intent("guides.library","explanation_ack",{"view_revision":world.panels.revision})
	elif not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
func aim() -> bool:
	var target=provider.targets.get(provider.FIRST_ID)
	if not is_instance_valid(target):return false
	var emitter=world.input_adapter.emitter
	for radius in [55,65,75,85,95]:
		for step in 32:
			var point: Vector2=target.get_meta("ground_xy")+Vector2.from_angle(step*TAU/32)*radius
			if not world.valid_landing(point) or not world.activate("Z1L1",point):continue
			world.player.set_physics_process(false)
			emitter.facing=(target.global_position-world.player.device_muzzle().global_position).normalized()
			emitter.release();emitter._aim()
			if emitter.selected==target:
				await ticks();return true
	return false
func touch_fire(down: bool) -> void:
	world.input_adapter.refresh()
	world.hud.route_touch(501,world.hud.rects.fire.get_center(),down)
func approach(id: String) -> bool:
	close_feedback()
	for radius in [24,28,32,36]:
		for step in 32:
			var at: Vector2=provider.pieces[id].position+Vector2.from_angle(step*TAU/32)*radius
			if world.valid_landing(at) and world.activate("Z1L1",at) and provider.action_allowed(id):return true
	return false
func context_action(id: String) -> bool:
	if not approach(id):print("NO_APPROACH024 ",id);return false
	world.input_adapter.refresh();await ticks()
	world.input_adapter.refresh()
	var record: Dictionary=world.chunks["Z1L1.shell"].context_record()
	if record.get("key")!="Z1L1:"+id:return false
	var button: Control=world.hud.controls.context
	world.hud.route_touch(601,button.get_global_rect().get_center(),true)
	world.hud.route_touch(601,button.get_global_rect().get_center(),false)
	return true
func help_checks() -> void:
	var key: String=store.instance_id("melting_and_freezing",1,"lesson_melting")+":melting"
	check(store.guide_records().has(key),"free melting Guide available before first target success")
	var before: Dictionary=store.data.duplicate(true)
	world.input_adapter.open_panel("guides");world.input_adapter._open_guide(key);await ticks(15)
	check(is_instance_valid(world.input_adapter.guide_preview),"free Guide opens existing isolated demonstration")
	check(store.data==before and provider._state.legacy.melted[0]<1,"Guide demonstration grants no live progress reward or success popup")
	await shot("free-help")
	world.input_adapter.close_panel();await ticks()
func first_task_checks() -> void:
	provider.set_process(false)
	check(await aim(),"first world barrier has real supported muzzle approach")
	var target=provider.targets[provider.FIRST_ID]
	await shot("ready")
	var before: Dictionary=store.data.duplicate(true)
	check(not store.select_device_mode("cryo") and not store.select_device_mode("vacuum") and not store.select_device_mode("pressure"),"future modes locked")
	check(store.data==before,"rejected mode selection preserves profile")
	for layer in [1,2,8]:
		var body:=StaticBody2D.new();body.collision_layer=layer;body.collision_mask=0
		var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(10,30);shape.shape=box;body.add_child(shape);world.add_child(body)
		var ray: Dictionary=world.world_device_ray(world.player.device_muzzle().global_position,target.global_position,target)
		body.global_position=ray.from.lerp(ray.to,.5);await ticks()
		check(target.geometry_reason(world.player.device_muzzle())=="occluded","world ray blocked by layer "+str(layer))
		touch_fire(true);await create_timer(.12).timeout;touch_fire(false)
		check(target.exposure()==0,"occluded touch Fire adds no heat layer "+str(layer))
		body.free();await ticks()
	# Positive Fire traverses approved HUD -> shared emitter -> native target.
	touch_fire(true);await create_timer(.55).timeout
	check(target.exposure()>0 and provider._state.legacy.melted[0]<1,"real touch hold adds heat before verified outcome")
	await shot("thermal-contact")
	touch_fire(false);var partial: float=target.exposure();await ticks(8)
	check(is_equal_approx(target.exposure(),partial),"release retains unfinished session heat")
	var hash: String=FileAccess.get_sha256(store.save_path)
	before=store.data.duplicate(true);store.fail_commit=true
	touch_fire(true);await create_timer(3.2).timeout;touch_fire(false)
	check(not target.verified_outcome(store,world).is_empty(),"held native exposure verifies outcome")
	check(store.data==before and FileAccess.get_sha256(store.save_path)==hash,"failed outcome rolls back whole profile and disk")
	check(provider.bodies[0].collision_layer!=0 and provider._state.legacy.melted[0]<1 and world.input_adapter.feedback.contains("Barrier stays closed"),"failed write keeps physical and logical barrier closed with retry feedback")
	store.fail_commit=false
	check(provider.commit_target(target),"same verified target retries successfully")
	await ticks()
	check(provider._state.legacy.melted[0]==1 and provider.bodies[0].collision_layer==0,"committed first barrier opens")
	check(provider.bodies[1].collision_layer!=0 and provider.bodies[2].collision_layer!=0,"fan and mirror barriers remain closed")
	check(store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1"],"only correct checkpoint unlocks")
	check(store.data.extras.solved_puzzle_ids.get("melting_and_freezing:1:puzzle0")=="melt_direct","original first puzzle identity and explanation reused")
	check(store.data.extras.independent_phase_evidence.size()==1 and store.data.active_run.state.device_outcomes.size()==1,"one scientific receipt")
	check(world.input_adapter.modal=="explanation","first success explanation follows committed melt")
	await shot("first-success")
	before=store.data.duplicate(true)
	check(not provider.commit_target(target) and store.data==before,"duplicate callback creates no award or popup")
	close_feedback();await ticks()
	check(store.pending_explanations().is_empty(),"explicit acknowledgment consumes explanation once")
	await shot("crossing-open")
	# No target exists for environmental gates. Border checks remain source-owned.
	check(get_nodes_in_group("phase_device_targets").size()==1,"fan and mirror never opt into device targeting")
	var destination: Vector2=world.REGISTRY.local_to_ground("Z1L2",Vector2.ZERO)
	check(not world.world_contact_allowed(world.player.position,destination),"device contact cannot cross locked subregion border")
	check(not provider.completion_authorized() and not store.is_level_complete("melting_and_freezing",1),"first thaw cannot invent full route completion")
func environmental_checks() -> void:
	check(provider.pieces.has("wood") and provider.pieces.has("blades") and provider.pieces.has("mirror3"),"independent fuel fan and three mirrors retained")
	provider._environmental(12)
	check(provider._state.legacy.melted[1]==0 and provider._state.legacy.melted[2]==0,"unprepared machines gain no heat")
	check(await context_action("wood") and world.player.carrying,"real contextual touch carries unique fuel")
	check(approach("brazier1"),"carried fuel has clear supported placement approach")
	var before: Dictionary=store.data.duplicate(true);var hash: String=FileAccess.get_sha256(store.save_path)
	store.fail_commit=true
	check(not provider.commit_action("brazier1") and store.data==before and FileAccess.get_sha256(store.save_path)==hash and world.player.carrying,"failed fuel placement retains one carried part and disk")
	store.fail_commit=false
	check(await context_action("brazier1") and provider._state.legacy.lit[1] and not world.player.carrying,"touch places fuel without module obligation")
	provider._environmental(12)
	check(provider._state.legacy.melted[1]==0 and provider.bodies[1].collision_layer!=0,"fueled heater still requires repaired fan")
	check(await context_action("blades") and world.player.carrying,"touch carries fan blades")
	check(await context_action("vent") and provider._state.legacy.fan_installed and not world.player.carrying,"touch installs same fan blades")
	store.fail_commit=true;before=store.data.duplicate(true)
	provider._environmental(4)
	check(store.data==before and provider.bodies[1].collision_layer!=0,"failed fan thaw transaction keeps crossing closed")
	store.fail_commit=false;provider._environmental(.01)
	check(provider._state.legacy.melted[1]==1 and provider.bodies[1].collision_layer==0,"fuel plus repaired fan commits environmental thaw")
	check(provider._state.legacy.melted[2]==0 and provider.bodies[2].collision_layer!=0,"fan success cannot open mirror barrier")
	close_feedback();await shot("fan-preserved")
	for id in ["mirror","mirror2","mirror3"]:
		check(approach(id),"mirror has supported contextual approach "+id)
		var index: int=["mirror","mirror2","mirror3"].find(id)
		var end: Vector2=provider.pieces[["mirror2","mirror3","receiver"][index]].position+Vector2(0,-26 if index==2 else -42)
		var direction: Vector2=(provider.pieces[id].position+Vector2(0,-42)).direction_to(end)
		var desired:=0;var score:=-INF
		for d in range(8):
			var dot: float=Vector2(sin(d*PI/4),cos(d*PI/4)*.5).normalized().dot(direction)
			if dot>score:score=dot;desired=d
		for turn in range(8):
			var actual: int=([provider._state.legacy.mirror]+provider._state.legacy.relays)[index]
			if actual==desired:break
			check(provider.commit_action(id),"context rotates preserved mirror "+id)
	check(provider._mirror_aligned(),"authored three-link geometric relay aligns")
	provider._environmental(3);provider._environmental(8)
	check(provider._state.legacy.receiver_lit and provider._state.legacy.melted[2]==1,"aligned mirror charge then receiver heat retains original timing contract")
	check(store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1","C2","C3"],"environmental successes retain checkpoint order")
	for i in range(4):
		await ticks();close_feedback()
	check(provider.pieces.keys().filter(func(id):return id.begins_with("crystal")).size()==6,"all six independent crystal stations retained")
	check(not store.is_level_complete("melting_and_freezing",1),"isolated machine checks do not certify full route")
func migration_checks() -> void:
	close_feedback()
	var base: Dictionary=provider._state.legacy.duplicate(true)
	base.melted=[.6,0.0,0.0];base.lit=[true,false,true];base.module_state="docked";base.erase("legacy_first_heat");base.erase("device_retrofit_version")
	base.wood=true;base.carry_item="wood";base.collected={0:true,3:true};base.mirror=4;base.relays=[2,5];base.future_record={"keep":[1,2,3]}
	var earned: Dictionary=store.data.extras.duplicate(true)
	var attempt: String=store.data.active_run.attempt_id
	store.data.active_run.attempt_id="migration-024"
	store.data.active_run.state={"current":base.duplicate(true),"checkpoint":base.duplicate(true),"checkpoint_progress":{"version":1,"unlock_sequence":["C0"],"latest_unlocked_checkpoint_id":"C0"}}
	world.player.get_node("CarriedModule").hide() # Fresh actor's initial visibility before cold restore.
	provider._restored();await ticks()
	check(provider._state.legacy.legacy_first_heat==.6 and is_equal_approx(provider.targets[provider.FIRST_ID].definition().required_exposure,1.2),"legacy partial heat credits remaining 1.2 seconds")
	check(provider._state.legacy.collected==base.collected and provider._state.legacy.relays==base.relays and provider._state.legacy.future_record==base.future_record,"legacy collectibles mirrors and unknown fields retained")
	check(world.player.carrying and provider._held.is_visible_in_tree() and provider._held.get_meta("unique_item_id")=="wood" and not provider.pieces.wood.visible,"carried fuel restores immediately visible as exactly one held item")
	check(not world.player.request_jump(),"carried fuel blocks Jump")
	check(not world.input_adapter.emitter.available(),"carried fuel blocks Fire")
	check(store.update_run_with_events(provider.snapshot(),[],[],world),"migrated snapshot persists")
	var once: Dictionary=store.data.duplicate(true)
	provider._restored();await ticks()
	check(store.data==once and provider._state.legacy.legacy_first_heat==.6,"second migration idempotent without awards")
	check(store.save_profile(),"migration writes backed-up disk fixture")
	store.load_profile();provider.refresh_binding();await ticks()
	check(provider._state.legacy.legacy_first_heat==.6 and world.player.carrying,"disk reload retains credit and unique item")
	await shot("legacy-partial")
	var module:=base.duplicate(true);module.carry_item="module";module.module_state="carried";module.wood=false
	store.data.active_run.state={"current":module,"checkpoint":module.duplicate(true)}
	provider._restored();await ticks()
	check(not world.player.carrying and provider._state.legacy.carry_item=="" and provider._state.legacy.collected==base.collected,"retired module frees hands without losing earned items")
	var dual:=base.duplicate(true);dual.expedition_version=1;dual.erase("carry_item");dual.wood=true;dual.blades=true;dual.fan_installed=false
	store.data.active_run.state={"current":dual,"checkpoint":dual.duplicate(true)}
	provider._restored();await ticks()
	check(provider._state.legacy.carry_item=="wood" and not provider._state.legacy.blades and provider.pieces.blades.visible,"pre-carry dual supplies restore one carried fuel and recoverable fan blades")
	check(provider._state.legacy_original.blades==true,"exact pre-migration inventory retained in additive source snapshot")
	check(store.update_run_with_events(provider.snapshot(),[],[],world),"dual-supply migration persists")
	provider._restored();await ticks()
	check(world.player.carrying and provider.pieces.blades.visible and not provider._state.legacy.blades,"dual-supply migration cannot duplicate or strand either supply on repeat")
	var complete:=base.duplicate(true);complete.melted=[1.0,1.0,1.0];complete.carry_item="";complete.lit=[true,true,true];complete.blades=true;complete.fan_installed=true;complete.receiver_lit=true;complete.collected={0:true,1:true,2:true,3:true,4:true,5:true}
	store.data.completed["melting_and_freezing:1"]=true
	store.data.active_run.state={"current":complete,"checkpoint":complete.duplicate(true)}
	provider._restored();await ticks()
	check(provider.targets.is_empty() and store.is_level_complete("melting_and_freezing",1),"completed legacy L1 stays completed without target replay")
	check(provider._state.legacy.collected.size()==6 and provider.bodies.all(func(body):return body.collision_layer==0),"completed crystals and three barriers preserved")
	check(store.pending_explanations().is_empty(),"migration queues no repeated success popup")
	var intro: Variant=store.data.extras.get("thermal_introduction_version")
	store.data.extras.erase("thermal_introduction_version");provider._process(0)
	check(world.input_adapter.modal.is_empty(),"old completed L1 without retrofit marker never replays welcome")
	store.data.extras.thermal_introduction_version=intro
	for key in ["achievement_unlocks","achievement_progress","achievement_toasts","solved_puzzle_ids","explained_puzzle_types","independent_phase_evidence"]:
		check(store.data.extras.get(key)==earned.get(key),"migration retains earned "+key)
	await shot("legacy-complete")
	store.data.active_run.state={};provider._restored();provider._process(0);await ticks()
	check(provider.targets.is_empty() and provider._state.legacy.collected.size()==6 and provider._state.legacy.get("completion_only_recovery")==true and world.input_adapter.modal.is_empty() and store.total_stars()==1 and store.pending_explanations().is_empty(),"completion-only old profile recovers solved garden without replay awards or welcome")
	var future: Dictionary=provider._state.duplicate(true);future.version=99
	store.data.active_run.state[provider.STATE_KEY]=future
	var before: Dictionary=store.data.duplicate(true);provider._restored()
	check(provider._state.is_empty() and not provider.commit_action("wood") and store.data==before,"unsupported future provider record retained with writes disabled")
	store.data.active_run.attempt_id=attempt
func run() -> void:
	root.size=Vector2i(640,360) if "--compact" in OS.get_cmdline_user_args() else Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await ticks()
	store=root.get_node("PlayerSave")
	check(store.enter_world_subregion(world,"Z1L1"),"fresh authored world attempt")
	provider=PROVIDER.new();world.chunks["Z1L1.shell"].add_child(provider)
	check(provider.bind_garden(world),"garden provider binds existing independent world pieces")
	if provider.world!=null:
		check(provider.active(),"exact active subregion/attempt authority")
		var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://cube-inventory.json"))
		var components: Array=[]
		for id in provider.pieces:
			var piece=provider.pieces[id]
			var asset: String=piece.get_meta("asset_id","")
			if asset.is_empty():continue
			var matches: Array=inventory.existing_modules.filter(func(entry):return entry.id==asset)
			check(matches.size()==1,"existing measured cube envelope for independent "+id)
			if not matches.is_empty():components.append({"id":id,"ground_xy":piece.position,"elevation":piece.elevation,"footprint_cubes":matches[0].ground_envelope_cubes,"height_layers":matches[0].height_envelope_layers,"pivot_px":matches[0].pivot_px,"scale":matches[0].world_scale,"legacy_collision_source":"Actors/"+id+"/CollisionBody","source_inventory":matches[0]})
		FileAccess.open("res://../evidence/assembly-contract.json",FileAccess.WRITE).store_string(JSON.stringify({"cube_unit_px":20,"cap_px":[40,20],"components":components,"contract":"Existing independent world contributors, exact fractional legacy XY, original physical bounds and actual terrain support. Cube envelopes describe placement; never create collision/support from textures. Outdoor worksite; existing indoor cutaways unaffected."},"\t"))
		await ticks()
		check(world.input_adapter.modal=="lesson","fresh Professor lesson precedes target")
		check(not store.has_device_capability("melting") and store.data.extras.get("solved_puzzle_ids",{}).is_empty(),"unacknowledged lesson invents no access or success")
		await shot("professor-introduction")
		var before: Dictionary=store.data.duplicate(true)
		store.fail_commit=true
		world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
		check(store.data==before,"failed introductory grant rolls back entire profile")
		await ticks();check(world.input_adapter.modal=="lesson","failed introduction remains retryable")
		store.fail_commit=false
		world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
		await ticks()
		check(store.has_device_capability("melting"),"guided access granted before task")
		check(provider.targets.size()==1,"only direct barrier registered")
		await help_checks()
		await first_task_checks()
		await environmental_checks()
		await migration_checks()
	check(world.REGISTRY.READY_CHUNKS.is_empty(),"normal readiness remains gated")
	FileAccess.open("res://../evidence/"+(("render-compact-results.json" if root.size.x==640 else "render-results.json") if rendering else "check-results.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures},"\t"))
	print("GARDEN024 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
