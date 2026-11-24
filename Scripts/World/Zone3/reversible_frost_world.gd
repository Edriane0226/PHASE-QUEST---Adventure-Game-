extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/reversible_frost_assembly.gd")
const REGION := PARTS.CIRCUIT
const STEP = PARTS.Step
const CHECKPOINTS := ["C0","C1","C2"]
const BENCHES := ["source","a","b"]
const BENCH_NAMES := {"source":"Source","a":"Collector A","b":"Collector B"}
const RESERVES := ["sublimation_solid","deposition_empty","receiver_a_empty","phase_sensor_gas_empty",
	"frost_removal_0","receiver_b_empty","reversible_circuit_disconnected","lab_valve_closed","optical_sensor_below"]
const PRESSURE_TEXT := {"standby":"NORMAL PRESSURE","sublime":"LOW PRESSURE","deposit":"REGULATED PRESSURE"}
const HEAT_TEXT := {"standby":"HEAT OFF","sublime":"HEAT IN","deposit":"HEAT OUT"}
const GAUGE_LABEL_OFFSETS := {
	"source_gauge":Vector2(14,29),"a_gauge":Vector2(20,-10),"b_gauge":Vector2(-116,-16),
}
const PROGRESS_ART := {
	PARTS.SOURCE:["sublimation_shrinking_early","sublimation_shrinking_late"],
	PARTS.FIRST:["deposition_early_frost","deposition_growing"],
	PARTS.RETURN:["frost_removal_1","frost_removal_2"],
	PARTS.FINAL:["deposition_early_frost","deposition_growing"],
}
const QUESTION := {
	"choices":["Water vapor","Liquid water","Pieces of ice"],"correct":0,
	"feedback":"The sealed line carried water vapor. The source lost its captured gas when A received it. The liquid reading stayed at zero.",
}

var points := {}
var _professor: Marker2D
var _labels := {}
var _lines := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _visible_growth := {}

func bind_reversible_frost(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	# Keep each independently assembled piece on a measured, level footprint.
	points.merge({
		"source":points.court1+Vector2(0,35),"source_valve":points.court1+Vector2(-85,60),
		"source_gauge":points.court1+Vector2(12,100),"source_heat":points.court1+Vector2(77,60),
		"source_sensor":points.court1+Vector2(80,2),
		"a":points.court2+Vector2(65,-118),"a_valve":points.court2+Vector2(7,-153),
		"a_gauge":points.court2+Vector2(69,-39),"a_heat":points.court2+Vector2(130,-79),
		"a_sensor":points.court2+Vector2(136,-129),
		"b":points.court3+Vector2(-120,-80),"b_valve":points.court3+Vector2(-181,-48),
		"b_gauge":points.court3+Vector2(-123,-7),"b_heat":points.court3+Vector2(-59,-25),
		"b_sensor":points.court3+Vector2(-61,-114),
	})
	if not bind(host,get_parent(),PARTS.circuit_definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	_professor = Marker2D.new()
	_professor.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_professor)
	for id in assemblies:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-70,8)
		if GAUGE_LABEL_OFFSETS.has(id): label.position = GAUGE_LABEL_OFFSETS[id]
		if id.ends_with("_heat"): label.position.y = 22
		label.size.x = 140
		label.z_index = 1
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	for bench in BENCHES:
		var valve: Node2D = component(bench+"_valve/control")
		var vessel: Node2D = component(bench+"/control")
		var offset := valve.position-vessel.position-Vector2(0,valve.elevation-vessel.elevation)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2.ZERO,Vector2(offset.x*.5,offset.y),offset])
		line.width = 4.0
		line.z_index = -1
		line.antialiased = true
		vessel.visuals.add_child(line)
		_lines[bench] = line
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if not placement.station.begins_with(REGION+".court") or placement.asset not in RESERVES:
			continue
		var at: Vector2 = model.v(placement.at)
		for prop in world.props:
			if (prop.get_meta("station_id","") == placement.station and prop.get_meta("asset_id","") == placement.asset
					and prop.position.distance_to(at) < 1):
				prop.hide()
				_hidden_reserves.append(prop)
		for record in model.blockers:
			if (record.get("station","") == placement.station and record.bounds.get_center().distance_to(at) < 1
					and is_instance_valid(record.get("body"))):
				record.layer = 0
				record.body.collision_layer = 0
				_disabled_reserves.append(record)

