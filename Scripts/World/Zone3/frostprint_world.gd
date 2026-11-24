extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/frostprint_assembly.gd")
const REGION := PARTS.FROSTPRINT
const CHECKPOINTS := ["C0","C1","C2"]
const RESERVES := ["deposition_empty","dew_comparison_warm","optical_sensor_below","lab_valve_closed","lab_gate_closed"]
const FROST_TARGETS := [PARTS.FIRST,PARTS.COMPARE,PARTS.OPTICAL]
const LABEL_OFFSETS := {
	"sink":Vector2(-55,30),"first_sensor":Vector2(-42,2),"dry_sensor":Vector2(-47,-2),
	"compare":Vector2(-58,32),"inlet":Vector2(-36,-10),
}
const QUESTION := {
	"choices":["Yes. Any ice on a cold plate is deposition.","No. Droplets form by condensation and then freeze."],
	"correct":1,"feedback":"The dew pane detected liquid. The frost collector detected solid ice with zero liquid. Direct deposition skips the liquid phase.",
}

var points := {}
var _professor: Marker2D
var _labels := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _gate: Dictionary
var _gate_sprite: Sprite2D
var _growth_stage := {}

func bind_frostprint(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	# Service faces sit on the courts' flat terraces. The gate keeps its authored anchor.
	points.merge({
		"first":points.court1+Vector2(40,112),"cover":points.court1+Vector2(-28,139),
		"gauge":points.court1+Vector2(51,167),"sink":points.court1+Vector2(104,114),
		"first_sensor":points.court1+Vector2(-35,85),"dry_sensor":points.court1+Vector2(90,56),
		"dew":points.court2+Vector2(-112,39),"frost":points.court2+Vector2(-57,123),"compare":points.court2+Vector2(-1,110),
		"optical":points.court3+Vector2(-127,-84),"optical_sensor":points.court3+Vector2(-45,-71),
		"inlet":points.court3+Vector2(-120,-12),
	})
	if not bind(host,get_parent(),PARTS.frostprint_definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	_professor = Marker2D.new()
	_professor.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_professor)
	for id in ["cover","gauge","sink","first","first_sensor","dry_sensor","dew","frost","compare","optical","optical_sensor","inlet","gate","exit"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = LABEL_OFFSETS.get(id,Vector2(-72,8))
		label.size.x = 144
		label.z_index = 1
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		var visuals: Node = _gate_sprite.get_parent() if id == "gate" else component(id+"/control").visuals
		visuals.add_child(label)
		_labels[id] = label
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if not placement.station.begins_with(REGION+".court") or placement.asset not in RESERVES:
			continue
		var at: Vector2 = model.v(placement.at)
		if placement.asset == "lab_gate_closed":
			points.gate = at
		for prop in world.props:
			if (prop.get_meta("station_id","") == placement.station and prop.get_meta("asset_id","") == placement.asset
					and prop.position.distance_to(at) < 1):
				if placement.asset == "lab_gate_closed":
					_gate_sprite = prop.visuals.get_node("Artwork")
				else:
					prop.hide()
					_hidden_reserves.append(prop)
		for record in model.blockers:
			if (record.get("station","") != placement.station or record.bounds.get_center().distance_to(at) >= 1
					or not is_instance_valid(record.get("body"))):
				continue
			if placement.asset == "lab_gate_closed":
				_gate = record
			else:
				record.layer = 0
				record.body.collision_layer = 0
				_disabled_reserves.append(record)

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _set_phase(state: Dictionary, id: String, value: String) -> void:
	state.components[id+"/control"].phase = value

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not raw.items.is_empty():
		return false
	var first := phase(raw,"first")
	var dew := phase(raw,"dew")
	var frost := phase(raw,"frost")
	var compare := phase(raw,"compare")
	var inlet := phase(raw,"inlet")
	var optical := phase(raw,"optical")
	var sealed := phase(raw,"cover") == "sealed"
	var regulated := phase(raw,"gauge") == "regulated"
	var cooled := phase(raw,"sink") == "on"
	return ((first == "empty" or sealed) and (not regulated or first != "empty") and (not cooled or regulated)
		and (first != "solid" or cooled) and phase(raw,"first_sensor") == ("solid" if first == "solid" else "empty")
		and (dew == "empty") == (frost == "empty") and (dew == "empty") == (compare == "idle")
		and (compare == "idle" or first == "solid")
		and (compare not in ["retry","accepted"] or (dew == "liquid" and frost == "solid"))
		and (inlet == "closed" or compare == "accepted")
		and ((inlet == "closed" and optical == "empty") or (inlet == "open" and optical in ["gas","solid"])
			or (inlet == "isolated" and optical == "isolated"))
		and phase(raw,"optical_sensor") == ("target" if optical in ["solid","isolated"] else "below")
		and (phase(raw,"exit") != "recorded" or inlet == "isolated"))

func gate_open(state: Dictionary) -> bool:
	return phase(state,"inlet") == "isolated"

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		_set_phase(result[STATE_KEY],"exit","recorded")
	var earned := ["C0"]
	if phase(state,"first") == "solid":
		earned.append("C1")
	if phase(state,"compare") == "accepted":
		earned.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,earned)
	result.checkpoint = earned.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _near(id: String) -> bool:
	var ground: Vector2 = world.player.position
	var at: Vector2 = points[id]
	if ground.distance_to(at) > 43 or not world.world_contact_allowed(ground,at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if assemblies.has(id) and assemblies[id].bodies.has("control"):
		exclude.append(assemblies[id].bodies.control.get_rid())
	var query := PhysicsRayQueryParameters2D.create(ground,at,1|8,exclude)
	query.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _lesson_seen() -> bool:
	return DEVICE.has_lesson(store.data,DEVICE.MILESTONES[PARTS.INTRO])

func introduce(milestone_id: String) -> bool:
	if action_allowed("professor") and super.introduce(milestone_id):
		return true
	_feedback("The lesson could not be saved. Ask Professor Aster again.")
	last_error = world.input_adapter.feedback
	return false

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and not world.player.carrying and world.player.jump_elapsed < 0
			and world.player.action_elapsed < 0 and _near(id))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"seal": return _lesson_seen()
		"split": return _verified(PARTS.FIRST)
		"compare": return _verified(PARTS.DEW) and _verified(PARTS.COMPARE)
		"feed": return _comparison_verified(_state)
		"stop": return _comparison_verified(_state) and _verified(PARTS.OPTICAL)
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_professor) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Aster","target":_professor,"enabled":true,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func sample_for(id: String) -> Dictionary:
	var result := super.sample_for(id)
	result.amount = 1 if result.state == "gas" else 0
	if id == PARTS.DEW:
		result.pressure_regime = "normal"
		result.pane_c = PARTS.PANE_C
		result.dew_point_c = PARTS.DEW_POINT_C
		return result
	var pressure_ready := phase(_state,"gauge") == "regulated"
	var cooled := phase(_state,"sink") == "on"
	result.merge({"sealed":phase(_state,"cover") == "sealed","instrumented":true,
		"temperature_controlled":cooled,"pressure_regime":"high" if pressure_ready else "normal",
		"liquid_present":false,"phase_region":"gas_solid" if pressure_ready and cooled else "unqualified",
		"heat_flow":"out" if cooled else "none"},true)
	return result

