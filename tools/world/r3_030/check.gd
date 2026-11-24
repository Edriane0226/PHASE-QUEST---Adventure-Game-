extends SceneTree

const DRIVER = preload("res://touch_route.gd")
const EVIDENCE := "res://../../../output/world/r3-prompt030/evidence/"
const CONNECTED := "res://World/Navigation/ConnectedWorld.tscn"
var world: Node2D
var t: RefCounted
var profile: Node
var label := "check"
var arrivals: Array[String] = []
var retained: Array[int] = []
var resume_after := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name in ["garden","migration","restore","render"]:
		if "--"+name in OS.get_cmdline_user_args():label=name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resume-after="):resume_after=arg.trim_prefix("--resume-after=").to_int()
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(640,360) if compact else Vector2i(960,540)
	root.content_scale_size=root.size
	change_scene_to_file(CONNECTED)
	await scene_changed
	world=current_scene
	profile=root.get_node("PlayerSave")
	t=DRIVER.new(self,world)
	t.rendering=label=="render"
	if t.rendering:
		root.grab_focus()
	await t.ticks(6)
	world.subregion_changed.connect(func(id):arrivals.append(id))
	retained=[world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]
	if label=="migration":
		await load("res://migration.gd").new().verify(t)
	elif label=="render" and resume_after>0:
		check_shared(world.active_subregion_id)
		t.check(world.active_subregion_id=="Z1L%d"%resume_after and profile.total_stars()==resume_after,"render earned active district")
		if resume_after in [1,2]:
			t.check(world.active_chunk().tutorial.begins_with("Follow the trail"),"completed district HUD points onward")
		await shot("earned-l%d"%resume_after)
	elif label in ["restore","render"]:
		await restored()
	elif t.check(world.last_error.is_empty() and world.learning_provider()!=null,"six authored providers mounted"):
		var okay: bool=await garden() if resume_after==0 else t.check(profile.total_stars()==resume_after,"resume previously earned prefix")
		t.check(okay,"Garden route or its earned save is available")
		if okay and resume_after==1 and world.player.position.distance_to(profile.WORLD_SAVE.anchor("Z1L1","C3"))<20:
			var p:=provider()
			var jump: Dictionary=p._jumps[1]
			okay=await t.jump(p.chunk.ground_origin+world.models[0].v(jump.from),(world.models[0].v(jump.toward)-world.models[0].v(jump.from)).normalized())
		if okay and resume_after==2 and world.player.position.distance_to(provider().points.exit)>90:
			okay=t.check(await t.go(provider().points.MillCrankRecovery+Vector2(-36,14)),"resume across Mill walkback to the exit fork")
		if okay and label=="check":
			for i in range(maxi(2,resume_after+1),7):
				var from:="Z1L%d"%(i-1)
				var to:="Z1L%d"%i
				if not await t.boundary(from,to):break
				await t.ticks()
				print("ENTER030 ",to," at ",world.player.position)
				if not t.check(world.learning_provider()!=null and world.learning_provider().active(),"active attempt on "+to):break
				var stages: Array[Callable]=[mill,stillwater,canal,workshop,dock]
				if not await stages[i-2].call():break
			t.check(profile.total_stars()==6 and world.active_subregion_id=="Z2L1","six earned completions and geographic arrival")
			if t.failures.is_empty():
				t.check(DirAccess.copy_absolute(profile.save_path,"res://../fixtures/restore.save")==OK,"save completed binary route for cold restore")
	report()

func provider() -> Node:
	return world.learning_provider()

func use(id: String,point: Vector2) -> bool:
	return await t.interact(id,point)

func shot(name: String) -> void:
	if not t.rendering:return
	await t.ticks(3)
	await RenderingServer.frame_post_draw
	t.check(root.get_texture().get_image().save_png(EVIDENCE+name+"-"+str(root.size.x)+".png")==OK,"capture "+name)

func check_shared(id: String) -> void:
	t.check(retained==[world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()],"same player, HUD and camera "+id)
	var zone:=int(id.substr(1,1))
	t.check(world.professors[zone-1].visuals.get_child(0).cast_id=="professor_z%d"%zone,"correct Professor provider for "+id)
	t.check(not profile.is_device_mode_unlocked("vacuum") and not profile.is_device_mode_unlocked("pressure"),"future modes locked "+id)
	t.check(world.hud.minimap.visible and not world.hud.controls.has("map") and world.hud.rects.has("cryo"),"approved HUD slots and minimap "+id)

