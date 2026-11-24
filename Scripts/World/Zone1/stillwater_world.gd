extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Z1L3 only. Shared input, native targets, transactional learning and world saves.
const PARTS=preload("res://Scripts/World/Zone1/stillwater_assembly.gd")
const RECORD="stillwater_version"
var points: Dictionary={}
var markers: Dictionary={}
var pits: Array=[]
var _original_floors: Array=[]
var _pit_art: Array=[]
var _reservation_art: Array=[]
var _supports: Dictionary={}
var _retry:=0.0
var _question_attempt:=""
var _fall_recovery:=false
var _death_saved:=false
var _at_contact:=false
func bind_crossing(host: Node2D) -> bool:
	var owner=host.chunks.get("Z1L3.shell")
	if owner==null or get_parent()!=owner:return false
	for station in host.models[0].data.stations:
		if station.subregion=="Z1L3":points[station.id.get_slice(".",1)]=host.models[0].v(station.ground_xy)
	# Measured flat module footprints within the existing 260x220 reservations.
	points.court1+=Vector2(-8,-32);points.court2+=Vector2(0,16);points.court3+=Vector2(-24,-24)
	var okay:=bind(host,owner,PARTS.definition(points))
	if not okay:return false
	chunk.checkpoint_provider=self
	for key in ["first/tray","supply/water","crossing/left","crossing/right","crossing/shutter"]:
		var label:=Label.new();label.name="State";label.position=Vector2(-45,7);label.size=Vector2(90,20);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",10);label.add_theme_color_override("font_color",Color("f2f5e4"));label.add_theme_color_override("font_outline_color",Color("223c43"));label.add_theme_constant_override("outline_size",3);component(key).visuals.add_child(label)
	for id in ["professor","exit"]:_marker(id,points[id])
	_marker("question",points.professor+Vector2(65,20))
	for pair in [["valve","supply/valve"],["heater","crossing/shutter"],["latch","crossing/latch"]]:_marker(pair[0],component(pair[1]).position)
	# Replace only the three reservation sprites with independent production modules.
	for art in host.props:
		if str(art.name).begins_with("Z1L3.court") or str(art.name).begins_with("Z1L3_court"):_reservation_art.append(art);art.hide()
	# Cut real unsupported water gaps from every overlapping floor, including dry
	# mainland below the tray. No liquid/empty tray is a valid landing.
	_original_floors=host.models[0].floors.filter(func(record):return record.region=="Z1L3")
	for id in ["court1","court3"]:
		var at: Vector2=points[id];var half:=Vector2(70,35) if id=="court1" else Vector2(96,48)
		var local:=PackedVector2Array([Vector2(-half.x,0),Vector2(0,-half.y),Vector2(half.x,0),Vector2(0,half.y)])
		var poly:=PackedVector2Array()
		for point in local:poly.append(at+point)
		pits.append(poly)
		var anchor=preload("res://Scripts/World/Runtime/grounded_visual.gd").new();anchor.position=at;anchor.elevation=float(host.raised_surface(at).get("height",0));anchor.z_index=-1;host.district_art_parent(owner).add_child(anchor)
		var water:=Polygon2D.new();water.name="Water";water.polygon=local;water.color=Color("406e82");anchor.visuals.add_child(water)
		if id=="court3":
			for side in ["left","right"]:
				var box:=Rect2(Vector2(-96,-35) if side=="left" else Vector2(16,-35),Vector2(80,70))
				for polygon in Geometry2D.intersect_polygons(local,host.models[0].rect_poly(box)):
					var ice:=Polygon2D.new();ice.polygon=polygon;ice.color=Color("b2dce5");ice.set_meta("tray_side",side);ice.hide();anchor.visuals.add_child(ice)
		var rim:=Line2D.new();rim.points=local;rim.closed=true;rim.width=3;rim.default_color=Color("829b9b");anchor.visuals.add_child(rim);_pit_art.append(anchor)
	var clipped: Array=[]
	for floor_record in host.models[0].floors:
		if floor_record.region!="Z1L3":
			clipped.append(floor_record)
			continue
		var fragments: Array=[floor_record.polygon]
		for pit in pits:
			var next: Array=[]
			for fragment in fragments:next.append_array(_cut_convex(fragment,pit))
			fragments=next
		for fragment in fragments:
			var record: Dictionary=floor_record.duplicate(true);record.polygon=fragment;clipped.append(record)
	_reindex_floors(clipped)
	world.player.landed.connect(_landed);world.panels.intent_requested.connect(_question_intent)
	present();return true
