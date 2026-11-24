extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Frozen Mill content, composed with shared actor/HUD/native science/save services.
const PROGRESS=preload("res://Scripts/World/Zone1/frozen_mill_progress.gd")
const ANCHOR=preload("res://Scripts/World/Runtime/grounded_visual.gd")
const PARTS=PROGRESS.PARTS
const BELLS=["MillDock","HeatRouteStation","HeaterCartridge"]
const RECORD:="mill_thermal_world"
var pieces: Dictionary={}
var markers: Dictionary={}
var points: Dictionary={}
var _owned_art: Array=[]
var _conditional: Array=[]
var _gate_bindings: Dictionary={}
var _bell_time:=0.0
var _balance_time:=0.0
var _retry:=0.0
var _wrong_tray:=-1
var _wrong_time:=0.0
var _question_attempt:=""
var _jump: Dictionary={}
var _at_contact:=false
var _death_seen:=false
var _fall_recovery:=false

func bind_mill(host: Node2D) -> bool:
	var owner=host.chunks.get("Z1L2.shell")
	if owner==null:return false
	for piece in host.props:
		var station: String=piece.get_meta("station_id","")
		if station.begins_with("Z1L2."):pieces[station.trim_prefix("Z1L2.")]=piece
		if str(piece.get_meta("asset_id","")).begins_with("load_gauge_"):pieces.load_gauge=piece
	for station in host.models[0].data.stations:
		if station.subregion!="Z1L2":continue
		var id: String=station.id.trim_prefix("Z1L2.");var at:=Vector2(station.ground_xy[0],station.ground_xy[1]);points[id]=at
		var marker:=Marker2D.new();marker.position=at-owner.ground_origin-Vector2(0,float(host.raised_surface(at).get("height",0)));marker.set_meta("ground_xy",at);owner.add_child(marker);markers[id]=marker
	for source in host.models[0].data.sources:
		if source.subregion=="Z1L2" and not source.jumps.is_empty():_jump=source.jumps[0].duplicate(true)
	for floor_record in host.models[0].floors:
		if floor_record.region!="Z1L2" or (not floor_record.conditional and not floor_record.has("mill_kind")):continue
		for source in host.models[0].data.sources:
			if source.subregion!="Z1L2":continue
			for original in source.conditional_floors:
				var poly: PackedVector2Array=host.models[0].polygon(original.polygon,owner.ground_origin)
				if host.models[0].box_of(poly).get_center().distance_to(floor_record.bounds.get_center())<1:floor_record["mill_kind"]=original.source_path
		_conditional.append(floor_record)
	for name_hint in ["CartridgeReturnGate","SluiceGate","MaintenanceGate","FarLandingIce","WalkbackGate","ExitBridgeGate"]:
		var path: String="SolidBarriers/"+name_hint+"/Body";var records: Array=[];var artwork: Array=[]
		for b in host.models[0].blockers:
			if b.region=="Z1L2" and b.source_path==path:records.append(b)
		for art in host.props:
			if art.get_meta("asset_id","")!="maintenance_gate":continue
			for b in records:
				if art.position.distance_to(b.bounds.get_center())<2:artwork.append(art);break
		_gate_bindings[path]={"body":host.source_bodies.get("Z1L2:"+path),"records":records,"art":artwork}
	var okay:=bind(host,owner,{"subregion":"Z1L2","assemblies":[],"actions":{},"targets":{},"items":{},"guide_topics":["melting","resonance","balance"]})
	if not okay:return false
	chunk.checkpoint_provider=self
	_add_sign("WalkbackLever",points.WalkbackLever,.5859375)
	_add_sign("question",points.C1+Vector2(25,68),.5)
	_add_marker("help",points.professor_area)
	var authored_exit := owner.get_node_or_null("Layout/Exit") as Marker2D
	var exit_xy: Array = REGISTRY.definition("Z1L2").get("exit",[5810,1523])
	points.exit=authored_exit.global_position if authored_exit else Vector2(exit_xy[0],exit_xy[1])
	_add_marker("exit",points.exit)
	world.player.landed.connect(_landed)
	world.panels.intent_requested.connect(_question_intent)
	return true

