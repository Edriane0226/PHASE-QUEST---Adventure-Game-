extends SceneTree
const FIXTURE=preload("res://fixtures.gd")
const ADAPTER=preload("res://Scripts/World/Learning/subregion_adapter.gd")
const HOST=preload("res://Scripts/World/Navigation/connected_world.gd")
const RULES=preload("res://Scripts/Content/phase_transition_rules.gd")
const DEVICE=preload("res://Scripts/Content/phase_device_progress.gd")
const CONTENT=preload("res://Scripts/World/Learning/professor_content.gd")
var checks:=0
var failures: Array=[]
var world: Node
var provider: Node
var store: Node
var observations: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	store=root.get_node("PlayerSave");store.set_completed_prefix(4);store.adapter_tests=true
	check(world.room_cutaway.rooms.size()==3,"one room instance per authored chunk after shared base service composition")
	var room=world.room_cutaway.rooms[0];var origin: Vector2=room.point(Vector2(1,1))
	check(world.activate("Z1L5",room.point(Vector2(6.5,5.8))),"fixture enters workshop on actual stacked floor")
	check(store.enter_world_subregion(world,"Z1L5"),"disposable stable attempt")
	provider=FIXTURE.mount(world,FIXTURE.definition(origin))
	check(provider!=null,"representative modular provider binds")
	if provider:
		check(provider.active(),"provider bound to exact chunk/attempt")
		check(provider.assemblies.work.parts.size()==10,"ten independent components")
		check(provider.targets.size()==1,"native target registers only active provider")
		await rejection_checks(origin)
		await assembly_checks(room)
		await introduction_checks()
		content_checks()
	check(world.REGISTRY.READY_CHUNKS.is_empty(),"normal readiness remains empty")
	FileAccess.open("res://../evidence/check-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"observations":observations,"scope":"Isolated real writer/native science/actor/HUD/world physics. No production providers or mastery fixture writes to real profiles."},"\t"))
	print("ADAPTER023 ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func settle() -> void:await physics_frame;await process_frame
func close_feedback() -> void:
	if world.input_adapter.modal=="explanation":
		world.input_adapter._panel_intent("guides.library","explanation_ack",{"view_revision":world.panels.revision})
	elif not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
func stand(at: Vector2) -> bool:
	var okay: bool=world.activate(provider.subregion_id,at)
	if okay:provider.refresh_binding()
	return okay
func approach(action: String) -> Vector2:
	var anchor=provider.component(provider.contract.actions[action].component)
	var key: String=provider.contract.actions[action].component
	var assembly=provider.assemblies[key.get_slice("/",0)]
	for offset in [Vector2(-10,15),Vector2(0,27),Vector2(33,0),Vector2(-33,0),Vector2(0,-27),Vector2(40,25),Vector2(-40,25)]:
		if assembly.contains_interaction(key.get_slice("/",1),anchor.position+offset) and world.valid_landing(anchor.position+offset):return anchor.position+offset
	return Vector2(INF,INF)
func invoke(action: String) -> bool:
	var point:=approach(action)
	if not point.is_finite():print("NO_APPROACH ",action);return false
	if not stand(point):print("NO_STAND ",action," ",point);return false
	var okay: bool=provider.commit_action(action)
	if not okay:print("ACTION_DEBUG ",action," at=",point," active=",provider.active()," canwrite=",provider._can_write()," allowed=",provider.action_allowed(action)," modal=",world.input_adapter.modal," state=",provider._state," error=",provider.last_error)
	return okay
func walk(point: Vector2) -> bool:
	if not point.is_finite():return false
	for tick in range(300):
		var delta: Vector2=point-world.player.position
		if delta.length()<4:world.player.set_touch_movement(Vector2.ZERO);return true
		world.player.set_touch_movement(delta.normalized()*minf(1,delta.length()/12));await physics_frame
	world.player.set_touch_movement(Vector2.ZERO);return false
func assembly_checks(room: Node) -> void:
	var initial: Dictionary=store.data.duplicate(true)
	var target=provider.targets["review-water"]
	check(target.targeting_reason(world,store)=="prerequisite_missing","native target blocks unopened apparatus")
	check(not provider.finish() and not store.finish_level(world.SAVE_ZONE,world.SAVE_LEVEL,[],world),"location/provider presence cannot complete")
	check(not provider.introduce("z1l1_melting"),"wrong subregion cannot introduce capability")
	var asm=provider.assemblies.work
	for id in asm.parts:
		check(asm.parts[id].get_meta("component_id")==id,"stable independent component "+id)
		check(is_equal_approx(asm.parts[id].visuals.position.y,-asm.parts[id].elevation),"ground-pivot visual elevation "+id)
	check(asm.parts.sample.elevation==room.elevation+6,"sample effect height distinct from support")
	check(asm.interactions.control.size()==4 and asm.support_bounds.control.is_empty() and asm.bodies.has("control"),"separate interaction/support/collision bounds")
	for body in asm.bodies.values():
		var layer: int=body.collision_layer;asm.parts.control.hide();check(body.collision_layer==layer,"render hiding cannot disable solid collision")
	provider.present()
	var point:=approach("power");check(point.is_finite() and stand(point),"control has clear full-foot touch access")
	store.fail_commit=true;var hash:=FileAccess.get_sha256(store.save_path)
	check(not provider.commit_action("power") and store.data==initial and FileAccess.get_sha256(store.save_path)==hash,"failed control save atomically rolls snapshot/disk back")
	check(not provider._state.components["work/control"].enabled,"failed save leaves independent control art/state unchanged")
	store.fail_commit=false
	var proof_before: Dictionary=store.data.extras.get("independent_phase_evidence",{}).duplicate(true)
	check(provider.discover("melting","review-reference"),"free Guide discovery uses existing learning service")
	check(store.data.extras.get("independent_phase_evidence",{})==proof_before,"Guide discovery grants no independent mastery")
	var guide_key: String=store.instance_id(world.SAVE_ZONE,world.SAVE_LEVEL,"review-reference")+":melting"
	var before_demo: Dictionary=store.data.duplicate(true)
	world.input_adapter.open_panel("guides");world.input_adapter._open_guide(guide_key)
	await settle()
	check(is_instance_valid(world.input_adapter.guide_preview),"existing isolated Guide demonstration view opens")
	world.input_adapter.guide_preview.replay();world.input_adapter.guide_preview.toggle_playback();await settle()
	check(store.data==before_demo and provider._state.components["work/sample"].phase=="solid","Guide replay/preview changes neither live puzzle nor feedback queues")
	world.input_adapter.close_panel();await settle()
	check(invoke("power"),"context control commits independently")
	check(provider._state.components["work/control"].enabled and provider._state.components["work/sample"].phase=="solid" and not provider._state.components["work/pipe"].open,"control changes no sample/pipe/mastery")
	check(not store.data.extras.get("independent_phase_evidence",{}).has("melting_and_freezing:5:review-water"),"art/control action grants no science receipt")
	check(invoke("flow"),"pipe state changes independently")
	check(target.targeting_reason(world,store).is_empty(),"native target unlocks only after authored apparatus flags")
	check(store.select_device_mode("cryo"),"previously learned Cryo remains one of four actual modes")
	check(target.targeting_reason(world,store)=="unsupported_mode" and not store.select_device_mode("plasma"),"wrong mode/fifth mode cannot solve this authored transition")
	store.select_device_mode("thermal")
	var partial: Dictionary=target.apply_exposure(.02,world.player.device_muzzle(),provider.sample_for("review-water"),provider.flags_for("review-water"),true)
	check(not partial.get("new_outcome",false) and target.exposure()>0,"unfinished native exposure exists only within this live instance")
	provider._restored();check(not target.belongs_to(world,store),"restoration invalidates stale target instance")
	target=provider.targets["review-water"];check(target.exposure()==0,"restore resets unfinished exposure without manufacturing receipt")
	var touch_context: Dictionary=provider.world_context()
	check(touch_context.is_empty() or world.active_chunk().is_ancestor_of(touch_context.target),"context release target belongs to owning chunk")
	# Actual emitter and unchanged actor: aim at a native target from a clear approach.
	var sample_anchor=provider.component("work/sample")
	check(stand(sample_anchor.position+Vector2(42,30)),"Fire approach on actual stacked floor")
	store.select_device_mode("thermal");await settle()
	var emitter=world.input_adapter.emitter
	emitter.facing=(target.global_position-world.player.device_muzzle().global_position).normalized();emitter.release()
	check(emitter.available() and emitter.press(),"four-mode shared emitter starts actual fixture Fire")
	for tick in range(80):
		await physics_frame
		if target.is_committed():break
	emitter.release()
	check(target.is_committed() and provider._state.components["work/sample"].phase=="liquid","native exposure commits independent sample state")
	check(provider._state.components["work/pipe"].open and provider._state.components["work/vessel"].phase=="default","state effect leaves vessel/pipe ownership intact")
	check(store.data.extras.get("independent_phase_evidence",{}).has("melting_and_freezing:5:review-water"),"native receipt saved under stable world subregion identity")
	check(store.pending_explanations().any(func(e):return e.type=="melt_direct"),"manual success queues once-only explanation")
	await settle()
	check(world.input_adapter.modal=="explanation" and world.panels.model.get("speaker")=="professor_z1","safe feedback routes to correct Professor")
	var old_revision: int=world.panels.revision
	world.input_adapter.close_panel();await settle()
	check(store.pending_explanations().any(func(e):return e.type=="melt_direct"),"closing/interruption does not acknowledge explanation")
	world.input_adapter._panel_intent("guides.library","explanation_ack",{"view_revision":old_revision})
	check(store.pending_explanations().size()==1,"stale panel cannot acknowledge pending explanation")
	close_feedback();await settle()
	check(not store.pending_explanations().any(func(e):return e.type=="melt_direct"),"explicit acknowledgement persists once-only feedback")
	check(invoke("pickup") and world.player.carrying,"unique part pickup commits single owner and held visual")
	check(not provider.commit_action("pickup") and not world.player.request_jump(),"no duplicate pickup or carry jump")
	check(world.player.get_node("CarriedModule").get_children().filter(func(n):return n.get_meta("unique_item_id","")=="review-part" and not n.is_queued_for_deletion()).size()==1,"exactly one held part visual")
	var state: Dictionary=provider.snapshot();state.future_state={"keep":true};check(store.update_run(state),"unknown snapshot keys retained")
	check(store.save_world_location(world),"save while carrying")
	store.load_profile();check(world.restore_saved_world(world.access),"Continue restores active assembly")
	await settle();check(world.player.carrying and provider._state.items["review-part"]=="player" and store.data.active_run.state.future_state.keep,"Continue restores unique part/unknown fields")
	var place_point:=approach("place")
	# Cargo return uses a broad foreground aisle, with actual body movement.
	var aisle: Vector2=room.point(Vector2(4.8,6.7))
	check(await walk(aisle),"carried part reaches foreground aisle without jumping")
	check(await walk(place_point),"carried part reaches socket over supported floor")
	check(provider.commit_action("place") and not world.player.carrying,"matching placement commits unique installed owner")
	check(provider._state.items["review-part"]=="installed:work/socket" and asm.parts.gear.position.is_equal_approx(asm.parts.socket.position),"same part relocates; no second part instance")
	var stars: int=store.total_stars();var badges: Dictionary=store.achievement_state().unlocks.duplicate(true)
	check(not provider.commit_action("place"),"repeated placement cannot farm achievements")
	check(world.activate("Z1L5",store.WORLD_SAVE.anchor("Z1L5","C0")) and store.save_world_location(world),"revisit older checkpoint without changing unlock order")
	world.dead=true
	check(world.recover_world_checkpoint(world.access),"death restores current scoped attempt")
	await settle()
	check(world.player.position.is_equal_approx(store.WORLD_SAVE.anchor("Z1L5","C1")) and provider._state.items["review-part"]=="installed:work/socket","newest checkpoint and unique installed part survive death")
	# Malformed/future modular records stay byte-for-byte and refuse writes.
	var good: Dictionary=store.data.duplicate(true);store.data.active_run.state[ADAPTER.STATE_KEY].version=99;var future: Dictionary=store.data.duplicate(true)
	provider.refresh_binding();check(not provider.commit_action("power") and store.data==future,"future modular schema retained without writes")
	store.data=good;provider._restored();await settle()
	check(provider._state.items["review-part"]=="installed:work/socket","provider rebuild restores committed assembly")
	var chunk=world.active_chunk();var definition: Dictionary=provider.contract.duplicate(true);var attempt: String=store.data.active_run.attempt_id
	check(world.activate("Z1L1",world.REGISTRY.local_to_ground("Z1L1",Vector2(-699,-272))),"leave fixture region")
	await settle();check(not provider.active() and not emitter.held,"transition deactivates owned target and stops Fire")
	check(world.unmount_chunk(chunk.chunk_id),"inactive provider/chunk unload")
	await settle()
	chunk=load("res://World/Zone1/Z1L5Shell.tscn").instantiate();chunk.configure_geometry(world.models[0]);check(world.mount_chunk(chunk),"owning chunk reload")
	room=world.room_cutaway.rooms.filter(func(r):return r.subregion_id=="Z1L5")[0]
	check(world.activate("Z1L5",room.point(Vector2(6.5,5.8))) and store.enter_world_subregion(world,"Z1L5"),"ordinary return restores archived attempt")
	provider=FIXTURE.mount(world,definition);await settle()
	check(provider.active() and store.data.active_run.attempt_id==attempt and provider._state.items["review-part"]=="installed:work/socket","reload retains state and item identity without new reward")
	check(store.total_stars()==stars and store.achievement_state().unlocks==badges,"return/reload grant no stars/badges")
	store.fail_commit=true;var before: Dictionary=store.data.duplicate(true);hash=FileAccess.get_sha256(store.save_path)
	check(not provider.finish() and store.data==before and FileAccess.get_sha256(store.save_path)==hash,"failed completion retains entire attempt and unlocks")
	store.fail_commit=false
	check(provider.finish() and store.total_stars()==stars+1 and store.is_level_complete("melting_and_freezing",5),"authored completion commits state/star/unlock together")
	check(not provider.finish() and store.total_stars()==stars+1,"completion replay cannot duplicate reward")
	observations.append({"assembly":"6x6 cubes; 10 independent components; 20px layers","ground_height":room.elevation,"cargo":"actual supported walking/pickup/Continue/place","science":"native shared emitter/target receipt","completion":"failed/successful transaction and replay checked"})
func introduction_definition(region: String,mid: String,at: Vector2) -> Dictionary:
	var m: Dictionary=DEVICE.MILESTONES[mid];var components: Array=[];var targets: Dictionary={}
	var processes: Array=DEVICE.WORLD_INTRO.PROCESSES[m.capability]
	for i in range(processes.size()):
		var process: String=processes[i];var rule: Dictionary=RULES.PROCESSES[process];var id: String="sample"+str(i)
		var variants: Dictionary={}
		for phase in ["solid","liquid","gas"]:variants[phase]={"polygon":[[-3,0],[0,-2],[3,0],[0,2]],"color":"#b8d9de"}
		var part=FIXTURE.part(id,[.5,.5,0],[.5,.5],[.25,.25],{"phase":rule.from},variants);part.kind="state_effect";components.append(part)
		var target_id:=mid+"-"+process
		targets[target_id]={"component":"intro/"+id,"puzzle":"intro-"+process,"milestone":mid,"spec":{"zone":m.zone,"level":int(m.level),"material":"water","process":process,"allowed_modes":[m.mode],"required_exposure":.1,"max_range":100.0,"required_flags":[],"introductory_milestone":mid},"sample":{"material":"water","state":rule.from,"amount":1.0,"phase_region":rule.region,"heat_flow":rule.heat,"sealed":true,"instrumented":true,"temperature_controlled":true,"pressure_regime":"low" if m.mode=="vacuum" else "high","liquid_present":false}}
	# Deliberately fixture-only prose: future curriculum stays in its assigned content prompts.
	var lessons: Dictionary={};lessons[m.lesson]={"title":"Adapter review: "+m.lesson,"paragraphs":["Disposable fixture. Acknowledge to test introductory access; native observation remains required."]}
	return {"subregion":region,"assemblies":[{"id":"intro","origin_ground":[at.x,at.y-10],"footprint_cubes":[1,1],"components":components}],"introductions":[mid],"lessons":lessons,"actions":{},"items":{},"targets":targets}
func introduction_checks() -> void:
	for mid in DEVICE.MILESTONES:
		var m: Dictionary=DEVICE.MILESTONES[mid];var index: int=store.ZONES.find(m.zone)*6+int(m.level)-1;var region: String="Z%dL%d"%[store.ZONES.find(m.zone)+1,int(m.level)]
		store.set_completed_prefix(index)
		var baseline: Dictionary={"version":1,"player_name":"Intro fixture","completed":store.data.completed.duplicate(true),"active_run":{},"extras":{}}
		store.data=store.WORLD_SAVE.migrate(baseline);store.session_active=false
		var at: Vector2=store.WORLD_SAVE.anchor(region,"C0")
		check(world.activate(region,at) and store.enter_world_subregion(world,region),"intro ownership "+region)
		var chunk=world.active_chunk()
		if is_instance_valid(chunk.runtime_provider):chunk.runtime_provider.queue_free();chunk.runtime_provider=null;chunk.context_provider=null;await settle()
		var p:=ADAPTER.new();chunk.add_child(p);var definition:=introduction_definition(region,mid,at)
		check(p.bind(world,chunk,definition),"guided introduction binds "+mid)
		if chunk.runtime_provider!=p:continue
		check(not store.has_device_capability(m.capability),"location/earlier completions do not verify future capability "+mid)
		check(not p.introduce("unknown"),"unknown introduction refused "+mid)
		check(world.input_adapter.open_lesson(m.lesson,mid),"guided introduction uses shared Professor panel "+mid)
		world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
		check(store.is_device_mode_unlocked(m.mode) and not store.has_device_capability(m.capability),"guided mode precedes independent evidence "+mid)
		store.select_device_mode(m.mode)
		var count:=0
		for id in p.targets:
			var target=p.targets[id];var before_native: Dictionary=store.data.duplicate(true);var before_hash:=FileAccess.get_sha256(store.save_path)
			store.fail_commit=true
			var result: Dictionary=target.apply_exposure(.12,world.player.device_muzzle(),p.sample_for(id),{},true)
			check(result.get("new_outcome",false) and not target.is_committed(),"failed native introduction keeps uncommitted outcome "+id)
			check(store.data==before_native and FileAccess.get_sha256(store.save_path)==before_hash and not store.has_device_capability(m.capability),"failed introduction rolls back component/receipt/learning/capability/disk "+id)
			store.fail_commit=false
			check(p.commit_target(target) and target.is_committed(),"same verified guided receipt retries atomically "+id)
			count+=1
			check(store.has_device_capability(m.capability)==(count==p.targets.size()),"all required introductory observations gate capability "+id)
		check(DEVICE.WORLD_INTRO.verified(store.data,mid,m),"durable independent introduction receipt "+mid)
		var before: Dictionary=store.data.duplicate(true)
		world.demonstration_mode=true
		check(not p.introduce(mid) and not p.finish() and not p.discover(m.lesson,"preview") and store.data==before,"demonstration cannot mutate lesson/progress "+mid)
		world.demonstration_mode=false
		p.queue_free();chunk.runtime_provider=null;chunk.context_provider=null;await settle();close_feedback()
func content_checks() -> void:
	for zone in range(1,4):
		var local_teacher:=CONTENT.lesson("Z%dL1"%zone,"professor")
		check(local_teacher.title==local_teacher.name and local_teacher.paragraphs[1].contains(local_teacher.name),"generic Professor help names the owning zone teacher "+str(zone))
		for level_number in range(1,7):
			var id: String="Z%dL%d"%[zone,level_number];var speaker:=CONTENT.speaker(id)
			check(speaker.role=="professor_z%d"%zone and speaker.character_id!="finn" and not speaker.name.is_empty(),"correct Professor route "+id)
			check(load(speaker.portrait) is Texture2D,"original portrait route "+id)
	check(CONTENT.speaker("unknown").is_empty(),"unknown location cannot select Professor")
	var before: Dictionary=store.data.duplicate(true)
	for choice in range(3):
		var feedback:=CONTENT.answer("Z1L1",{"choices":["state","substance","vanished"],"correct":0,"feedback":"Water remains water."},choice)
		check(feedback.correct==(choice==0) and not feedback.feedback.is_empty(),"inline feedback for every answer "+str(choice))
	check(store.data==before,"feedback/Professor previews award no mastery/rewards")
func rejection_checks(origin: Vector2) -> void:
	var saved: Dictionary=store.data.duplicate(true)
	var unowned=load("res://Scripts/World/phase_device_target_2d.gd").new();world.active_chunk().add_child(unowned)
	var spec: Dictionary=provider.contract.targets["review-water"].spec.duplicate(true);spec.id="unowned-target"
	check(not unowned.configure(spec,world,store) and not unowned.belongs_to(world,store),"unregistered target cannot impersonate owned component")
	check(not store.commit_device_outcome(unowned,provider.snapshot(),world),"unverified/unowned target cannot commit native receipt");unowned.queue_free()
	check(store.data==saved,"rejected receipt mutates no durable state")
	var base: Dictionary=provider.contract.assemblies[0].duplicate(true)
	for kind in ["duplicate","NaN","missing-support"]:
		var bad: Dictionary=base.duplicate(true)
		match kind:
			"duplicate":bad.components[1].id=bad.components[0].id
			"NaN":bad.components[0].offset_cubes[0]=NAN
			"missing-support":bad.origin_ground=[-100000,-100000]
		var assembly=load("res://Scripts/World/Learning/puzzle_assembly.gd").new();provider.add_child(assembly)
		check(not assembly.configure(bad,world,world.active_chunk()) and assembly.parts.is_empty(),"invalid assembly rejected before creation "+kind);assembly.queue_free()
	var other=world.chunks["Z1L4.shell"];var wrong: Dictionary=provider.contract.duplicate(true);wrong.subregion="Z1L4"
	var outsider:=ADAPTER.new();other.add_child(outsider);var count: int=world.get_node("GroundSort").get_child_count()
	check(not outsider.bind(world,other,wrong),"target/owner mismatch rejects whole provider")
	check(world.get_node("GroundSort").get_child_count()==count and other.runtime_provider==null,"failed bind rolls external art/physics ownership back");outsider.queue_free()
	store.read_only=true
	check(not provider.commit_action("power") and not provider.finish() and store.data==saved,"read-only profile prevents every adapter write");store.read_only=false
	var raw: Dictionary=provider.default_state();raw.future_field={"keep":true};raw.items["future-item"]="installed:future-component"
	check(provider._supported_state(raw),"unknown dormant fields/items preserved")
	raw.items["future-item"]="player";check(not provider._supported_state(raw),"unknown carried item cannot create a duplicated actor part")
	var original: Dictionary=provider.contract.duplicate(true)
	# A legacy XY adapter records its original point; never rounds it onto a cube cell.
	var legacy: Dictionary=base.duplicate(true);legacy.id="legacy-offset";legacy.components=legacy.components.slice(0,1);legacy.components[0].legacy_local_xy=[origin.x-other.ground_origin.x+.375,origin.y-other.ground_origin.y+.625]
	var assembly=load("res://Scripts/World/Learning/puzzle_assembly.gd").new();provider.add_child(assembly)
	check(assembly.configure(legacy,world,other),"legacy logical anchor adapter accepts fractional XY")
	if not assembly.parts.is_empty():check(assembly.parts.values()[0].position.is_equal_approx(origin+Vector2(.375,.625)),"legacy anchor remains byte-exact/fractional, not snapped")
	assembly.dispose();assembly.queue_free();await settle()