func _cut_convex(polygon: PackedVector2Array,cut: PackedVector2Array) -> Array:
	# The diamond's bounding box partitions into four axis-aligned outside bands
	# and four corner triangles. Keep large banks intact: triangulating an entire
	# mainland introduces long numeric seams in the full-foot support union.
	if Geometry2D.intersect_polygons(polygon,cut).is_empty():return [polygon]
	var box: Rect2=world.models[0].box_of(polygon);var hole: Rect2=world.models[0].box_of(cut)
	var x0:=maxf(box.position.x,hole.position.x);var x1:=minf(box.end.x,hole.end.x)
	var bands: Array=[Rect2(box.position,Vector2(maxf(0,x0-box.position.x),box.size.y)),Rect2(Vector2(x1,box.position.y),Vector2(maxf(0,box.end.x-x1),box.size.y)),Rect2(Vector2(x0,box.position.y),Vector2(x1-x0,maxf(0,hole.position.y-box.position.y))),Rect2(Vector2(x0,maxf(box.position.y,hole.end.y)),Vector2(x1-x0,maxf(0,box.end.y-hole.end.y)))]
	var result: Array=[]
	for band in bands:
		if band.size.x>.001 and band.size.y>.001:result.append_array(Geometry2D.intersect_polygons(polygon,world.models[0].rect_poly(band)))
	var corners: Array=[hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]
	for edge in range(4):result.append_array(Geometry2D.intersect_polygons(polygon,PackedVector2Array([corners[edge],cut[edge],cut[(edge+1)%4]])))
	return result
func _marker(id: String,at: Vector2) -> void:
	var marker:=Marker2D.new();marker.position=at-chunk.ground_origin-Vector2(0,float(world.raised_surface(at).get("height",0)));chunk.add_child(marker);markers[id]=marker;points[id]=at
func default_state() -> Dictionary:
	var state:=super.default_state();state.merge({"crossed":false,"deaths":0,"death_pending":false});return state
func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or store.data.active_run.get("state",{}).get(RECORD,1)!=1:return false
	if not raw.get("crossed") is bool or not raw.get("deaths") is int or raw.deaths<0 or not raw.get("death_pending") is bool:return false
	var c: Dictionary=raw.components
	for key in ["first/tray","supply/water","crossing/left","crossing/right"]:
		if not c[key].get("amount") is int or c[key].amount<0:return false
	if c["first/tray"].amount!=1 or c["first/tray"].phase not in ["liquid","solid"]:return false
	if c["supply/water"].amount not in [0,2] or c["supply/water"].phase not in ["solid","liquid","empty"]:return false
	for key in ["crossing/left","crossing/right"]:
		if c[key].amount not in [0,1] or c[key].phase not in ["empty","liquid","solid"] or (c[key].phase=="empty")!=(c[key].amount==0):return false
	if c["supply/water"].amount+c["crossing/left"].amount+c["crossing/right"].amount!=2:return false
	if (c["supply/water"].phase=="empty")!=(c["supply/water"].amount==0):return false
	if c["supply/water"].phase!="solid" and c["first/tray"].phase!="solid":return false
	if c["supply/valve"].phase not in ["open","closed"] or (c["supply/valve"].phase=="open")!=(c["supply/water"].amount==0):return false
	if c["crossing/heater"].phase not in ["connected","isolated"] or c["crossing/latch"].phase not in ["open","latched"]:return false
	if c["crossing/shutter"].phase!=c["crossing/heater"].phase:return false
	var solid: bool=c["crossing/left"].phase=="solid" or c["crossing/right"].phase=="solid"
	if solid and (c["crossing/heater"].phase!="isolated" or c["first/tray"].phase!="solid"):return false
	if c["crossing/latch"].phase=="latched" and not _both_solid(c):return false
	return not raw.crossed or c["crossing/latch"].phase=="latched"