func _add_marker(id: String,at: Vector2) -> void:
	var marker:=Marker2D.new();marker.position=at-chunk.ground_origin-Vector2(0,float(world.raised_surface(at).get("height",0)));marker.set_meta("ground_xy",at);chunk.add_child(marker);markers[id]=marker;points[id]=at

func _add_sign(id: String,at: Vector2,size: float) -> void:
	if not markers.has(id):_add_marker(id,at)
	var anchor=ANCHOR.new();anchor.position=at;anchor.elevation=float(world.raised_surface(at).get("height",0));world.district_art_parent(chunk).add_child(anchor)
	var sprite:=Sprite2D.new();sprite.texture=load("res://assets/zones/zone_1/flat_v1/props/sign.tres");sprite.offset=Vector2(0,-194);sprite.scale=Vector2.ONE*size;anchor.visuals.add_child(sprite);_owned_art.append(anchor)

func default_state() -> Dictionary:
	var run: Dictionary=store.data.active_run
	var saved: Dictionary=run.get("state",{}) if store.WORLD_SAVE.region_for_run(run)=="Z1L2" else {}
	return PROGRESS.migrate(saved,store.is_level_complete("melting_and_freezing",2))
func _supported_state(raw: Variant) -> bool:
	return store.data.active_run.get("state",{}).get(RECORD,1)==1 and PROGRESS.supported(raw)
func snapshot(next: Dictionary={}) -> Dictionary:
	var value: Dictionary=_state if next.is_empty() else next
	var result: Dictionary=store.data.active_run.get("state",{}).duplicate(true)
	result.merge(value.legacy,true);result[STATE_KEY]=value.duplicate(true);result[RECORD]=1
	var earned: Array=["C0"]
	if value.legacy.clear:earned.append("C1")
	if value.legacy.latch_thawed:earned.append("C2")
	result.checkpoint_progress=store.normalize_checkpoint_progress(result.get("checkpoint_progress",{}),["C0","C1","C2"],earned)
	for id in earned:result.checkpoint_progress=store.unlock_checkpoint(result.checkpoint_progress,id,["C0","C1","C2"])
	result.checkpoint=result.checkpoint_progress.latest_unlocked_checkpoint_id
	result.position=world.player.safe_save_position()-chunk.ground_origin
	return result

func campaign_legacy_snapshot() -> Dictionary:
	return snapshot() if not _state.is_empty() else {}

func _bind_targets() -> void:
	for target in targets.values():
		if is_instance_valid(target):target.queue_free()
	targets.clear();_bell_time=0;_balance_time=0;_retry=0
	for index in range(3):
		if _state.legacy.workshop_parts[index]!=0:continue
		var id: String="mill_"+PARTS[index]+"_casing";var at: Vector2=points["runtime_"+PARTS[index]]
		var target=TARGET.new();chunk.add_child(target);target.global_position=at-Vector2(0,float(world.raised_surface(at).get("height",0))+18);target.set_meta("ground_xy",at);targets[id]=target
		var spec:={"id":id,"zone":"melting_and_freezing","level":2,"material":"water","process":"melting","allowed_modes":["thermal"],"required_exposure":4.0,"max_range":100.0,"required_flags":["bell_bridge_clear"]}
		if not target.configure(spec,world,store):targets.erase(id);target.queue_free();continue
		target.bind_live_context(func():return {"material":"water","state":"solid","amount":1.0,"phase_region":"melting","heat_flow":"in"},func():return {"bell_bridge_clear":not _state.is_empty() and _state.legacy.clear})
		target.outcome_ready.connect(func(_outcome):commit_target(target))

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target) or target.verified_outcome(store,world).is_empty():return false
	var index: int=PARTS.find(target.definition().id.trim_prefix("mill_").trim_suffix("_casing"))
	if index<0 or _state.legacy.workshop_parts[index]!=0 or not _state.legacy.clear:return false
	var next:=_state.duplicate(true);next.legacy.workshop_parts[index]=1
	var events := _events([{"id":"first_thaw","members":[]},{"id":"six_changes","members":["melting"]}],target.definition().id)
	var okay: bool=store.commit_device_outcome(target,snapshot(next),world,[],events)
	if not okay:_failure("Could not save thaw. Part stays unavailable; retrying.");_retry=1.0
	else:world.get_node("/root/GameAudio").play("melt")
	return okay

