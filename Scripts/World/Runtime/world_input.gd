extends Node
## Sole world HUD intent binding. View owns touch IDs; save/emitter/providers own authority.
const EMITTER=preload("res://Scripts/World/phase_device_emitter.gd")
const TEACHING=preload("res://Scripts/World/Learning/professor_content.gd")
const REDUCED_EFFECTS := "level1_reduced_effects"
var world: Node
var profile: Node
var view: Control
var panels: Control
var emitter: Node
var modal:=""
var feedback:=""
var _context: Dictionary={}
var _stopping:=false
var _fire_down:=false
var _paused_before:=false
var _clock:=0.0
var _focused:=true
var _suspended:=false
var _was_allowed:=false
var guide_preview: Control
var _learning_provider: Node
var _learning_attempt:=""
var _learning_key:=""
var _learning_topic:=""
var _explanation: Dictionary={}
var _deferred_explanations: Dictionary={}
var _offered_intros: Dictionary={}
var _panel_owner: Node
var _panel_handler: Callable
func bind(host: Node,store: Node,hud: Control,support: Control) -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	world=host;profile=store;view=hud;panels=support
	emitter=EMITTER.new();emitter.name="Emitter";add_child(emitter)
	emitter.bind(world.player,profile,allowed)
	view.preview_input=true # Exactly one raw touch acquisition surface, no old TouchControls/FireInput.
	view.movement_preview.connect(_move);view.hold_preview.connect(_hold)
	view.mode_requested.connect(select_mode);view.selector_canceled.connect(cancel_selector)
	view.action_requested.connect(action);panels.intent_requested.connect(_panel_intent)
	profile.changed.connect(_profile_changed);profile.restored.connect(_restored)
	world.subregion_changed.connect(_district_changed)
	refresh()
func allowed() -> bool:
	return is_instance_valid(world) and world.is_node_ready() and _focused and not _suspended and world.player_controls_allowed()
func _move(value: Vector2) -> void:
	if is_instance_valid(world):world.player.set_touch_movement(value if allowed() else Vector2.ZERO)
func _hold(id: String,held: bool) -> void:
	if id=="run":world.player.set_touch_sprinting(held and allowed() and not world.player.carrying)
	elif id=="fire":
		if held:
			if _fire_down:return
			_fire_down=true
			if allowed() and emitter.available() and not emitter.requires_release and not world.player.device_rig.requires_release:emitter.press()
		else:_fire_down=false;emitter.release()
func stop_all(cause: String,cancel_motion:=false) -> void:
	if _stopping or not is_instance_valid(view):return
	_stopping=true;view.reset_preview();_fire_down=false
	if is_instance_valid(emitter):emitter.interrupt(cause);emitter.release()
	world.player.set_touch_movement(Vector2.ZERO);world.player.set_touch_sprinting(false)
	if cancel_motion and world.player.is_node_ready():world.player.cancel_motion()
	_stopping=false
func select_mode(mode: String) -> void:
	if not allowed() or not profile.is_device_mode_unlocked(mode):return
	emitter.interrupt("mode_change")
	if not profile.select_device_mode(mode):feedback=profile.last_error
	else:feedback=""
	refresh()
func cancel_selector() -> void:
	# Cancel other pending mode touches too; releasing one cannot commit after center cancel.
	for id in view.pointers.keys():
		if view.pointers[id] in ["thermal","cryo","vacuum","pressure"]:view.route_touch(id,Vector2.ZERO,false,true)
	view.preview_mode="";feedback="";view.labels.feedback.text=""
func _profile_changed() -> void:
	if is_instance_valid(emitter):emitter.interrupt("profile_changed")
	refresh()
func _restored() -> void:
	close_panel()
	_deferred_explanations.clear()
	_offered_intros.clear()
	stop_all("profile_restored",true);refresh()

func _district_changed(id: String) -> void:
	if is_instance_valid(_learning_provider) and _learning_provider.subregion_id != id:
		interrupt_learning()
	elif modal == "provider" and _panel_owner != world.learning_provider():
		interrupt_learning()

func interrupt_learning() -> void:
	if modal in ["lesson","explanation","provider","optional_activity","mill_question","stillwater_question"]:
		close_panel()
func _current_context() -> Dictionary:
	var chunk: Node=world.active_chunk()
	if chunk==null:return {}
	var record: Dictionary=chunk.context_record().duplicate()
	var target=record.get("target")
	if not is_instance_valid(target) or not target is Node2D or not target.is_inside_tree() or target.is_queued_for_deletion():return {}
	if not chunk.is_ancestor_of(target) or str(record.get("key","")).is_empty():return {}
	record.identity=chunk.chunk_id+":"+str(target.get_instance_id())+":"+str(record.key)
	return record