func _verified(id: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var process: String = PARTS.PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	return records is Dictionary and records.get(id) == {"version":1,"id":id,"material":"water","process":process,
		"from_state":rule.from,"to_state":rule.to,"capability":rule.capability,"puzzle_type":rule.type}

func _comparison_verified(state: Dictionary) -> bool:
	return phase(state,"compare") == "accepted" and _verified(PARTS.FIRST) and _verified(PARTS.DEW) and _verified(PARTS.COMPARE)

func _completion_ready(state: Dictionary) -> bool:
	return gate_open(state) and _comparison_verified(state) and _verified(PARTS.OPTICAL)

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("deposition",PARTS.INTRO)
		"compare": return _show_question()
		"exit":
			if finish():
				return true
			_feedback("The Frostprint result could not be saved. Record it again.")
			return false
	world.input_adapter.stop_all("frostprint_action",true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var action: Dictionary = contract.actions[id]
	next.components[action.component].phase = action.value
	match id:
		"split":
			_set_phase(next,"dew","gas")
			_set_phase(next,"frost","gas")
		"feed": _set_phase(next,"optical","gas")
		"stop":
			_set_phase(next,"optical","isolated")
	if not _save(next):
		return false
	if id == "stop":
		_feedback("Inlet closed. Gate open.")
	return true

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var next := _state.duplicate(true)
	next.components[contract.targets[outcome.id].component].phase = outcome.to_state
	var events := []
	match outcome.id:
		PARTS.FIRST:
			_set_phase(next,"first_sensor","solid")
			events = [{"id":"frost_from_air","members":[]},{"id":"six_changes","members":["deposition"]},
				{"id":"field_notes","members":["deposition"]}]
		PARTS.OPTICAL: _set_phase(next,"optical_sensor","target")
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	present()
	_feedback("The sensor reading could not be saved. Apply the device again.")
	return false

func _show_question(feedback := "") -> bool:
	var actions := []
	for index in QUESTION.choices.size():
		actions.append({"id":str(index),"label":QUESTION.choices[index]})
	return world.input_adapter.open_provider_panel(self,_answer_comparison,"guides.library",{
		"title":"Is frozen dew direct deposition?","speaker":"professor_z3",
		"body":feedback+"\n\nDew pane · liquid detected at +8°C\nCold collector · solid detected, liquid stayed at 0",
		"rows":[],"search":false,"actions":actions})

func _answer_comparison(id: String, _payload: Dictionary) -> void:
	if not id.is_valid_int():
		return
	var answer := CONTENT.answer(REGION,QUESTION,id.to_int())
	if answer.is_empty():
		return
	world.input_adapter.close_panel()
	if not action_allowed("compare"):
		return
	var next := _state.duplicate(true)
	_set_phase(next,"compare","accepted" if answer.correct else "retry")
	var successes := []
	if answer.correct:
		successes.append({"puzzle":"frostprint_dew_or_frost","type":"condense_deposit_compare",
			"topic":"deposition","object":"frostprint_comparison_readings"})
	if not _save(next,successes):
		return
	if answer.correct:
		_feedback("Comparison verified.")
	else:
		_show_question(answer.feedback)

func _save(next: Dictionary, successes := []) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,[],world):
		return true
	_feedback("The chamber settings could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var first := phase(state,"first")
	var dew := phase(state,"dew")
	var frost := phase(state,"frost")
	var comparison := phase(state,"compare")
	var inlet := phase(state,"inlet")
	var optical := phase(state,"optical")
	var observed := phase(state,"optical_sensor") == "target"
	var open_gate := gate_open(state)
	var done := phase(state,"exit") == "recorded"
	if not _gate.is_empty() and is_instance_valid(_gate.body):
		_gate.layer = 0 if open_gate else _gate.original_layer
		_gate.body.set_deferred("collision_layer",_gate.layer)
	_artwork(_gate_sprite,"lab_gate_open" if open_gate else "lab_gate_closed")
	_labels.cover.text = "SEALED" if phase(state,"cover") == "sealed" else "COLLECTORS OPEN"
	_labels.gauge.text = "PRESSURE REGULATED" if phase(state,"gauge") == "regulated" else "NORMAL PRESSURE"
	_labels.sink.text = "HEAT OUT" if phase(state,"sink") == "on" else "HEAT REMOVAL OFF"
	_labels.first.text = {"empty":"FIRST FROST","gas":"WATER VAPOR","solid":"GAS → SOLID"}[first]
	_labels.first_sensor.text = "SOLID %d" % int(first == "solid")
	_labels.dry_sensor.text = "LIQUID 0"
	_labels.dew.text = {"empty":"DEW PANE","gas":"VAPOR · NORMAL PRESSURE","liquid":"+8°C · LIQUID 1"}[dew]
	_labels.frost.text = {"empty":"COLD COLLECTOR","gas":"WATER VAPOR","solid":"SOLID 1 · LIQUID 0"}[frost]
	_labels.compare.text = {"idle":"COMPARE BOTH PATHS","fed":"READ BOTH SENSORS","retry":"COMPARE · RETRY","accepted":"COMPARISON VERIFIED"}[comparison]
	_labels.optical.text = {"empty":"OPTICAL COLLECTOR","gas":"WATER VAPOR","solid":"TARGET HELD","isolated":"FROST ISOLATED"}[optical]
	_labels.optical_sensor.text = "OPTICAL %d/%d" % [PARTS.TARGET_MARK if observed else 0, PARTS.TARGET_MARK]
	_labels.inlet.text = "INLET OPEN" if inlet == "open" else "INLET CLOSED"
	_labels.gate.text = "OBSERVATION GATE OPEN" if open_gate else "OBSERVATION GATE CLOSED"
	_labels.exit.text = "FROSTPRINT RECORDED" if done else "FROSTPRINT DESK"
	var task := "Ask Professor Aster about deposition"
	if _lesson_seen(): task = "First Frost · seal the collectors"
	if phase(state,"cover") == "sealed": task = "First Frost · feed water vapor"
	if first == "gas": task = "First Frost · set regulated pressure"
	if phase(state,"gauge") == "regulated": task = "First Frost · start heat removal"
	if phase(state,"sink") == "on": task = "First Frost · use Pressure at the collector"
	if first == "solid": task = "Comparison bench · feed both vapor lines"
	if dew != "empty": task = "Cryo at dew pane · Pressure at cold collector"
	if dew == "liquid" and frost == "solid": task = "Comparison bench · compare the two readings"
	if comparison == "accepted": task = "Frost Signal · open the optical vapor inlet"
	if optical == "gas": task = "Frost Signal · grow frost to the optical line"
	if optical == "solid": task = "Target reached · close the optical vapor inlet"
	if open_gate: task = "Frostprint desk · record the result"
	chunk.quests = [{"text":"Frostprint result recorded" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func present() -> void:
	super.present()
	if not _state.is_empty():
		_growth_stage.clear()
		_apparatus(_state)

func _process(_delta: float) -> void:
	if not _can_write() or _labels.is_empty():
		return
	for id in FROST_TARGETS:
		var target: Node = targets.get(id)
		if not is_instance_valid(target) or target.is_committed() or target.exposure() <= 0:
			continue
		var fraction: float = target.exposure()/target.definition().required_exposure
		var stage := 1 if fraction < .55 else 2
		if _growth_stage.get(id) == stage:
			continue
		_growth_stage[id] = stage
		var key: String = contract.targets[id].component
		var sprite: Sprite2D = component(key).visuals.get_node("Artwork")
		_artwork(sprite,"deposition_early_frost" if stage == 1 else "deposition_growing")
		_labels[key.get_slice("/",0)].text = "FROST GROWING · LIQUID 0"
		if id == PARTS.OPTICAL:
			_labels.optical_sensor.text = "OPTICAL %d/%d" % [stage,PARTS.TARGET_MARK]

func _artwork(sprite: Sprite2D, id: String) -> void:
	var art := PARTS.art(id)
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE*float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	var state: Dictionary = raw if _supported_state(raw) else default_state()
	for assembly in assemblies.values():
		assembly.present(state.components,state.items)
	_apparatus(state)

func _checkpoint_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and id in snapshot().checkpoint_progress.unlock_sequence

func world_checkpoints() -> Array:
	var result := []
	for id in CHECKPOINTS:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor(REGION,id),
			"attuned":_checkpoint_allowed(id),"allowed":_checkpoint_allowed.bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _checkpoint_allowed(id) and world.activate(REGION,world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	var blockers := _disabled_reserves.duplicate()
	if not _gate.is_empty():
		blockers.append(_gate)
	for record in blockers:
		record.layer = record.original_layer
		if is_instance_valid(record.body):
			record.body.set_deferred("collision_layer",record.layer)
	for prop in _hidden_reserves:
		if is_instance_valid(prop):
			prop.show()
	if is_instance_valid(_gate_sprite):
		_artwork(_gate_sprite,"lab_gate_closed")
	if is_instance_valid(_labels.get("gate")):
		var gate_label: Label = _labels.gate
		gate_label.hide()
		gate_label.queue_free()
	if is_instance_valid(_professor):
		_professor.queue_free()
	super._exit_tree()