func _failure(message: String) -> void:
	last_error=store.last_error;world.input_adapter.feedback=message+" "+last_error
func _commit(next: Dictionary,successes: Array=[],events: Array=[]) -> bool:
	var okay: bool=store.update_run_with_events(snapshot(next),successes,events,world)
	if not okay:_failure("Save failed. Committed work and carried item retained; retry.")
	else:world.input_adapter.feedback=""
	return okay

func sync_world_permissions() -> void:
	if world.active_chunk()==chunk:
		refresh_binding()
		if active() and not _state.is_empty():return
	var saved: Dictionary=store.world_record().get("attempts",{}).get("Z1L2",{}).get("attempt",{}).get("state",{})
	var state: Variant=saved.get(STATE_KEY)
	if state==null:state=PROGRESS.migrate(saved,store.is_level_complete("melting_and_freezing",2))
	if PROGRESS.supported(state):_geometry(state.legacy)
func _gate(path: String,opened: bool) -> void:
	var binding: Dictionary=_gate_bindings[path];var body=binding.body
	if is_instance_valid(body):body.collision_layer=0 if opened else 1
	for b in binding.records:b.layer=0 if opened else b.get("original_layer",1)
	for art in binding.art:art.visible=not opened
func _geometry(s: Dictionary) -> void:
	for pair in [["CartridgeReturnGate",true],["SluiceGate",s.clear],["MaintenanceGate",s.latch_thawed],["FarLandingIce",s.latch_thawed],["WalkbackGate",s.walkback_open],["ExitBridgeGate",s.crank=="installed"]]:_gate("SolidBarriers/"+pair[0]+"/Body",pair[1])
	for floor_record in _conditional:
		# Conditional source floors retain their original polygons. No new support
		# crosses a gap: earned stage toggles only its authored deck.
		var path: String=floor_record.get("mill_kind","")
		var earned: bool=s.latch_thawed if path=="Ground/MaintenanceLanding" else (s.walkback_open if path=="Ground/WalkbackBridge" else (s.crank=="installed" and path=="Generated counterweight exit deck"))
		floor_record.conditional=not earned

func _art(id: String,asset: String) -> void:
	if not pieces.has(id):return
	var texture=world.kits[0].get_meta("tiles",{}).get(asset)
	if texture!=null:pieces[id].visuals.get_node("Artwork").texture=texture