func finish_count(level: int) -> bool:
	check_shared(world.active_subregion_id)
	var okay: bool=t.check(profile.total_stars()==level and profile.is_level_complete(profile.ZONES[0],level),"one completion each through L%d"%level)
	if okay:
		print("CHECKPOINT030 completed L",level," walked=",t.walked)
		DirAccess.copy_absolute(profile.save_path,"res://../fixtures/after-l%d.save"%level)
	return okay

func garden() -> bool:
	var p:=provider()
	t.check(profile.total_stars()==0 and profile.device_state().unlocked_modes.is_empty(),"fresh profile has no completion or device access")
	t.check(not world.access.allowed("Z1L2") and not p.finish(),"Garden exit and Mill closed before work")
	if not t.check(world.input_adapter.modal=="lesson","first Professor lesson opens before device task"):return false
	if not t.check(await t.press("lesson_ack"),"tap Professor lesson acknowledgement"):return false
	if not t.check(profile.is_device_mode_unlocked("thermal") and profile.has_device_capability("melting") and not profile.is_device_mode_unlocked("cryo"),"guided Thermal comes before Fire"):return false
	if not await t.mode("thermal"):return false
	if not await crystal(p,0):return false
	var first: Dictionary=p._jumps[0]
	var takeoff: Vector2=p.chunk.ground_origin+world.models[0].v(first.from)
	var toward: Vector2=world.models[0].v(first.toward)-world.models[0].v(first.from)
	if not await t.jump(takeoff,toward.normalized()):return false
	t.check(p._state.legacy.get("traversal_completed",{}).get(first.id,false),"authored J1 jump recorded")
	if not await crystal(p,1) or not await t.expose(p.FIRST_ID):return false
	await t.acknowledge()
	t.check(profile.achievement_state().unlocks.has("first_thaw") and p.snapshot().checkpoint_progress.latest_unlocked_checkpoint_id=="C1","first melt earns badge and C1")
	if not t.check(await t.bridge(Vector2(2600,1320),Vector2(2720,1380)),"walk thawed first bridge along authored diagonal"):return false
	if not await crystal(p,2) or not await use("wood",p.pieces.wood.position):return false
	t.check(world.player.carrying and p._state.legacy.carry_item=="wood","carry one dry wood")
	if not await t.continue_from_disk():return false
	t.check(world.player.carrying and p._held.get_meta("unique_item_id")=="wood","Continue preserves held wood")
	if not await use("brazier1",p.pieces.brazier1.position):return false
	t.check(p._state.legacy.melted[1]<1 and p._state.legacy.melted[2]<1 and world.input_adapter.emitter.selected==null,"fuel alone and Thermal cannot bypass separate machines")
	if not await use("blades",p.pieces.blades.position) or not await use("vent",p.pieces.vent.position):return false
	await t.wait(4.2)
	await t.acknowledge()
	if not t.check(p._state.legacy.melted[1]==1.0,"installed fan and fuel thaw second gate"):return false
	if not await crystal(p,3):return false
	if not t.check(await t.bridge(Vector2(2720,2220),Vector2(2600,2280)),"walk fan-heated bridge along authored diagonal"):return false
	if not await crystal(p,4) or not await crystal(p,5):return false
	var desired := [7,4,3]
	var mirrors := ["mirror","mirror2","mirror3"]
	for index in range(3):
		var angle: int=p._state.legacy.mirror if index==0 else p._state.legacy.relays[index-1]
		var id: String=mirrors[index]
		for turn in range(posmod(desired[index]-angle,8)):
			if not await use(id,p.pieces[id].position):return false
	await t.wait(11.3)
	await t.acknowledge()
	t.check(p._state.legacy.melted==[1.0,1.0,1.0] and p._state.legacy.collected.size()==6,"all three distinct thaws and six unique crystals")
	t.check(profile.achievement_state().unlocks.has("pocket_scientist"),"six crystal badge earned")
	if not t.check(await t.bridge(Vector2(1880,2320),Vector2(1680,2220)),"walk mirror-heated bridge along authored diagonal"):return false
	var second: Dictionary=p._jumps[1]
	takeoff=p.chunk.ground_origin+world.models[0].v(second.from)
	toward=world.models[0].v(second.toward)-world.models[0].v(second.from)
	if not await t.jump(takeoff,toward.normalized()):return false
	t.check(p._state.legacy.get("traversal_completed",{}).get(second.id,false),"authored J2 jump recorded")
	if not await use("exit",p.pieces.exit.position):return false
	return finish_count(1)

func crystal(p: Node,index: int) -> bool:
	var id:="crystal%d"%index
	for step in range(2):
		if not await use(id,p.pieces[id].position):return false
		if step==0:await t.wait(2.6)
	return t.check(p._state.legacy.collected.get(index)==true,"one crystal "+str(index)+" collected from its frost shell")