func default_state() -> Dictionary:
	var result := super.default_state()
	result.step = STEP.SOURCE_ICE
	return result

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _set_phase(state: Dictionary, id: String, value: String) -> void:
	state.components[id+"/control"].phase = value

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not raw.items.is_empty() or not raw.get("step") is int:
		return false
	var step: int = raw.step
	var valve := phase(raw,"source_valve")
	return (step in range(STEP.SOURCE_ICE,STEP.ONLINE+1) and valve in ["open","sealed"]
		and (step == STEP.SOURCE_ICE or (valve == "sealed" and phase(raw,"source_gauge") == "sublime"))
		and (step < STEP.A_RETURN_GAS or phase(raw,"a_gauge") == "sublime")
		and (step < STEP.B_FROST or phase(raw,"b_gauge") == "deposit"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].step = STEP.ONLINE
	var earned := ["C0"]
	if state.step >= STEP.A_GAS: earned.append("C1")
	if state.step >= STEP.A_FROST: earned.append("C2")
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

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and not world.player.carrying and world.player.jump_elapsed < 0
			and world.player.action_elapsed < 0 and _near(id))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"source_gauge": return _state.step == STEP.SOURCE_ICE
		"source_valve": return _state.step <= STEP.SOURCE_GAS
		"a_gauge": return _state.step >= STEP.A_GAS and _state.step <= STEP.A_ISOLATED
		"a_valve": return _state.step >= STEP.A_GAS and _state.step <= STEP.A_RETURN_GAS
		"b_gauge": return _state.step == STEP.B_GAS
		"question": return _state.step >= STEP.A_GAS
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return false

func world_context() -> Dictionary:
	if is_instance_valid(_professor) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Aster","target":_professor,"enabled":true,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func _verified(id: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var process: String = PARTS.PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	return records is Dictionary and records.get(id) == {"version":1,"id":id,"material":"water","process":process,
		"from_state":rule.from,"to_state":rule.to,"capability":rule.capability,"puzzle_type":rule.type}

func _has_receipts(count: int) -> bool:
	return PARTS.RECEIPT_ORDER.slice(0,count).all(_verified)

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	var bench: String = PARTS.TARGET_BENCH[id]
	var condition := phase(_state,bench+"_gauge")
	var settings: Array = PARTS.CONDITIONS[condition]
	var ready: bool = _state.step == PARTS.TARGET_STEPS[id] and _has_receipts(PARTS.RECEIPT_ORDER.find(id))
	var rule: Dictionary = RULES.PROCESSES[PARTS.PROCESSES[id]]
	sample.merge({
		"state":rule.from if ready else "empty","amount":1 if ready else 0,
		"sealed":phase(_state,"source_valve") == "sealed" if bench == "source" else ready,
		"instrumented":true,"temperature_controlled":condition != "standby","pressure_regime":settings[0],
		"heat_flow":settings[1],"phase_region":{"standby":"unqualified","sublime":"solid_gas","deposit":"gas_solid"}[condition],
		"liquid_present":false,
	},true)
	return sample