func present() -> void:
	if _state.is_empty():return
	var s: Dictionary=_state.legacy;_geometry(s)
	for i in range(3):
		_art(BELLS[i],["bell_low","bell_mid","bell_high"][i]+("_solved" if s.clear else ("_played" if i<s.bell_count else "_idle")))
		var part: String=PARTS[i];var phase: int=s.workshop_parts[i];var heat:=0.0
		var target=targets.get("mill_"+part+"_casing")
		if is_instance_valid(target):heat=target.exposure()/4.0
		_art("runtime_"+part,part+"_thaw_"+str(3 if phase>0 else mini(2,int(heat*4))))
		pieces["runtime_"+part].visible=phase<2 and s.workshop_held!=i
		_art("runtime_tray_"+part,part+"_tray_"+("wrong" if _wrong_tray==i else ("occupied" if phase==2 else "empty")))
	_art("ChannelIce","bell_bridge_clear" if s.clear else ("bell_bridge_fractured" if s.furnace_on else "bell_bridge_intact"))
	_art("ExitBridge","freight_lift_secured" if s.crank=="installed" else ("freight_lift_raised" if s.cache_thawed else "freight_lift_lowered"))
	_art("CrankSocket","brake_housing_released" if s.crank=="installed" else "brake_housing_locked")
	_art("load_gauge","load_gauge_%d"%mini(7,weight_total()))
	if pieces.has("MillCrankRecovery"):pieces.MillCrankRecovery.visible=s.cache_thawed and s.crank=="cache"
	# Keep the inherited cabinet footprint visible. Its legacy name does not
	# introduce another ice task: use existing open, unfrozen housing art.
	if pieces.has("CacheIceShell"):_art("CacheIceShell","storage_latch_open");pieces.CacheIceShell.show()
	if active():_carry()
	chunk.quests=[{"text":"Ring low, middle, high · vibration fractures ice","state":"done" if s.clear else "active"},{"text":"Thermal: thaw and match three metal parts","state":"done" if s.latch_thawed else "active"},{"text":"Balance load %d/5; return brake pin"%weight_total(),"state":"done" if s.crank=="installed" else "active"}]
	chunk.tutorial="Ring low, middle, high. Vibration fractures bridge ice; this is not melting." if not s.clear else ("Four valid Thermal seconds per casing. Release stops heat. Metal stays solid." if not s.latch_thawed else ("Carry brake pin across lowered return bridge; install it in housing. Jump stays blocked while carrying." if s.crank=="held" else ("Lift secured. Reach the exit. Observation question remains optional." if s.crank=="installed" else "Cross marked gap empty-handed. Heavy 3 + light 2 balances load 5. Lower return before carrying brake pin.")))
	if store.is_level_complete("melting_and_freezing",2):chunk.tutorial="Follow the trail to Stillwater Crossing."

func _carry() -> void:
	var s: Dictionary=_state.legacy
	var id: String="brake_pin" if s.crank=="held" else (PARTS[s.workshop_held] if s.workshop_held>=0 else "")
	if is_instance_valid(_held) and _held.get_meta("unique_item_id","")==id:return
	if is_instance_valid(_held):world.player._grip_offsets.erase(_held.get_instance_id());_held.get_parent().remove_child(_held);_held.queue_free();_held=null
	world.player.carrying=not id.is_empty()
	if not id.is_empty():
		_held=Sprite2D.new();_held.texture=world.kits[0].get_meta("tiles",{}).get("brake_pin" if id=="brake_pin" else id+"_part");_held.scale=Vector2.ONE*.5;_held.set_meta("unique_item_id",id);world.player.get_node("CarriedModule").add_child(_held);world.player._fit_carried_objects();world.player._play("carry_idle")
	world.player._sync_carry_socket()

func _reachable(id: String) -> bool:
	if not _can_write() or not points.has(id) or world.player.jump_elapsed>=0 or (world.player.action_elapsed>=0 and not _at_contact):return false
	var at: Vector2=points[id]
	if world.player.position.distance_to(at)>42 or not world.world_contact_allowed(world.player.position,at):return false
	var query:=PhysicsRayQueryParameters2D.create(world.player.position,at,1|2|8,[world.player.get_rid()]);query.hit_from_inside=true
	var hit:=world.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or str(hit.collider.get_meta("source_path","")).begins_with("Scenery/"+id+"Art/")
func action_allowed(id: String) -> bool:
	if not _reachable(id):return false
	var s: Dictionary=_state.legacy
	if id=="question":return not world.player.carrying
	if id=="help":return not world.player.carrying
	if id in BELLS:return not s.clear and not s.furnace_on and not world.player.carrying
	if id.begins_with("runtime_tray_"):
		var i:=PARTS.find(id.trim_prefix("runtime_tray_"));return i>=0 and s.workshop_held>=0 and s.workshop_parts[i]!=2
	if id.begins_with("runtime_"):
		var i:=PARTS.find(id.trim_prefix("runtime_"));return i>=0 and s.clear and s.workshop_parts[i]==1 and not world.player.carrying
	if id in ["ReflectorA","ReflectorB"]:return s.latch_thawed and not s.cache_thawed and not world.player.carrying
	if id=="WalkbackLever":return s.latch_thawed and not s.walkback_open and s.get("jump_records",{}).get("z1_l2_j2",false) and not world.player.carrying
	if id=="MillCrankRecovery":return s.cache_thawed and s.walkback_open and s.crank=="cache" and not world.player.carrying
	if id=="CrankSocket":return s.crank=="held"
	if id=="exit":return PROGRESS.complete(s) and not world.player.carrying
	return false