func snapshot(next: Dictionary={}) -> Dictionary:
	var value: Dictionary=_state if next.is_empty() else next
	var result:=super.snapshot(value);result[RECORD]=1;result.death_pending=value.death_pending;result.deaths=value.deaths
	var earned: Array=["C0"]
	if value.components["first/tray"].phase=="solid":earned.append("C1")
	if value.components["crossing/left"].amount==1 and value.components["crossing/right"].amount==1:earned.append("C2")
	result.checkpoint_progress=store.normalize_checkpoint_progress(result.get("checkpoint_progress",{}),["C0","C1","C2"],earned)
	for id in earned:result.checkpoint_progress=store.unlock_checkpoint(result.checkpoint_progress,id,["C0","C1","C2"])
	result.checkpoint=result.checkpoint_progress.latest_unlocked_checkpoint_id;return result
func _bind_targets() -> void:
	for target in targets.values():
		if is_instance_valid(target):target.queue_free()
	targets.clear();_retry=0
	for pair in [["first_ice","first/tray","freezing"],["melt_supply","supply/water","melting"],["left_ice","crossing/left","freezing"],["right_ice","crossing/right","freezing"]]:
		var id: String=pair[0];var key: String=pair[1];var process: String=pair[2]
		var spec:={"id":id,"zone":"melting_and_freezing","level":3,"material":"water","process":process,"allowed_modes":["thermal" if process=="melting" else "cryo"],"required_exposure":3.0,"max_range":100.0,"required_flags":[] if id=="first_ice" else ["ready"]}
		if id=="first_ice":spec.introductory_milestone="z1l3_freezing"
		contract.targets[id]={"component":key,"spec":spec,"milestone":"z1l3_freezing" if id=="first_ice" else ""}
		var target=TARGET.new();chunk.add_child(target);var anchor=component(key);target.global_position=anchor.position-Vector2(0,anchor.elevation+16);target.set_meta("ground_xy",anchor.position);targets[id]=target
		if not target.configure(spec,world,store):targets.erase(id);target.queue_free();continue
		target.bind_live_context(Callable(self,"sample_for").bind(id),Callable(self,"flags_for").bind(id));target.outcome_ready.connect(func(_outcome):commit_target(target))
func sample_for(id: String) -> Dictionary:
	if _state.is_empty():return {}
	var s: Dictionary=_state.components[contract.targets[id].component];var melt: bool=id=="melt_supply"
	return {"material":"water","state":s.phase,"amount":s.amount,"phase_region":"melting" if melt else "freezing","heat_flow":"in" if melt else "out"}
func flags_for(id: String) -> Dictionary:
	if _state.is_empty():return {"ready":false}
	var c: Dictionary=_state.components
	return {"ready":c["first/tray"].phase=="solid" and (id=="melt_supply" or (c["crossing/heater"].phase=="isolated" and c["crossing/left"].amount==1 and c["crossing/right"].amount==1))}
func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):return false
	var outcome: Dictionary=target.verified_outcome(store,world)
	if outcome.is_empty():return false
	var key: String=contract.targets[outcome.id].component
	if _state.components[key].phase==outcome.to_state:return false
	var next:=_state.duplicate(true);next.components[key].phase=outcome.to_state
	var events: Array=_events([{"id":"six_changes","event":"observe-"+outcome.process,"members":[outcome.process]}],outcome.id)
	if outcome.process == "freezing":
		events.append_array(_events([{"id":"ice_builder","members":[]}],outcome.id))
	var okay: bool=store.commit_device_outcome(target,snapshot(next),world,[],events)
	if not okay:_failed();_retry=1
	return okay
func _failed() -> void:
	last_error=store.last_error;world.input_adapter.feedback="Save failed. Committed water, support and progress retained. Retry. "+last_error
func _commit(next: Dictionary,successes: Array=[],events: Array=[]) -> bool:
	if not _supported_state(next):return false
	if not store.update_run_with_events(snapshot(next),successes,events,world):_failed();return false
	world.input_adapter.feedback="";return true