func _completion_ready(state: Dictionary) -> bool:
	return state.step == STEP.B_FROST and _has_receipts(PARTS.RECEIPT_ORDER.size())

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty() or _state.step != PARTS.TARGET_STEPS[outcome.id]:
		return false
	var next := _state.duplicate(true)
	next.step += 1
	var successes := []
	var events := []
	if outcome.id == PARTS.FIRST:
		events.append({"id":"direct_return","members":[]})
	if outcome.id == PARTS.FINAL:
		successes.append({"puzzle":"same_sample_circuit","type":"sublime_deposit_cycle",
			"topic":"deposition","object":"reversible_frost_circuit"})
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,successes,_events(events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	present()
	_feedback("Reading could not be saved. Try Fire again.")
	return false

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("circuit")
		"source_valve","a_valve": return _open_valve(id)
		"question": return _question()
		"exit":
			if finish():
				return true
			_feedback("Circuit result could not be saved.")
			return false
	return _open_conditions(id)

func _panel(title: String, body: String, choices: Array, handler: Callable) -> bool:
	var actions := []
	for choice in choices:
		actions.append({"id":choice[0],"label":choice[1]})
	return world.input_adapter.open_provider_panel(self,handler,"guides.library",{
		"title":title,"body":body,"rows":[],"search":false,"actions":actions})

func _open_conditions(id: String) -> bool:
	var condition := phase(_state,id)
	return _panel(BENCH_NAMES[id.get_slice("_",0)]+" pressure and heat",
		"Current setting · "+PRESSURE_TEXT[condition]+" · "+HEAT_TEXT[condition],
		[["sublime","Low pressure · heat in"],["deposit","Regulated pressure · heat out"],["standby","Standby"]],
		_set_conditions.bind(id))

func _set_conditions(choice: String, _payload: Dictionary, id: String) -> void:
	if not PARTS.CONDITIONS.has(choice):
		return
	world.input_adapter.close_panel()
	if not action_allowed(id) or phase(_state,id) == choice:
		return
	var next := _state.duplicate(true)
	_set_phase(next,id,choice)
	_save(next)

func _open_valve(id: String, feedback := "") -> bool:
	var body := feedback
	if id == "source_valve":
		if body.is_empty():
			body = "The source outlet leads to A. Sublimate the ice and wait for GAS 1 before transfer."
		return _panel("Source valve",body,[["seal","Seal source"],["send_a","Send vapor to A"],["send_b","Send vapor to B"]],
			_set_valve.bind(id))
	if body.is_empty():
		body = "The A inlet receives vapor from the source. Isolate frost here before heating it and sending vapor to B."
	return _panel("Collector A valve",body,[["isolate","Isolate A"],["send_b","Send vapor to B"],["send_a","Send back to source"]],
		_set_valve.bind(id))

func _set_valve(choice: String, _payload: Dictionary, id: String) -> void:
	world.input_adapter.close_panel()
	if not action_allowed(id):
		return
	var next := _state.duplicate(true)
	var feedback := ""
	match [id,choice]:
		["source_valve","seal"]:
			if phase(next,"source_valve") == "sealed": return
			_set_phase(next,"source_valve","sealed")
		["source_valve","send_a"]:
			if next.step != STEP.SOURCE_GAS or not _verified(PARTS.SOURCE):
				feedback = "Wait for the source gas reading. Only captured vapor can enter the line."
			else:
				next.step = STEP.A_GAS
		["source_valve","send_b"]:
			feedback = "The source line goes to A. B receives vapor from A."
		["a_valve","isolate"]:
			if next.step == STEP.A_ISOLATED: return
			if next.step != STEP.A_FROST or not _verified(PARTS.FIRST):
				feedback = "Isolate A once its frost reaches the optical target. Use captured vapor for any transfer."
			else:
				next.step = STEP.A_ISOLATED
		["a_valve","send_b"]:
			if next.step != STEP.A_RETURN_GAS or not _verified(PARTS.RETURN):
				feedback = "B needs captured gas. First isolate A and sublimate its frost."
			else:
				next.step = STEP.B_GAS
		["a_valve","send_a"]:
			feedback = "The outlet from A goes to B. The sealed source line only feeds A."
		_: return
	if not feedback.is_empty():
		_open_valve(id,feedback)
	else:
		_save(next)

func _question(feedback := "") -> bool:
	var choices := []
	for i in QUESTION.choices.size():
		choices.append([str(i),QUESTION.choices[i]])
	return _panel("What moved through the pipe?",feedback,choices,_answer)

func _answer(id: String, _payload: Dictionary) -> void:
	if not id.is_valid_int() or not active() or not _near("a_sensor"):
		return
	var answer := CONTENT.answer(REGION,QUESTION,id.to_int())
	if not answer.is_empty():
		_question(answer.feedback)

func _save(next: Dictionary) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),[],[],world):
		return true
	_feedback("Setting could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func _present_apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var view := state.duplicate(true)
	var step: int = state.step
	var source: String = ["solid","gas"][step] if step <= STEP.SOURCE_GAS else "empty"
	var collector_a: String = ["gas","solid","isolated","return_gas"][step-STEP.A_GAS] if step in range(STEP.A_GAS,STEP.B_GAS) else "empty"
	if step >= STEP.B_GAS:
		collector_a = "cleared"
	var collector_b := "solid" if step >= STEP.B_FROST else ("gas" if step == STEP.B_GAS else "empty")
	var sensor_a := "target" if step in [STEP.A_FROST,STEP.A_ISOLATED] else ("clear" if step >= STEP.A_RETURN_GAS else "below")
	var valve_a := "closed"
	if step >= STEP.A_GAS: valve_a = "inlet"
	if step >= STEP.A_ISOLATED: valve_a = "isolated"
	if step >= STEP.B_GAS: valve_a = "sent"
	for entry in [
		["source",source],["source_valve","sent" if step >= STEP.A_GAS else phase(state,"source_valve")],
		["source_sensor","gas" if source == "gas" else "empty"],
		["a",collector_a],["a_valve",valve_a],["a_sensor",sensor_a],
		["b",collector_b],["b_valve","sealed" if step >= STEP.B_GAS else "closed"],
		["b_sensor","target" if collector_b == "solid" else "below"],
		["exit","online" if step == STEP.ONLINE else ("ready" if step == STEP.B_FROST else "offline")],
	]:
		_set_phase(view,entry[0],entry[1])
	for bench in BENCHES:
		var condition := phase(state,bench+"_gauge")
		_set_phase(view,bench+"_heat",condition)
		_labels[bench+"_gauge"].text = "REGULATED" if condition == "deposit" else PRESSURE_TEXT[condition]
		_labels[bench+"_heat"].text = HEAT_TEXT[condition]
	for assembly in assemblies.values():
		assembly.present(view.components,view.items)
	_labels.source.text = {"solid":"SOURCE ICE","gas":"SOURCE VAPOR","empty":"SOURCE EMPTY"}[source]
	_labels.source_sensor.text = "GAS %d · LIQUID 0" % int(source == "gas")
	_labels.source_valve.text = {"open":"UNSEALED","sealed":"SOURCE SEALED","sent":"VAPOR SENT TO A"}[phase(view,"source_valve")]
	_labels.a.text = {"empty":"COLLECTOR A EMPTY","gas":"A · VAPOR RECEIVED","solid":"A · FROST",
		"isolated":"A · ISOLATED FROST","return_gas":"A · GAS 1 · LIQUID 0","cleared":"A · GAS 0 · LIQUID 0"}[collector_a]
	_labels.a_valve.text = {"closed":"A INLET CLOSED","inlet":"SOURCE → A","isolated":"A ISOLATED","sent":"VAPOR SENT TO B"}[valve_a]
	_labels.a_sensor.text = {"below":"A · BELOW TARGET","target":"A · TARGET","clear":"A · SENSOR CLEAR"}[sensor_a]
	_labels.b.text = {"empty":"COLLECTOR B EMPTY","gas":"B · VAPOR RECEIVED","solid":"B · SOLID 1 · LIQUID 0"}[collector_b]
	_labels.b_valve.text = "A → B" if step >= STEP.B_GAS else "B INLET CLOSED"
	_labels.b_sensor.text = "B · TARGET" if collector_b == "solid" else "B · BELOW TARGET"
	_labels.exit.text = "CIRCUIT ONLINE" if step == STEP.ONLINE else "CIRCUIT CONTROL"
	for bench in BENCHES:
		var has_gas: bool = (bench == "source" and step == STEP.SOURCE_GAS) or (bench == "a" and step in [STEP.A_GAS,STEP.A_RETURN_GAS]) or (bench == "b" and step == STEP.B_GAS)
		_lines[bench].default_color = Color("8bd3e2") if has_gas else Color("647a84")
	var tasks := ["Source · seal and set low pressure + heat in","Source valve · send vapor to A",
		"A · set regulated pressure + heat out","A valve · isolate frost","A · set low pressure + heat in",
		"A valve · send vapor to B","B · set regulated pressure + heat out","Circuit control · record the result","Circuit online"]
	var task: String = tasks[step]
	if step == STEP.SOURCE_ICE and phase(state,"source_valve") == "sealed" and phase(state,"source_gauge") == "sublime":
		task = "Source · use Vacuum"
	if step == STEP.A_GAS and phase(state,"a_gauge") == "deposit": task = "Collector A · use Pressure"
	if step == STEP.A_ISOLATED and phase(state,"a_gauge") == "sublime": task = "Isolated A · use Vacuum"
	if step == STEP.B_GAS and phase(state,"b_gauge") == "deposit": task = "Collector B · use Pressure"
	chunk.quests = [{"text":task,"state":"done" if step == STEP.ONLINE else "active"}]
	chunk.tutorial = ""

func present() -> void:
	if not _state.is_empty():
		_visible_growth.clear()
		_present_apparatus(_state)

func _process(_delta: float) -> void:
	if not _can_write() or _labels.is_empty():
		return
	for id in targets:
		var target: Node = targets[id]
		if not is_instance_valid(target) or target.is_committed() or target.exposure() <= 0:
			continue
		var stage := int(target.exposure() >= target.definition().required_exposure*.55)
		if _visible_growth.get(id,-1) == stage:
			continue
		_visible_growth[id] = stage
		var bench: String = PARTS.TARGET_BENCH[id]
		var art := PARTS.art(PROGRESS_ART[id][stage])
		var sprite: Sprite2D = component(bench+"/control").visuals.get_node("Artwork")
		sprite.texture = load(art.path)
		sprite.scale = Vector2.ONE*float(art.scale)
		sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale
		_labels[bench].text = "PARTIAL GAS · LIQUID 0" if PARTS.PROCESSES[id] == "sublimation" else "PARTIAL FROST · LIQUID 0"

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	_present_apparatus(raw if _supported_state(raw) else default_state())

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
	for record in _disabled_reserves:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.set_deferred("collision_layer",record.layer)
	for prop in _hidden_reserves:
		if is_instance_valid(prop): prop.show()
	if is_instance_valid(_professor): _professor.queue_free()
	super._exit_tree()