func world_context() -> Dictionary:
	var id:="";var distance:=INF
	for key in markers:
		if action_allowed(key) and world.player.position.distance_to(points[key])<distance:id=key;distance=world.player.position.distance_to(points[key])
	if id.is_empty():return {}
	var caption: String={"MillDock":"Ring low bell","HeatRouteStation":"Ring middle bell","HeaterCartridge":"Ring high bell","ReflectorA":"Toggle heavy · 3 units","ReflectorB":"Cycle light · 0–3 units","WalkbackLever":"Lower return bridge","MillCrankRecovery":"Carry brake pin","CrankSocket":"Install brake pin","exit":"Leave Frozen Mill","question":"Optional observation question","help":"Free Mill help"}.get(id,"Carry "+id.trim_prefix("runtime_"))
	if id.begins_with("runtime_tray_"):caption="Place part · "+id.trim_prefix("runtime_tray_").replace("_"," ")+" tray"
	return {"key":"Z1L2:"+id,"caption":caption,"target":markers[id],"enabled":true,"allowed":Callable(self,"action_allowed").bind(id),"invoke":Callable(self,"commit_action").bind(id)}
func commit_action(id: String) -> bool:
	if not action_allowed(id):return false
	if id=="question":return open_question()
	if id=="help":return world.input_adapter.open_lesson("resonance" if not _state.legacy.clear else ("melting" if not _state.legacy.latch_thawed else "balance"))
	if id=="exit":return finish()
	world.input_adapter.stop_all("mill_context",true)
	if not action_allowed(id):return false
	# Keep existing lift/place/operate poses. Authority and reach are checked
	# again at hand contact, so pause/restore/movement cannot commit a stale tap.
	var attempt: String=_attempt
	var contact:=func():
		_at_contact=true
		if attempt==_attempt and action_allowed(id):_apply_action(id)
		_at_contact=false
	var pose:="operate"
	if id.begins_with("runtime_tray_") or id=="CrankSocket":pose="place"
	elif id.begins_with("runtime_") or id=="MillCrankRecovery":pose="lift"
	world.player._facing=world.player._direction_from_vector(points[id]-world.player.position)
	return world.player.perform_action(pose,contact,.72 if pose=="place" else (.65 if pose=="lift" else .5))

func _apply_action(id: String) -> bool:
	var next:=_state.duplicate(true);var s: Dictionary=next.legacy;var successes: Array=[];var events: Array=[]
	if id in BELLS:
		var step: int=s.bell_count;var index:=BELLS.find(id);s.bell_count=step+1 if index==step else int(index==0);s.furnace_on=s.bell_count==3
	elif id.begins_with("runtime_tray_"):
		var i:=PARTS.find(id.trim_prefix("runtime_tray_"))
		if s.workshop_held!=i:_wrong_tray=i;_wrong_time=1.5;world.input_adapter.feedback="Silhouette does not match. You still hold the "+PARTS[s.workshop_held].replace("_"," ")+".";present();return true
		s.workshop_parts[i]=2;s.workshop_held=-1
		if s.workshop_parts==[2,2,2]:s.gear_thawed=true;s.latch_thawed=true;successes=[{"puzzle":"thaw_sort","type":"melt_direct","topic":"melting","object":"workshop"}]
	elif id.begins_with("runtime_"):s.workshop_held=PARTS.find(id.trim_prefix("runtime_"))
	elif id=="ReflectorA":s.heavy_engaged=not s.heavy_engaged;_balance_time=0
	elif id=="ReflectorB":s.light_count=(s.light_count+1)%4;_balance_time=0
	elif id=="WalkbackLever":s.walkback_open=true
	elif id=="MillCrankRecovery":s.crank="held"
	elif id=="CrankSocket":s.crank="installed";events=_events([{"id":"hands_on","event":"delivery:brake_pin","members":[]}],"brake_pin")
	var okay:=_commit(next,successes,events)
	if okay:
		world.get_node("/root/GameAudio").play("bell_"+["low","middle","high"][BELLS.find(id)] if id in BELLS else ("collect" if id.begins_with("runtime_") and not id.begins_with("runtime_tray_") else "interact"))
	return okay