func _near(id: String) -> bool:
	if not _can_write() or not markers.has(id) or world.player.jump_elapsed>=0 or (world.player.action_elapsed>=0 and not _at_contact) or world.player.position.distance_to(points[id])>=42 or not world.world_contact_allowed(world.player.position,points[id]):return false
	var query:=PhysicsRayQueryParameters2D.create(world.player.position,points[id],1|2|8,[world.player.get_rid()]);query.hit_from_inside=true
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func _both_solid(c: Dictionary) -> bool:return c["crossing/left"].phase=="solid" and c["crossing/right"].phase=="solid"
func action_allowed(id: String) -> bool:
	if not _near(id) or world.player.carrying:return false
	var c: Dictionary=_state.components
	match id:
		"professor","question":return true
		"valve":return c["first/tray"].phase=="solid" and c["supply/water"].phase=="liquid" and c["supply/water"].amount==2 and c["supply/valve"].phase=="closed"
		"heater":return c["crossing/left"].amount==1 and c["crossing/heater"].phase=="connected"
		"latch":return _both_solid(c) and c["crossing/latch"].phase=="open"
		"exit":return _complete()
	return false
func world_context() -> Dictionary:
	var chosen:="";var distance:=INF
	for id in markers:
		if action_allowed(id) and world.player.position.distance_to(points[id])<distance:chosen=id;distance=world.player.position.distance_to(points[id])
	if chosen.is_empty():return {}
	var captions:={"professor":"Professor · freezing lesson / free help","valve":"Open meltwater supply valve","heater":"Disconnect bridge heater","latch":"Secure mechanical crossing latch","exit":"Leave Stillwater Crossing","question":"Optional observation question"}
	return {"key":"Z1L3:"+chosen,"caption":captions[chosen],"target":markers[chosen],"enabled":true,"allowed":Callable(self,"action_allowed").bind(chosen),"invoke":Callable(self,"commit_action").bind(chosen)}
func commit_action(id: String) -> bool:
	if not action_allowed(id):return false
	if id=="professor":return world.input_adapter.open_lesson("freezing","z1l3_freezing")
	if id=="question":return open_question()
	if id=="exit":return finish()
	world.input_adapter.stop_all("stillwater_action",true)
	var attempt: String=_attempt
	var contact:=func():
		_at_contact=true
		if attempt==_attempt and action_allowed(id):_apply_action(id)
		_at_contact=false
	return world.player.perform_action("operate",contact,.5)
func _apply_action(id: String) -> bool:
	if not action_allowed(id):return false
	var next:=_state.duplicate(true);var c: Dictionary=next.components;var successes: Array=[]
	match id:
		"valve":
			c["supply/water"].amount=0;c["supply/water"].phase="empty";c["supply/valve"].phase="open"
			for key in ["crossing/left","crossing/right"]:c[key].amount=1;c[key].phase="liquid"
		"heater":c["crossing/heater"].phase="isolated";c["crossing/shutter"].phase="isolated"
		"latch":c["crossing/latch"].phase="latched";successes=[{"puzzle":"separate_heat","type":"stillwater_latch","topic":"freezing","object":"crossing_latch"}]
		_:return false
	return _commit(next,successes)
func _reindex_floors(records: Array) -> void:
	var model=world.models[0];model.floors=[];model.floor_bins={}
	for record in records:model.index_record(record,model.floors,model.floor_bins)
func _add_support(id: String,box: Rect2) -> void:
	if _supports.has(id):return
	world.models[0].add_floor(world.models[0].rect_poly(box),"Z1L3","bridge",0,false,"Stillwater:"+id);_supports[id]=true