func interact() -> bool:
	if not allowed():return false
	var current:=_current_context()
	if current.is_empty() or current.get("key")!=_context.get("key") or current.target!=_context.get("target") or not current.get("enabled",false):return false
	var invoke: Callable=current.get("invoke",Callable())
	if not invoke.is_valid():return false
	# Recheck domain predicate at release, not only the last rendered state.
	var gate: Callable=current.get("allowed",Callable())
	if not gate.is_valid() or not gate.call():return false
	var result: bool=invoke.call();refresh();return result
func action(id: String) -> void:
	if not allowed():return
	match id:
		"jump":world.player.request_jump()
		"interact":interact()
		"guides":open_panel("guides")
		"pause":open_panel("pause")
func refresh() -> void:
	if not is_instance_valid(view) or not view.is_node_ready() or not is_instance_valid(world.player):return
	var chunk: Node=world.active_chunk();_context=_current_context()
	var actor: Node2D=world.player
	var enabled:=allowed()
	var context_point: Vector2=_context.target.get_global_transform_with_canvas().origin if not _context.is_empty() else view.size/2
	var context_gate: Callable=_context.get("allowed",Callable())
	view.present({"name":profile.data.get("player_name","Explorer"),"hp":world.hp,"warmth":world.warmth,"device":profile.device_state(),"quests":chunk.quests if chunk else [],"quest_title":"Current objective","tutorial":chunk.tutorial if chunk else "","feedback":feedback,"modal":not modal.is_empty() or not _focused or _suspended or world.dead or world.hp<=0,"run_enabled":enabled and not actor.carrying,"jump_enabled":enabled and not actor.carrying and actor.jump_elapsed<0 and actor.action_elapsed<0 and actor.context_progress<0,"fire_enabled":enabled and emitter.available() and not emitter.requires_release and not actor.device_rig.requires_release,"context":_context.get("caption",""),"context_key":str(_context.get("identity","")),"context_enabled":enabled and _context.get("enabled",false) and context_gate.is_valid() and context_gate.call(),"context_at":context_point,"reduced_effects":profile.data.get("extras",{}).get("level1_reduced_effects",false),"minimap":{"heading":Vector2.DOWN.angle_to(Vector2.RIGHT.rotated(actor.DIRECTIONS.find(actor._facing)*PI/4))}})
func _begin_modal(kind: String) -> void:
	if modal.is_empty():_paused_before=get_tree().paused
	stop_all("modal",true);modal=kind;get_tree().paused=true;refresh()
func open_lesson(topic: String,milestone_id: String="") -> bool:
	var provider: Node=world.learning_provider()
	if not allowed() or provider==null or not provider.active():return false
	var content: Dictionary=provider.lesson(topic)
	if not content.get("available",false):return false
	_learning_provider=provider;_learning_attempt=provider.achievement_events.attempt_id;_learning_key=milestone_id;_learning_topic=topic
	_begin_modal("lesson")
	panels.open_panel("guides.library",{"title":content.title,"speaker":content.role,"expression":"explaining","body":"\n\n".join(content.paragraphs),"search":false,"rows":[],"actions":[{"id":"lesson_ack","label":"Continue","enabled":true}]})
	return true
func offer_intro(topic: String,milestone_id: String) -> void:
	var attempt: String = profile.data.active_run.get("attempt_id","")
	var key := attempt + ":" + milestone_id
	if not _offered_intros.has(key) and open_lesson(topic,milestone_id):
		_offered_intros[key] = true

func pending_feedback(include_deferred := false) -> Dictionary:
	# Retain provider overrides for existing adapters with injected teaching contracts.
	var provider: Node = world.learning_provider()
	for entry: Dictionary in profile.pending_explanations():
		if not include_deferred and _deferred_explanations.has(entry.type): continue
		var authored: Dictionary = {}
		if provider != null and TEACHING.region_for(entry.instance_id.get_slice(":",0),entry.instance_id.get_slice(":",1).to_int()) == provider.subregion_id:
			authored = provider.contract.get("explanations",{})
		var content := TEACHING.explanation(entry,authored)
		if content.get("available",false): return content
	return {}

func _show_pending_explanation(include_deferred := false) -> void:
	if world.demonstration_mode or world.player.jump_elapsed>=0 or world.player.action_elapsed>=0 or world.player.carrying:return
	if profile.WORLD_SAVE.truth(profile.data.active_run.get("state",{}).get("death_pending")): return
	var content := pending_feedback(include_deferred)
	if content.is_empty(): return
	_explanation = content
	_begin_modal("explanation")
	panels.open_panel("guides.library",{"title":"What changed?","speaker":content.role,"expression":"explaining","body":content.text,"search":false,"rows":[],"actions":[{"id":"explanation_ack","label":"Understood","enabled":true}]})