func weight_total() -> int:return (3 if _state.legacy.heavy_engaged else 0)+int(_state.legacy.light_count) if not _state.is_empty() else 0
func _landed(origin: Vector2,destination: Vector2) -> void:
	if not _can_write() or not _state.legacy.latch_thawed or _jump.is_empty() or not world.valid_landing(destination):return
	var model=world.models[0]
	if not Geometry2D.is_point_in_polygon(origin,model.polygon(_jump.takeoff,chunk.ground_origin)) or not Geometry2D.is_point_in_polygon(destination,model.polygon(_jump.landing,chunk.ground_origin)):return
	var next:=_state.duplicate(true);next.legacy["jump_records"]=next.legacy.get("jump_records",{}).duplicate(true);next.legacy.jump_records.z1_l2_j2=true;_commit(next)
func _process(delta: float) -> void:
	if active() and not _state.is_empty() and world.dead:
		_retry=maxf(0,_retry-delta)
		if _retry==0:_save_death()
		return
	if not _can_write():return
	_death_seen=false
	if _state.legacy.death_pending:
		var next:=_state.duplicate(true);next.legacy.death_pending=false
		var events := []
		var checkpoint: String = snapshot().checkpoint_progress.latest_unlocked_checkpoint_id
		if checkpoint != "C0" and world.safe_ground.is_equal_approx(world.checkpoint_anchor(subregion_id,checkpoint)):
			events = _events([{"id":"safe_return","event":str(next.legacy.deaths),"members":[]}],"respawn")
		if not _commit(next,[],events):return
	if store.data.active_run.state.get(RECORD)!=1 and not _commit(_state):return
	for topic in ["resonance","melting","balance"]:discover(topic,"mill_reference_"+topic)
	_retry=maxf(0,_retry-delta);_wrong_time=maxf(0,_wrong_time-delta)
	if _wrong_time==0:_wrong_tray=-1
	var s: Dictionary=_state.legacy
	if s.furnace_on and not s.clear:
		_bell_time+=delta
		if _bell_time>=3:
			var next:=_state.duplicate(true);next.legacy.clear=true;next.legacy.part="docked"
			if _commit(next,[{"puzzle":"resonance_bells","type":"ice_resonance","topic":"resonance","object":"bells"}]):_bell_time=0
	if s.latch_thawed and not s.cache_thawed:
		_balance_time=_balance_time+delta if weight_total()==5 else 0
		if _balance_time>=3:
			var next:=_state.duplicate(true);next.legacy.cache_thawed=true
			if _commit(next,[{"puzzle":"counterweight_lift","type":"mill_counterweight","topic":"balance","object":"lift"}]):_balance_time=0
	for target in targets.values():
		if is_instance_valid(target) and not target.is_committed() and _retry==0 and not target.verified_outcome(store,world).is_empty():commit_target(target)
	present()

func recover_world_fall() -> bool:
	if not active() or _state.is_empty():return false
	world.input_adapter.stop_all("mill_fall",true)
	world.dead=true;_fall_recovery=true;_death_seen=false;_retry=0
	_save_death()
	return true # Failed writes stay blocked here; generic fallback must not bypass them.
func _save_death() -> void:
	if not _death_seen:
		var next:=_state.duplicate(true);next.legacy.deaths+=1;next.legacy.death_pending=true
		_death_seen=_commit(next)
		if not _death_seen:_retry=1.0;return
	if _fall_recovery:
		_fall_recovery=false
		if not world.recover_world_checkpoint(world.access):_fall_recovery=true;world.dead=true;_retry=1.0