func mill() -> bool:
	var p:=provider()
	t.check(not p.finish() and not world.access.allowed("Z1L3") and not profile.is_device_mode_unlocked("cryo"),"Mill starts with its exit, Cryo and Stillwater locked")
	for id in p.BELLS:
		if not await use(id,p.points[id]):return false
	await t.wait(3.2)
	await t.acknowledge()
	if not t.check(p._state.legacy.clear,"bells fracture ice without science receipt"):return false
	t.check(profile.data.active_run.state.get("device_outcomes",{}).is_empty(),"mechanical bells add no phase outcome")
	for id in p.PARTS:
		if not await t.expose("mill_"+id+"_casing"):return false
		if not await use("runtime_"+id,p.points["runtime_"+id]):return false
		if id==p.PARTS[0]:
			var wrong: String="runtime_tray_"+p.PARTS[1]
			if not await use(wrong,p.points[wrong]):return false
			t.check(world.player.carrying and p._state.legacy.workshop_held==0,"wrong tray retains exact metal part")
			if not await t.continue_from_disk():return false
		if not await use("runtime_tray_"+id,p.points["runtime_tray_"+id]):return false
	await t.acknowledge()
	t.check(p._state.legacy.workshop_parts==[2,2,2] and p.snapshot().checkpoint=="C2","three matching parts attune C2")
	var at: Vector2=p.chunk.ground_origin+world.models[0].v(p._jump.from)
	var direction: Vector2=(world.models[0].v(p._jump.toward)-world.models[0].v(p._jump.from)).normalized()
	if not await t.jump(at,direction) or not t.check(p._state.legacy.get("jump_records",{}).get("z1_l2_j2",false),"ordinary jump earns maintenance crossing"):return false
	for id in ["ReflectorA","ReflectorB","ReflectorB"]:
		if not await use(id,p.points[id]):return false
	await t.wait(3.2)
	await t.acknowledge()
	for id in ["WalkbackLever","MillCrankRecovery","CrankSocket"]:
		if not await use(id,p.points[id]):return false
	if not t.check(await t.go(p.points.MillCrankRecovery+Vector2(-36,14)),"walk back through the earned freight landing to the exit fork"):return false
	if not await use("exit",p.points.exit):return false
	return finish_count(2)

func stillwater() -> bool:
	var p:=provider()
	if not profile.is_device_mode_unlocked("cryo"):
		t.check(not profile.has_device_capability("freezing"),"freezing locked on Stillwater arrival")
		if not await use("professor",p.points.professor) or not await t.press("lesson_ack"):return false
	t.check(profile.is_device_mode_unlocked("cryo") and not profile.has_device_capability("freezing"),"lesson enables use before verified freezing")
	if not await t.mode("cryo") or not await t.expose("first_ice"):return false
	t.check(profile.has_device_capability("freezing"),"filled first tray verifies freezing")
	if not await t.mode("thermal") or not await t.expose("melt_supply") or not await use("valve",p.points.valve):return false
	if not await use("heater",p.points.heater) or not await t.mode("cryo"):return false
	for id in ["left_ice","right_ice"]:
		if not await t.expose(id):return false
	if not await use("latch",p.points.latch):return false
	var at: Vector2=p.points.court3+Vector2(-56,0)
	if not await t.jump(at,Vector2.RIGHT):return false
	await t.acknowledge()
	if not t.check(p._state.crossed,"ordinary jump crosses latched trays"):return false
	if not await use("exit",p.points.exit):return false
	return finish_count(3)

func modular(id: String) -> bool:
	var p:=provider()
	var spec: Dictionary=p.contract.actions.get(id,{})
	var at: Vector2=p.points.exit if id=="exit" else p.component(spec.component).position
	return await use(id,at)

func canal() -> bool:
	var p:=provider()
	if not await t.mode("thermal") or not await t.expose("thaw_intake"):return false
	for id in ["divert","isolate"]:
		if not await modular(id):return false
	if not await t.mode("cryo") or not await t.expose("freeze_side"):return false
	if not await modular("drive") or not await t.mode("thermal") or not await t.expose("thaw_lock"):return false
	for id in ["pickup","seat"]:
		if not await modular(id):return false
	if not await t.mode("cryo") or not await t.expose("refreeze_lock"):return false
	for id in ["latch","release","exit"]:
		if not await modular(id):return false
	t.check(p._state.components["wheel_channel/main"].phase=="liquid","Canal main channel remains liquid")
	return finish_count(4)

