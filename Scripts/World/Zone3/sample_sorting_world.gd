extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/sample_sorting_assembly.gd")
const REGION := PARTS.SORTING
const CHECKPOINTS := ["C0","C1","C2"]
const ROUTES := {"liquid_lock":PARTS.MELT,"gas_lock":PARTS.SUBLIME}
const READINGS := {
	PARTS.MELT:{"sensor":"liquid_sensor","card":"melt_card","states":["solid","liquid"],"liquid":PARTS.BATCH,"gas":0},
	PARTS.SUBLIME:{"sensor":"gas_sensor","card":"gas_card","states":["solid","gas"],"liquid":0,"gas":PARTS.BATCH},
}
const SHRINKING := {
	PARTS.MELT:["normal_warmer_melting_early","normal_warmer_melting_late"],
	PARTS.SUBLIME:["sublimation_shrinking_early","sublimation_shrinking_late"],
}
const LABELS := {"warmer":"NORMAL PRESSURE", "liquid_sensor":"LIQUID %d", "melt_card":"SOLID → LIQUID",
	"chamber":"SAMPLE CHAMBER", "valve":"CHAMBER VALVE", "condition":"NORMAL PRESSURE · HEAT OFF",
	"gas_sensor":"GAS %d", "dry_tray":"LIQUID 0", "gas_card":"SOLID → GAS", "liquid_lock":"LIQUID ROUTE",
	"gas_lock":"DIRECT-GAS ROUTE", "condenser":"RECOVERY CONDENSER", "tank":"TANK EMPTY", "exit":"SAMPLE TRAY DESK"}
const LABEL_OFFSETS := {"warmer":Vector2(-75,-11),"chamber":Vector2(-24,-8),"gas_card":Vector2(-182,-30),
	"dry_tray":Vector2(-33,-2),"condition":Vector2(-75,-43),"valve":Vector2(-75,-25),
	"condenser":Vector2(-75,-11),"exit":Vector2(-2,-10)}

var points := {}
var _professor: Marker2D
var _labels := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _visible_exposure := {}

func bind_sorting_room(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	points.merge({
		"warmer":points.court1+Vector2(84,-149), "liquid_sensor":points.court1+Vector2(-4,-132),
		"melt_card":points.court1+Vector2(169,-149), "chamber":points.court2+Vector2(-144,-19),
		"valve":points.court2+Vector2(-85,40), "condition":points.court2+Vector2(0,35),
		"gas_sensor":points.court2+Vector2(-220,-19), "dry_tray":points.court2+Vector2(-154,46),
		"gas_card":points.court2+Vector2(-133,-93), "liquid_lock":points.court3+Vector2(0,-140),
		"gas_lock":points.court3+Vector2(99,-94), "condenser":points.court3+Vector2(-84,-149),
		"tank":points.court3+Vector2(-20,10),
	})
	if not bind(host,get_parent(),PARTS.sorting_definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	_professor = Marker2D.new()
	_professor.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_professor)
	for id in LABELS:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = LABEL_OFFSETS.get(id,Vector2(-75,8))
		label.size.x = 150
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if placement.station not in [REGION+".court1",REGION+".court2",REGION+".court3"]:
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
				_disabled_reserves.append(record)
				record.layer = 0
				record.body.collision_layer = 0

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _set_phase(state: Dictionary, id: String, value: String) -> void:
	state.components[id+"/control"].phase = value

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not raw.items.is_empty():
		return false
	var observed: Variant = raw.get("readings",{})
	if not observed is Dictionary:
		return false
	var melted := phase(raw,"warmer") == "liquid"
	var chamber := phase(raw,"chamber")
	var condenser := phase(raw,"condenser")
	var prepared := phase(raw,"condition") == "ready"
	var drained := condenser == "drained"
	var released := phase(raw,"exit") == "released"
	var expected := {}
	if melted: expected[PARTS.MELT] = READINGS[PARTS.MELT]
	if chamber != "solid": expected[PARTS.SUBLIME] = READINGS[PARTS.SUBLIME]
	if observed != expected:
		return false
	for id in READINGS:
		var reading: Dictionary = READINGS[id]
		var sensor_value := "detected" if expected.has(id) else "empty"
		if phase(raw,reading.sensor) != sensor_value or phase(raw,reading.card) != sensor_value:
			return false
	for lock in ROUTES:
		if phase(raw,lock) == "open" and not expected.has(ROUTES[lock]):
			return false
	return ((not prepared or phase(raw,"valve") == "sealed") and (chamber == "solid" or prepared)
		and (chamber == "routed") == (condenser != "empty")
		and (chamber != "routed" or _locks_open(raw))
		and (phase(raw,"tank") == "full") == drained
		and raw.get("recovery",{}) == (PARTS.RECOVERY if drained else {})
		and (not released or drained)
		and raw.get("output",{}) == (PARTS.OUTPUT if released else {}))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		var finished: Dictionary = result[STATE_KEY]
		_set_phase(finished,"exit","released")
		finished.output = PARTS.OUTPUT.duplicate()
	var progress: Dictionary = store.normalize_checkpoint_progress(result.get("checkpoint_progress",{}),CHECKPOINTS)
	if phase(state,"warmer") == "liquid": progress = store.unlock_checkpoint(progress,"C1",CHECKPOINTS)
	if phase(state,"chamber") != "solid": progress = store.unlock_checkpoint(progress,"C2",CHECKPOINTS)
	result.checkpoint_progress = progress
	result.checkpoint = progress.latest_unlocked_checkpoint_id
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
	var ray := PhysicsRayQueryParameters2D.create(ground,at,1|8,exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and world.player.jump_elapsed < 0 and world.player.action_elapsed < 0
			and not world.player.carrying and _near(id))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"route": return _paths_verified(_state)
		"collect": return _paths_verified(_state) and _verified(PARTS.RECOVER)
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_professor) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Aster","target":_professor,"enabled":true,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	match id:
		PARTS.MELT:
			sample.pressure_regime = "normal"
		PARTS.SUBLIME:
			var prepared := phase(_state,"condition") == "ready"
			sample.merge({"sealed":phase(_state,"valve") == "sealed","instrumented":true,
				"temperature_controlled":prepared,"pressure_regime":"low" if prepared else "normal",
				"heat_flow":"in" if prepared else "none","phase_region":"solid_gas" if prepared else "unqualified",
				"liquid_present":false},true)
		PARTS.RECOVER:
			var charged := phase(_state,"condenser") == "gas" and phase(_state,"chamber") == "routed"
			sample.amount = PARTS.BATCH if charged else 0
			sample.pressure_regime = "normal"
			sample.pane_c = PARTS.PANE_C
	return sample