func _dismiss_panel() -> void:
	if modal == "explanation": _deferred_explanations[_explanation.type] = true
	close_panel()

func close_panel() -> void:
	if modal.is_empty():return
	_clear_preview()
	_panel_owner=null;_panel_handler=Callable()
	_learning_provider=null;_learning_attempt="";_learning_key="";_learning_topic="";_explanation={}
	panels.hide();modal="";get_tree().paused=_paused_before;stop_all("modal_closed");refresh()
func open_provider_panel(owner: Node,handler: Callable,layout: String,model: Dictionary) -> bool:
	if owner != world.learning_provider() or not is_instance_valid(owner) or not owner.active() or not handler.is_valid():
		return false
	if not (allowed() or (modal == "provider" and _panel_owner == owner)):
		return false
	if not panels.open_panel(layout,model):
		return false
	_panel_owner=owner;_panel_handler=handler
	_begin_modal("provider")
	return true
func open_optional_activity(title: String,objective: String,cue: String) -> bool:
	if not allowed():return false
	if not panels.open_panel("guides.library",{"title":title,"body":objective+"\n\n"+cue,"rows":[],"search":false,"actions":[]}):return false
	_begin_modal("optional_activity")
	return true
func open_panel(kind: String) -> void:
	if not world.is_node_ready():return
	_clear_preview()
	_begin_modal(kind)
	var rows: Array=[]
	var actions: Array=[{"id":"return","label":"Back to Pause","enabled":true}]
	match kind:
		"pause":
			panels.open_panel("pause.open",{"rows":[{"title":"Objectives","text":"Full current task list","action":"objectives"},{"title":"Guides","text":"Discovered learning references","action":"guides"},{"title":"Journal","text":"Retained discoveries and progress","action":"journal"},{"title":"Checkpoint map","text":"Previously attuned local destinations","action":"travel"},{"title":"Settings","text":"Audio and accessibility","action":"settings"}],"actions":[{"id":"resume","label":"Resume","enabled":true},{"id":"save_menu","label":"Save & Menu","enabled":true}]})
		"objectives":
			var chunk: Node=world.active_chunk()
			if chunk:
				for quest in chunk.quests:rows.append({"title":quest.get("text",""),"text":quest.get("state","active")})
			panels.open_panel("journal.empty",{"title":"Current objectives","body":"All tasks remain accessible here.","rows":rows,"actions":actions})
		"guides":
			if not pending_feedback(true).is_empty():
				rows.append({"title":"First-success feedback","text":"Review pending explanations","action":"review_feedback"})
			for key in profile.guide_records():
				var record: Dictionary=profile.guide_records()[key]
				var guide := TEACHING.guide(record)
				var district := TEACHING.REGISTRY.definition(TEACHING.region_for(record.zone,record.level))
				rows.append({"id":key,"title":guide.title,"text":district.get("name",""),"action":"open_guide"})
			panels.open_panel("guides.library",{"title":"Guides","body":"Free lessons and demonstrations","rows":rows,"search":false,"actions":actions})
		"journal":
			var journal: Dictionary = panels.journal_model(profile)
			journal.actions = actions
			panels.open_panel("journal.empty",journal)
		"travel":
			var chunk: Node=world.active_chunk()
			if chunk:
				for checkpoint in chunk.checkpoint_records():rows.append({"id":str(checkpoint.id),"title":str(checkpoint.get("name",checkpoint.id)),"text":"Attuned" if checkpoint.get("attuned",false) else "Not attuned","action":"request_travel","enabled":checkpoint.get("attuned",false)})
			panels.open_panel("travel.known",{"title":"Checkpoint map","body":"Local attuned checkpoints only. Selecting a location never attunes or unlocks it.","rows":rows,"status":"" if rows.size()>0 else "No attuned destinations available.","actions":actions})
			if chunk:
				var map=preload("res://Scripts/UI/WorldHUD/checkpoint_map.gd").new();panels.body.add_child(map);panels.body.move_child(map,1)
				map.present(chunk.ground_polygons(),chunk.checkpoint_records(),world.player.position)
				var token: int=panels.revision
				map.checkpoint_requested.connect(func(id):
					if modal=="travel" and token==panels.revision:_travel(id))
		"settings":
			var audio:=get_node("/root/GameAudio")
			panels.open_panel("settings.default",{
				"settings":[
					{"id":"music","label":"Music","value":audio.music_enabled},
					{"id":"sfx","label":"Sound effects","value":audio.sfx_enabled},
					{"id":"reduced_effects","label":"Reduced effects","value":profile.data.extras.get(REDUCED_EFFECTS,false)}
				],
				"actions":actions
			})