func sync_world_permissions() -> void:
	if world.active_chunk()==chunk:
		refresh_binding()
		if active() and not _state.is_empty():return
	var saved: Variant=store.world_record().get("attempts",{}).get("Z1L3",{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	_geometry(saved if _supported_state(saved) else default_state())
func _geometry(state: Dictionary) -> void:
	if state.is_empty() or pits.is_empty():return
	var c: Dictionary=state.components
	# Scientific state colors cover the real tray span, not just its small kit
	# icon. Solid-but-unlatched ice remains visibly distinct from secured support.
	_pit_art[0].visuals.get_node("Water").color=Color("b2dce5") if c["first/tray"].phase=="solid" else Color("406e82")
	for visual in _pit_art[1].visuals.get_children():
		if visual.has_meta("tray_side"):visual.visible=c["crossing/"+str(visual.get_meta("tray_side"))].phase=="solid"
	var desired: Array=[]
	if c["first/tray"].phase=="solid":desired.append("first")
	if c["crossing/latch"].phase=="latched":desired.append_array(["left","right"])
	if _supports.keys().any(func(id):return id not in desired):
		_reindex_floors(world.models[0].floors.filter(func(record):return not str(record.body_path).begins_with("Stillwater:") or str(record.body_path).trim_prefix("Stillwater:") in desired))
		for id in _supports.keys():
			if id not in desired:_supports.erase(id)
	if c["first/tray"].phase=="solid":_add_support("first",Rect2(points.court1-Vector2(70,42),Vector2(140,84)))
	if c["crossing/latch"].phase=="latched":
		_add_support("left",Rect2(points.court3+Vector2(-96,-35),Vector2(80,70)))
		_add_support("right",Rect2(points.court3+Vector2(16,-35),Vector2(80,70)))
func present() -> void:
	if _state.is_empty():return
	super.present();_geometry(_state)
	var c: Dictionary=_state.components
	for pair in [["first_ice","first/tray"],["left_ice","crossing/left"],["right_ice","crossing/right"]]:
		var anchor=component(pair[1]);var phase: String=c[pair[1]].phase
		if phase=="solid" and (pair[0]=="first_ice" or c["crossing/latch"].phase=="latched"):phase="latched"
		elif is_instance_valid(targets.get(pair[0])) and targets[pair[0]].exposure()>0 and phase=="liquid":phase="freezing"
		anchor.visuals.get_node("Artwork").texture=load(PARTS.visual("cooling_tray_"+phase).path)
		var label=anchor.visuals.get_node_or_null("State")
		if label:label.text="SECURED" if phase=="latched" else ("COOLING" if phase=="freezing" else phase.to_upper())
	var supply_label=component("supply/water").visuals.get_node_or_null("State")
	if supply_label:supply_label.text=("ICE · 2" if c["supply/water"].phase=="solid" else ("WATER · 2" if c["supply/water"].phase=="liquid" else "DRAINED"))
	var shutter_label=component("crossing/shutter").visuals.get_node_or_null("State")
	if shutter_label:shutter_label.text=c["crossing/heater"].phase.to_upper()
	chunk.quests=[{"text":"Cryo · remove heat from filled first tray","state":"done" if c["first/tray"].phase=="solid" else "active"},{"text":"Thermal supply → valve → fill both trays","state":"done" if c["supply/water"].amount==0 else "active"},{"text":"Disconnect heater → freeze both → latch → cross","state":"done" if _state.crossed else "active"}]
	chunk.tutorial="Professor teaches freezing before Cryo unlocks. First tray already holds water." if not DEVICE.has_lesson(store.data,DEVICE.MILESTONES.z1l3_freezing) else ("Select Cryo. Hold Fire on liquid water until SOLID / SECURED." if c["first/tray"].phase!="solid" else ("Reuse Thermal at supply court; open its valve to fill both empty bridge trays." if c["supply/water"].amount>0 else ("Disconnect heater. Cryo each filled tray. Operate latch only after both show SOLID." if c["crossing/latch"].phase!="latched" else "SECURED. Hop left ↔ right across small gap, then reach exit. Fixed frame keeps occupied support stable.")))
func _landed(origin: Vector2,destination: Vector2) -> void:
	if not _can_write() or _state.crossed or _state.components["crossing/latch"].phase!="latched":return
	var center: Vector2=points.court3
	var left:=Rect2(center+Vector2(-86,-24),Vector2(60,48));var right:=Rect2(center+Vector2(26,-24),Vector2(60,48))
	if ((left.has_point(origin) and right.has_point(destination)) or (right.has_point(origin) and left.has_point(destination))) and world.valid_landing(destination):
		var next:=_state.duplicate(true);next.crossed=true;_commit(next)
func _complete() -> bool:return not _state.is_empty() and _state.components["crossing/latch"].phase=="latched" and _state.crossed
func completion_authorized() -> bool:return _pending_finish and active() and _complete() and _near("exit")
func finish() -> bool:
	if not _complete() or not _near("exit"):return false
	_pending_finish=true;var okay: bool=store.finish_level("melting_and_freezing",3,[],world);_pending_finish=false
	if not okay:_failed()
	return okay
func _process(delta: float) -> void:
	if _fall_recovery:
		_retry=maxf(0,_retry-delta)
		if _retry==0:_save_death()
		return
	if not _can_write():return
	if store.data.active_run.state.get(RECORD)!=1 and not _commit(_state):return
	if DEVICE.has_lesson(store.data,DEVICE.MILESTONES.z1l3_freezing):discover("freezing","cooling_tool")
	if _state.death_pending:
		var next:=_state.duplicate(true);next.death_pending=false
		var events := []
		var checkpoint: String = snapshot().checkpoint_progress.latest_unlocked_checkpoint_id
		if checkpoint != "C0" and world.safe_ground.is_equal_approx(world.checkpoint_anchor(subregion_id,checkpoint)):
			events = _events([{"id":"safe_return","event":str(next.deaths),"members":[]}],"respawn")
		if not _commit(next,[],events):return
	_retry=maxf(0,_retry-delta)
	for target in targets.values():
		if is_instance_valid(target) and not target.is_committed() and _retry==0 and not target.verified_outcome(store,world).is_empty():commit_target(target)
	present()
func recover_world_fall() -> bool:
	if not active() or _state.is_empty():return false
	world.input_adapter.stop_all("stillwater_fall",true);world.dead=true;_fall_recovery=true;_death_saved=false;_retry=0;_save_death();return true
func _save_death() -> void:
	if not _death_saved:
		var next:=_state.duplicate(true);next.deaths+=1;next.death_pending=true;_death_saved=_commit(next)
		if not _death_saved:_retry=1;return
	_fall_recovery=false
	if not world.recover_world_checkpoint(world.access):_fall_recovery=true;world.dead=true;_retry=1
func world_checkpoints() -> Array:
	var result: Array=[]
	if _state.is_empty():return result
	for id in ["C0","C1","C2"]:result.append({"id":id,"name":id,"position":world.checkpoint_anchor("Z1L3",id),"attuned":_travel_allowed(id),"allowed":Callable(self,"_travel_allowed").bind(id)})
	return result
func _travel_allowed(id: String) -> bool:return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence
func world_travel_checkpoint(id: String) -> bool:return _travel_allowed(id) and world.activate("Z1L3",world.checkpoint_anchor("Z1L3",id))
func open_question() -> bool:
	_question_attempt=_attempt;world.input_adapter._begin_modal("stillwater_question");_show_question("");return true
func _show_question(feedback: String) -> void:
	world.panels.open_panel("guides.library",{"title":"Optional observation","body":"Does feeling cold mean your body changed from liquid into solid?\n\n"+feedback,"speaker":"professor_z1","search":false,"rows":[],"actions":[{"id":"stillwater_answer_yes","label":"Yes","enabled":true},{"id":"stillwater_answer_no","label":"No","enabled":true},{"id":"close","label":"Return to game","enabled":true}]})
func _question_intent(_panel: String,id: String,payload: Dictionary) -> void:
	if world.input_adapter.modal!="stillwater_question" or payload.get("view_revision")!=world.panels.revision or not active() or _question_attempt!=_attempt or id not in ["stillwater_answer_yes","stillwater_answer_no"] or not world._focused or world._suspended or world.dead:return
	_show_question(("Correct. " if id=="stillwater_answer_no" else "Try again. ")+"Feeling cold means heat is leaving your body. The liquid water in this tray froze into solid ice; feeling cold alone is not evidence of a phase change in your body.")
func _exit_tree() -> void:
	if is_instance_valid(world) and not _original_floors.is_empty():
		var retained: Array=world.models[0].floors.filter(func(record):return record.region!="Z1L3");retained.append_array(_original_floors);_reindex_floors(retained)
	for art in _reservation_art:
		if is_instance_valid(art):art.show()
	for art in _pit_art:
		if is_instance_valid(art):art.queue_free()
	super._exit_tree()