func _verified(id: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var process: String = PARTS.PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	return records is Dictionary and records.get(id) == {"id":id,"version":1,"material":"water","process":process,
		"from_state":rule.from,"to_state":rule.to,"capability":rule.capability,"puzzle_type":rule.type}

func _observed(id: String, state: Dictionary) -> bool:
	return state.get("readings",{}).get(id) == READINGS[id] and _verified(id)

func _locks_open(state: Dictionary) -> bool:
	return phase(state,"liquid_lock") == "open" and phase(state,"gas_lock") == "open"

func _paths_verified(state: Dictionary) -> bool:
	return _locks_open(state) and _observed(PARTS.MELT,state) and _observed(PARTS.SUBLIME,state)

func _completion_ready(state: Dictionary) -> bool:
	return state.get("recovery") == PARTS.RECOVERY and _paths_verified(state) and _verified(PARTS.RECOVER)

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	if ROUTES.has(id):
		return _show_lock(id)
	match id:
		"professor": return world.input_adapter.open_lesson("comparison")
		"exit": return finish()
	world.input_adapter.stop_all("sorting_action",true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var action: Dictionary = contract.actions[id]
	next.components[action.component].phase = action.value
	var successes := []
	match id:
		"route": _set_phase(next,"chamber","routed")
		"collect":
			_set_phase(next,"condenser","drained")
			next.recovery = PARTS.RECOVERY.duplicate(true)
			successes.append({"puzzle":"sorting_comparison","type":"melt_sublime_compare",
				"topic":"sublimation","object":"sorting_supply_tank"})
	return _save(next,successes)

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var next := _state.duplicate(true)
	next.components[contract.targets[outcome.id].component].phase = outcome.to_state
	if READINGS.has(outcome.id):
		var reading: Dictionary = READINGS[outcome.id]
		var observed: Dictionary = next.get("readings",{})
		observed[outcome.id] = reading.duplicate(true)
		next.readings = observed
		_set_phase(next,reading.sensor,"detected")
		_set_phase(next,reading.card,"detected")
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world):
		return true
	target.reset_after_restore(world,store)
	present()
	_feedback("Reading could not be saved. Apply the device again.")
	return false

func _show_lock(lock: String, feedback := "") -> bool:
	var melt := "Warmer · liquid detected" if _observed(PARTS.MELT,_state) else "Warmer · no verified liquid reading yet"
	var gas := "Chamber · gas captured, liquid stayed at 0" if _observed(PARTS.SUBLIME,_state) else "Chamber · no verified gas reading yet"
	var title := "Which sample took the liquid route?" if lock == "liquid_lock" else "Which sample went directly from solid to gas?"
	return world.input_adapter.open_provider_panel(self,_answer_lock.bind(lock),"guides.library",{
		"title":title,"speaker":"professor_z3","body":(feedback+"\n\n" if not feedback.is_empty() else "")+melt+"\n"+gas,
		"rows":[],"search":false,"actions":[{"id":"warmer","label":"Warmer sample"},
			{"id":"chamber","label":"Chamber sample"},{"id":"shrank","label":"Smaller solid only"}]})

func _answer_lock(choice: String, _payload: Dictionary, lock: String) -> void:
	if choice not in ["warmer","chamber","shrank"]:
		return
	world.input_adapter.close_panel()
	if not action_allowed(lock):
		return
	var expected: String = ROUTES[lock]
	var selected := PARTS.MELT if choice == "warmer" else PARTS.SUBLIME
	var message := ""
	if choice == "shrank":
		message = "Both solids can shrink. Use the liquid and captured-gas readings to tell which state formed."
	elif not _observed(selected,_state):
		message = "This sample has no verified reading yet. Finish observing the sample and try again."
	elif selected != expected:
		message = "The warmer produced liquid. The chamber produced captured gas while its liquid tray stayed empty. Try the other path."
	var next := _state.duplicate(true)
	_set_phase(next,lock,"open" if message.is_empty() else "wrong")
	if not _save(next):
		return
	if message.is_empty():
		_feedback("Sensor reading accepted. Route lock open.")
	else:
		_show_lock(lock,message)

func _save(next: Dictionary, successes := []) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,[],world):
		return true
	_feedback("Sorting room state could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	for id in LABELS:
		_labels[id].text = LABELS[id]
	var melted := phase(state,"warmer") == "liquid"
	var chamber := phase(state,"chamber")
	var condenser := phase(state,"condenser")
	var done := phase(state,"exit") == "released"
	_labels.liquid_sensor.text = LABELS.liquid_sensor % (PARTS.BATCH if melted else 0)
	_labels.melt_card.text = LABELS.melt_card if melted else "AWAITING LIQUID READING"
	_labels.gas_sensor.text = LABELS.gas_sensor % (PARTS.BATCH if chamber != "solid" else 0)
	_labels.gas_card.text = LABELS.gas_card if chamber != "solid" else "AWAITING GAS READING"
	_labels.chamber.text = {"solid":"SAMPLE CHAMBER","gas":"VAPOR CAPTURED","routed":"VAPOR SENT"}[chamber]
	_labels.valve.text = "CHAMBER SEALED" if phase(state,"valve") == "sealed" else "CHAMBER OPEN"
	if phase(state,"condition") == "ready": _labels.condition.text = "LOW PRESSURE\nHEAT IN"
	for lock in ROUTES:
		_labels[lock].text += {"closed":" · CLOSED","wrong":" · RETRY","open":" · OPEN"}[phase(state,lock)]
	_labels.condenser.text = {"empty":LABELS.condenser,"gas":"VAPOR · NORMAL PRESSURE",
		"liquid":"+%d°C · DROPLETS" % PARTS.PANE_C,"drained":"DRAINED"}[condenser]
	if chamber == "routed": _labels.gas_sensor.text = "CAPTURED %d · TRANSFERRED" % PARTS.BATCH
	if phase(state,"tank") == "full": _labels.tank.text = "%d LIQUID MEASURES" % PARTS.BATCH
	if done: _labels.exit.text = "CALIBRATED SAMPLE TRAY"
	var task := "West bench · melt ice with Thermal"
	if melted:
		task = "Middle bench · prepare the chamber"
		if phase(state,"condition") == "ready": task = "Middle bench · use Vacuum and read the sensors"
	if melted and chamber != "solid": task = "East bench · match both sensor readings"
	if _locks_open(state): task = "East bench · send captured vapor"
	if condenser == "gas": task = "East bench · cool vapor with Cryo"
	if condenser == "liquid": task = "East bench · drain the droplets"
	if condenser == "drained": task = "South desk · record the tray"
	chunk.quests = [{"text":"Calibrated sample tray recorded" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func present() -> void:
	super.present()
	if not _state.is_empty():
		_visible_exposure.clear()
		_apparatus(_state)

func _process(_delta: float) -> void:
	if not _can_write() or _labels.is_empty():
		return
	for id in SHRINKING:
		var target: Node = targets.get(id)
		if not is_instance_valid(target) or target.is_committed() or target.exposure() <= 0:
			continue
		var stage := 1 if target.exposure() >= target.definition().required_exposure * .55 else 0
		if _visible_exposure.get(id,-1) == stage:
			continue
		_visible_exposure[id] = stage
		var part: String = contract.targets[id].component.get_slice("/",0)
		var sprite: Sprite2D = component(part+"/control").visuals.get_node("Artwork")
		var art := PARTS.art(SHRINKING[id][stage])
		sprite.texture = load(art.path)
		sprite.scale = Vector2.ONE*float(art.scale)
		sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale
		_labels[part].text = "HEAT IN · SAMPLE SHRINKING"

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
	for record in _disabled_reserves:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.collision_layer = record.layer
	for prop in _hidden_reserves:
		if is_instance_valid(prop): prop.show()
	if is_instance_valid(_professor): _professor.queue_free()
	super._exit_tree()