func world_checkpoints() -> Array:
	var result: Array=[]
	if _state.is_empty():return result
	for id in ["C0","C1","C2"]:result.append({"id":id,"name":id,"position":world.checkpoint_anchor("Z1L2",id),"attuned":_travel_allowed(id),"allowed":Callable(self,"_travel_allowed").bind(id)})
	return result
func _travel_allowed(id: String) -> bool:return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence
func world_travel_checkpoint(id: String) -> bool:return _travel_allowed(id) and world.activate("Z1L2",world.checkpoint_anchor("Z1L2",id))
func completion_authorized() -> bool:return _pending_finish and active() and not _state.is_empty() and PROGRESS.complete(_state.legacy) and world.valid_landing(world.player.position) and world.player.position.distance_to(points.exit)<45
func finish() -> bool:
	if not _can_write() or not PROGRESS.complete(_state.legacy) or world.player.position.distance_to(points.exit)>=45 or not world.valid_landing(world.player.position):return false
	var original: Dictionary=store.data.active_run.state
	store.data.active_run.state=snapshot()
	_pending_finish=true
	var events: Array=[]
	if _state.legacy.deaths==0 and store.data.active_run.get("achievement_history_known",false) and not _state.legacy.get("completion_only_recovery",false):events=_events([{"id":"steady_explorer","event":"deathless","members":[]}],"completion")
	var okay: bool=store.finish_level("melting_and_freezing",2,events,world)
	_pending_finish=false
	if not okay:store.data.active_run.state=original
	else:chunk.tutorial="Follow the trail to Stillwater Crossing."
	return okay
func explanation() -> Dictionary:return super.explanation() if not _state.is_empty() else {}
func open_question() -> bool:
	if not _can_write():return false
	_question_attempt=_attempt;world.input_adapter._begin_modal("mill_question");_show_question("");return true
func _show_question(feedback: String) -> void:
	var question: Dictionary=store.LEVEL_REGISTRY.definition("melting_and_freezing",2).practice_question;var actions: Array=[]
	for i in range(question.choices.size()):actions.append({"id":"mill_answer_"+str(i),"label":question.choices[i],"enabled":true})
	actions.append({"id":"close","label":"Return to game","enabled":true})
	world.panels.open_panel("guides.library",{"title":"Optional observation","body":"What changed when Thermal heated the water-ice casings?\n\n"+feedback,"speaker":"professor_z1","search":false,"rows":[],"actions":actions})
func _question_intent(_panel: String,id: String,payload: Dictionary) -> void:
	if world.input_adapter.modal!="mill_question" or payload.get("view_revision")!=world.panels.revision or not active() or _question_attempt!=_attempt or not id.begins_with("mill_answer_") or not world._focused or world._suspended or world.dead:return
	var question: Dictionary=store.LEVEL_REGISTRY.definition("melting_and_freezing",2).practice_question
	var choice := id.trim_prefix("mill_answer_")
	if not choice.is_valid_int(): return
	var answer := CONTENT.answer(subregion_id,question,choice.to_int())
	if not answer.is_empty(): _show_question(answer.feedback)
func acknowledge_help(topic: String) -> bool:
	if not _can_write():return false
	var s: Dictionary=_state.legacy
	var puzzle: String="resonance_bells" if not s.clear else ("thaw_sort" if not s.latch_thawed else ("counterweight_lift" if s.crank!="installed" else ""))
	if puzzle.is_empty():return super.acknowledge_help(topic)
	return _commit(_state,[],_events([{"id":"good_question","event":"help:"+puzzle,"members":[],"guide":{"topic":topic,"object":"professor"}}],"help:"+puzzle))
func _exit_tree() -> void:
	for art in _owned_art:
		if is_instance_valid(art):art.queue_free()
	for record in _conditional:record.conditional=true
	super._exit_tree()