func workshop() -> bool:
	var p:=provider()
	for id in ["mirror_a","mirror_b","mirror_b","mirror_b"]:
		if not await modular(id):return false
	await t.wait(3.3)
	for id in ["open","walkback","fill"]:
		if not await modular(id):return false
	if not await t.mode("cryo") or not await t.expose("freeze_jig"):return false
	for id in ["take","fit"]:
		if not await modular(id):return false
	if not await t.mode("thermal") or not await t.expose("melt_jig"):return false
	for id in ["drain","retrieve","stow","draft","exit"]:
		if not await modular(id):return false
	t.check(p.boat_blueprint_unlocked(profile.data),"Workshop independently saves actual blueprint")
	return finish_count(5)

func dock() -> bool:
	var p:=provider()
	if not await modular("ramp") or not await t.mode("thermal"):return false
	for id in p.PARTS.PLANKS:
		if not await t.expose("thaw_"+id) or not await modular("take_"+id) or not await modular("rack_"+id):return false
	if not await modular("fill_walkway") or not await t.mode("cryo") or not await t.expose("freeze_walkway"):return false
	if not await modular("latch_walkway"):return false
	for id in ["rope","sailcloth"]:
		if not await modular("take_"+id) or not await modular("rack_"+id):return false
	if not await modular("isolate_heat") or not await t.mode("thermal") or not await t.expose("thaw_rudder"):return false
	for id in ["take_rudder","rack_rudder","fill_jig"]:
		if not await modular(id):return false
	if not await t.mode("cryo") or not await t.expose("freeze_jig") or not await modular("recipe"):return false
	if not await t.press("assemble") or not await t.mode("thermal") or not await t.expose("release_jig"):return false
	if not await modular("test"):return false
	await t.wait(1.6)
	await t.acknowledge()
	t.check(not world.access.allowed("Z2L1"),"tested hull alone keeps destination locked")
	if not await use("finn",p.points.finn):return false
	for choice in ["1","0","2"]:
		if not await t.panel_button(world.panels.choices.get(choice)) or not await t.press("submit") or not await t.press("next_question"):return false
	t.check(p.finn.passed(p._state.finn) and not world.access.allowed("Z2L1"),"Finn passes before boarding without granting access")
	if not await t.panel_button(world.panels.close_button):return false
	if not await modular("exit"):return false
	await t.wait(2.3)
	t.check(world.active_subregion_id=="Z2L1" and profile.active_world_zone()==profile.ZONES[1],"Zone 2 arrival commits via boat")
	return finish_count(6)

func restored() -> void:
	t.check(profile.total_stars()==6 and world.active_subregion_id=="Z2L1","cold process restores completed route and landing")
	t.check(world.can_transit("Z1L6--Z2L1",true),"cold return boat is available")
	t.check(world.REGISTRY.READY_CHUNKS.is_empty(),"normal release gate remains pending")
	check_shared("Z2L1")
	var unlocks: Dictionary=profile.achievement_state().unlocks
	t.check(["first_thaw","helping_breeze","follow_light","hands_on","pocket_scientist","boatwright","snow_scholar","clear_explanation"].all(func(id):return unlocks.has(id)),"earned Garden and Dock badges survive cold Continue")
	var changes: Dictionary={}
	for receipt in profile.data.extras.get("independent_phase_evidence",{}).values():
		changes[receipt.process]=true
	t.check(changes.size()==2 and changes.has("melting") and changes.has("freezing") and not profile.has_device_capability("vaporization"),"only Zone 1 phase evidence is earned")
	t.check(profile.pending_explanations().is_empty(),"acknowledged first-success help stays closed after relaunch")
	await shot("sunlit-arrival")
	var record: Dictionary=world.active_chunk().context_record()
	if not t.check(record.get("key")=="Z1L6--Z2L1.return" and record.get("enabled"),"return is offered at the arrival dock"):return
	world.input_adapter.refresh()
	t.tap(world.hud.controls.context.get_global_rect().get_center())
	await t.wait(2.3)
	var dock_provider:=provider()
	if not t.check(world.active_subregion_id=="Z1L6" and profile.total_stars()==6 and dock_provider!=null,"touch return boat brings player back with six stars"):return
	t.check(dock_provider.boat_earned() and dock_provider._state.items.values().count(dock_provider.FITTED)==6,"cold return restores the same finished local boat")
	await shot("dock-return")

func report() -> void:
	var report_label:=label if resume_after==0 else label+"-from-l%d"%resume_after
	var file:=FileAccess.open(EVIDENCE+report_label+"-results.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":t.checks,"failures":t.failures,"walked_world_units":t.walked,"arrivals":arrivals,"explanations":t.feedback,"resume_after":resume_after},"\t"))
	print("ZONE030 ","PASS" if t.failures.is_empty() else "FAILED"," checks=",t.checks," failures=",t.failures.size()," walked=",t.walked)
	quit(0 if t.failures.is_empty() else 1)