func _set_reduced_effects(value: bool) -> void:
	var extras: Dictionary = profile.data.extras
	var had_setting := extras.has(REDUCED_EFFECTS)
	var previous: Variant = extras.get(REDUCED_EFFECTS)
	extras[REDUCED_EFFECTS] = value
	if profile.save_profile(): return
	if had_setting:
		extras[REDUCED_EFFECTS] = previous
	else:
		extras.erase(REDUCED_EFFECTS)
	open_panel("settings")
	panels.status.text = "Reduced effects could not be saved. Try again."
	panels.status.show()
func _open_guide(key: String) -> void:
	var record: Dictionary=profile.guide_records().get(key,{})
	if record.is_empty():return
	_clear_preview()
	var guide := TEACHING.guide(record)
	guide.actions = [{"id":"guides","label":"Back to Guides","enabled":true}]
	panels.open_panel("guides.library",guide)
	guide_preview = TEACHING.preview(record)
	panels.attach_guide_demo(guide_preview)
func _clear_preview() -> void:
	if is_instance_valid(guide_preview):guide_preview.queue_free()
	guide_preview=null
func _travel(id: String) -> bool:
	if modal!="travel" or not _focused or _suspended or world.dead or world.hp<=0:return false
	var chunk: Node=world.active_chunk()
	if chunk==null or not is_instance_valid(chunk.checkpoint_provider):return false
	for checkpoint in chunk.checkpoint_records():
		if str(checkpoint.id)==id and checkpoint.get("attuned",false) and chunk.checkpoint_provider.has_method("world_travel_checkpoint"):
			var gate: Callable=checkpoint.get("allowed",Callable())
			if gate.is_valid() and gate.call() and chunk.checkpoint_provider.world_travel_checkpoint(id):close_panel();return true
	return false
func _panel_intent(_panel: String,id: String,payload: Dictionary) -> void:
	if modal.is_empty() or payload.get("view_revision")!=panels.revision or not _focused or _suspended or world.dead or world.hp <= 0:return
	if modal=="provider" and id!="close":
		if _focused and not _suspended and is_instance_valid(_panel_owner) and _panel_owner==world.learning_provider() and _panel_owner.active() and _panel_handler.is_valid():
			_panel_handler.call(id,payload)
		return
	if id == "explanation_ack" and modal == "explanation":
		if profile.acknowledge_explanation(_explanation.type):
			close_panel()
		else:
			panels.status.text = "Acknowledgement could not be saved. Try again."
			panels.status.show()
		return
	if id == "lesson_ack" and modal == "lesson":
		if not is_instance_valid(_learning_provider) or not _learning_provider.active() or _learning_attempt!=_learning_provider.achievement_events.attempt_id:return
		var provider := _learning_provider
		var milestone := _learning_key
		var topic := _learning_topic
		close_panel()
		var saved: bool = provider.acknowledge_help(topic) if milestone.is_empty() else provider.introduce(milestone)
		if not saved and open_lesson(topic,milestone):
			panels.status.text = "Learning progress could not be saved. Try again."
			panels.status.show()
		return
	match id:
		"save_menu":world.save_and_menu()
		"close","resume":_dismiss_panel()
		"return":open_panel("pause")
		"guides","journal","travel","settings","objectives":open_panel(id)
		"open_guide":_open_guide(str(payload.get("value","")))
		"review_feedback":
			close_panel()
			if allowed(): _show_pending_explanation(true)
		"request_travel":_travel(str(payload.get("value","")))
		"setting":
			var setting := str(payload.get("setting_id",""))
			var value := bool(payload.get("value",false))
			if setting in ["music","sfx"]:
				get_node("/root/GameAudio").set_enabled(setting,value)
			elif setting=="reduced_effects" and modal=="settings":
				_set_reduced_effects(value)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:return
	if event.physical_keycode==KEY_ESCAPE and event.pressed:
		if modal.is_empty():action("pause")
		else:_dismiss_panel()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_F:
		_hold("fire",event.pressed);get_viewport().set_input_as_handled()
	elif event.pressed and event.physical_keycode==KEY_E:action("interact");get_viewport().set_input_as_handled()
	elif event.pressed and event.physical_keycode==KEY_G:action("guides");get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not is_instance_valid(world):return
	if world.dead or world.hp <= 0: close_panel()
	var enabled:=allowed()
	if _was_allowed and not enabled:stop_all("input_blocked",true)
	elif not enabled and (_fire_down or not world.player.touch_movement.is_zero_approx() or world.player.touch_sprinting):stop_all("input_blocked")
	_was_allowed=enabled
	if enabled and modal.is_empty():_show_pending_explanation()
	_clock+=delta
	if _clock>=0.08:_clock=0;refresh()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_focused=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:_suspended=true
	elif what==NOTIFICATION_APPLICATION_RESUMED:_suspended=false
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE] and is_instance_valid(world):stop_all("lifecycle",true)
