extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/observatory_assembly.gd")
const WORLD_SAVE = preload("res://Scripts/Content/world_save.gd")
const REGION := PARTS.OBSERVATORY
const CHECKPOINTS := ["C0","C1","C2"]
const BLUEPRINT := {"version":1,"id":"frost_cartridge_blueprint"}
const TITLES := {"solid_liquid":"Solid–liquid","liquid_gas":"Liquid–gas","solid_gas":"Solid–gas"}
const SETTINGS := {"standby":"STANDBY","sublime":"LOW · HEAT IN","deposit":"REGULATED · HEAT OUT"}
const LINKS := {"melt":"freeze","boil":"wheel","wheel":"condense","sublime":"deposit"}
const QUESTIONS := {
	"solid_liquid":{"process":"freezing","prompt":"Which path held the plate in the jig?",
		"choices":["Liquid → solid · heat out","Liquid → solid · heat in","Solid → liquid · heat out"],"correct":0},
	"liquid_gas":{"process":"condensation","prompt":"What happened at the measuring cup?",
		"choices":["Liquid → gas · heat in","Gas → liquid · heat out","Gas → solid · heat out"],"correct":1},
	"solid_gas":{"process":"sublimation","prompt":"Which path supplied the sealed vapor line?",
		"choices":["Solid → liquid · heat in","Gas → solid · heat out","Solid → gas · heat in"],"correct":2},
}

var points := {}
var _labels := {}
var _links := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _help: Marker2D
var _progress_art := {}
var _wheel_spin := 0.0

func bind_observatory(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	points.merge({
		"melt":points.court1+Vector2(-58,-32),"freeze":points.court1+Vector2(36,-18),
		"heater":points.court1+Vector2(99,25),"plate":points.court1+Vector2(16,34),
		"dock":points.court1+Vector2(-64,45),"solid_liquid":points.court1+Vector2(-100,16),
		"evap":points.court2+Vector2(-42,-89),"boil":points.court2+Vector2(45,-55),
		"condense":points.court2+Vector2(38,71),"wheel":points.court2+Vector2(88,2),
		"liquid_gas":points.court2+Vector2(-45,59),
		"sublime":points.court3+Vector2(-60,-69),"deposit":points.court3+Vector2(67,-63),
		"sublime_setup":points.court3+Vector2(-70,8),"deposit_setup":points.court3+Vector2(82,23),
		"solid_gas":points.court3+Vector2(-58,91),"blueprint":points.court3+Vector2(48,86),
	})
	if not bind(host,get_parent(),PARTS.observatory_definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	_help = Marker2D.new()
	_help.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_help)
	for id in assemblies:
		if id == "plate": continue
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-76,8)
		label.size.x = 152
		label.z_index = 1
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	for id in LINKS:
		var from: Node2D = component(id+"/control")
		var to: Node2D = component(LINKS[id]+"/control")
		var offset := to.position-from.position-Vector2(0,to.elevation-from.elevation)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2.ZERO,Vector2(offset.x*.5,offset.y),offset])
		line.width = 4
		line.z_index = -1
		line.antialiased = true
		from.visuals.add_child(line)
		_links[id] = line
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
				record.layer = 0
				record.body.collision_layer = 0
				_disabled_reserves.append(record)

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _set_phase(state: Dictionary, id: String, value: String) -> void:
	state.components[id+"/control"].phase = value

static func reading(process: String) -> Dictionary:
	var rule: Dictionary = RULES.PROCESSES[process]
	var result := {"material":"water","states":[rule.from,rule.to],"heat_flow":rule.heat}
	match process:
		"evaporation": result.origin = "cloth_surface"
		"boiling": result.origin = "boiler_bulk"
		"condensation": result.merge({"origin":"boiler_exhaust","pane_c":PARTS.PANE_C,"measured_liquid":1})
		"sublimation": result.merge({"pressure_regime":"low","liquid_present":false})
		"deposition": result.merge({"pressure_regime":"high","liquid_present":false})
	return result

static func _proof_for(run_state: Dictionary, process: String) -> bool:
	var module: Variant = run_state.get(STATE_KEY)
	var proof: Variant = run_state.get("device_outcomes")
	if not module is Dictionary or not proof is Dictionary:
		return false
	var readings: Variant = module.get("readings")
	var rule: Dictionary = RULES.PROCESSES[process]
	var id := PARTS.target_id(process)
	return (readings is Dictionary and readings.get(process) == reading(process)
		and proof.get(id) == {"version":1,"id":id,"material":"water","process":process,"from_state":rule.from,
			"to_state":rule.to,"capability":rule.capability,"puzzle_type":rule.type})

static func cartridge_blueprint_unlocked(profile: Dictionary) -> bool:
	var extras: Variant = profile.get("extras")
	if not extras is Dictionary:
		return false
	var record: Variant = extras.get(WORLD_SAVE.KEY)
	if not record is Dictionary or not WORLD_SAVE.supported(record):
		return false
	var attempt: Variant = record.get("attempts",{}).get(REGION,{}).get("attempt")
	if not attempt is Dictionary or not attempt.get("state") is Dictionary:
		return false
	var state: Dictionary = attempt.state
	var module: Variant = state.get(STATE_KEY)
	return (module is Dictionary and module.get("version") == 1 and module.get("subregion") == REGION and module.get("blueprint") == BLUEPRINT
		and module.get("items") is Dictionary and module.items.get(PARTS.PLATE) == PARTS.DOCKED
		and PARTS.VESSELS.keys().all(func(process): return _proof_for(state,process)))

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or raw.items.get(PARTS.PLATE) not in [PARTS.CRADLE,"player",PARTS.DOCKED]:
		return false
	var readings := {}
	for process in PARTS.VESSELS:
		if phase(raw,PARTS.VESSELS[process]) in PARTS.FINISHED_PHASES[process]:
			readings[process] = reading(process)
	var filled := phase(raw,"freeze") != "empty"
	var released := phase(raw,"freeze") == "released"
	var routed := phase(raw,"boil") == "spent"
	var vented := phase(raw,"sublime") == "routed"
	var blueprint := phase(raw,"blueprint") == "recorded"
	return (raw.get("readings",{}) == readings and filled == (phase(raw,"melt") == "drained")
		and released == (phase(raw,"heater") == "used")
		and (released or raw.items[PARTS.PLATE] == PARTS.CRADLE)
		and ((phase(raw,"evap") == "folded" and phase(raw,"boil") == "unguarded") or raw.items[PARTS.PLATE] == PARTS.DOCKED)
		and routed == (phase(raw,"wheel") == "driven") and routed == (phase(raw,"condense") != "empty")
		and vented == (phase(raw,"deposit") != "empty")
		and (phase(raw,"sublime") == "solid" or (readings.has("evaporation") and readings.has("condensation")))
		and (not blueprint or (readings.size() == PARTS.VESSELS.size() and raw.items[PARTS.PLATE] == PARTS.DOCKED))
		and raw.get("blueprint",{}) == (BLUEPRINT if blueprint else {})
		and (phase(raw,"exit") == "waiting" or blueprint))

func _observed(state: Dictionary, group: String) -> bool:
	var readings: Dictionary = state.get("readings",{})
	return PARTS.GROUPS[group].all(func(process): return readings.get(process) == reading(process))

func _verified(process: String) -> bool:
	return _proof_for(store.data.active_run.get("state",{}),process)

func _group_ready(state: Dictionary, group: String) -> bool:
	return _observed(state,group) and PARTS.GROUPS[group].all(_verified)

func _plate_verified(state: Dictionary) -> bool:
	return state.items[PARTS.PLATE] == PARTS.DOCKED and _group_ready(state,"solid_liquid")

func _all_verified(state: Dictionary) -> bool:
	return _plate_verified(state) and _group_ready(state,"liquid_gas") and _group_ready(state,"solid_gas")

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		_set_phase(result[STATE_KEY],"exit","recorded")
	var earned := ["C0"]
	if state.items[PARTS.PLATE] == PARTS.DOCKED: earned.append("C1")
	if _observed(state,"liquid_gas"): earned.append("C2")
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

func world_context() -> Dictionary:
	if is_instance_valid(_help) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Aster","target":_help,"enabled":true,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and not world.player.carrying and world.player.jump_elapsed < 0
			and world.player.action_elapsed < 0 and _near(id))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"fill": return _verified("melting")
		"release","take","dock": return _group_ready(_state,"solid_liquid")
		"spread","guard": return _plate_verified(_state)
		"wheel": return _plate_verified(_state) and _verified("boiling")
		"sublime_setup": return _group_ready(_state,"liquid_gas") and phase(_state,"sublime") == "solid"
		"deposit_setup": return _group_ready(_state,"liquid_gas") and phase(_state,"deposit") == "gas"
		"route": return _group_ready(_state,"liquid_gas") and _verified("sublimation")
		"blueprint": return _all_verified(_state)
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	var process: String = contract.targets[id].spec.process
	var ready: bool = sample.state == RULES.PROCESSES[process].from
	if process in PARTS.GROUPS.liquid_gas:
		ready = ready and _plate_verified(_state)
	if process in PARTS.GROUPS.solid_gas:
		ready = ready and _group_ready(_state,"liquid_gas")
		var selected := phase(_state,PARTS.VESSELS[process]+"_setup")
		var setup: Array = PARTS.CIRCUIT.CONDITIONS[selected]
		sample.merge({"sealed":selected != "standby","instrumented":true,"temperature_controlled":selected != "standby",
			"pressure_regime":setup[0],"heat_flow":setup[1],"liquid_present":false,
			"phase_region":{"standby":"unqualified","sublime":"solid_gas","deposit":"gas_solid"}[selected]},true)
	if process == "condensation":
		sample.pane_c = PARTS.PANE_C
		sample.pressure_regime = "normal"
	sample.amount = 1 if ready else 0
	return sample

func _completion_ready(state: Dictionary) -> bool:
	return state.get("blueprint") == BLUEPRINT and _all_verified(state)

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var next := _state.duplicate(true)
	_set_phase(next,PARTS.VESSELS[outcome.process],outcome.to_state)
	var readings: Dictionary = next.get("readings",{}).duplicate(true)
	readings[outcome.process] = reading(outcome.process)
	next.readings = readings
	var events := _events([{"id":"six_changes","members":[outcome.process]}],outcome.id)
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],events):
		return true
	target.reset_after_restore(world,store)
	present()
	_feedback("Reading could not be saved. Try Fire again.")
	return false

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	if PARTS.GROUPS.has(id):
		return _open_review(id)
	match id:
		"professor": return world.input_adapter.open_lesson("observatory")
		"sublime_setup","deposit_setup": return _open_conditions(id)
		"exit":
			if finish():
				return true
			_feedback("Completion could not be saved.")
			return false
		"take","dock": return super.commit_action(id)
	world.input_adapter.stop_all("observatory_action",true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var action: Dictionary = contract.actions[id]
	next.components[action.component].phase = action.value
	match id:
		"fill": _set_phase(next,"melt","drained")
		"release": _set_phase(next,"freeze","released")
		"wheel":
			_set_phase(next,"boil","spent")
			_set_phase(next,"condense","gas")
		"route": _set_phase(next,"sublime","routed")
		"blueprint": next.blueprint = BLUEPRINT.duplicate()
	if not _save(next):
		return false
	if id == "wheel": _wheel_spin = 1.25
	return true

func _open_conditions(id: String) -> bool:
	var title := "Source conditions" if id == "sublime_setup" else "Collector conditions"
	return world.input_adapter.open_provider_panel(self,_set_conditions.bind(id),"guides.library",{
		"title":title,"body":"Current setting · "+SETTINGS[phase(_state,id)],"rows":[],"search":false,"actions":[
			{"id":"standby","label":"Standby"},{"id":"sublime","label":"Low pressure · heat in"},
			{"id":"deposit","label":"Regulated pressure · heat out"}]})

func _set_conditions(value: String, _payload: Dictionary, id: String) -> void:
	if not SETTINGS.has(value):
		return
	world.input_adapter.close_panel()
	if not action_allowed(id) or phase(_state,id) == value:
		return
	var next := _state.duplicate(true)
	_set_phase(next,id,value)
	_save(next)

func _open_review(group: String, feedback := "") -> bool:
	var rows := []
	for process in PARTS.GROUPS[group]:
		var route := _reading_label(process).replace("\n"," · ")
		rows.append({"title":process.capitalize(),"text":route if _verified(process) else "Awaiting observation"})
	var question: Dictionary = QUESTIONS[group]
	var actions := []
	if _verified(question.process):
		for i in question.choices.size():
			actions.append({"id":str(i),"label":question.choices[i]})
	return world.input_adapter.open_provider_panel(self,_answer_review.bind(group),"guides.library",{
		"title":TITLES[group]+" evidence","body":question.prompt if feedback.is_empty() and not actions.is_empty() else feedback,
		"search":false,"rows":rows,"actions":actions})

func _answer_review(id: String, _payload: Dictionary, group: String) -> void:
	if not active() or not _near(group) or not id.is_valid_int():
		return
	var question: Dictionary = QUESTIONS[group].duplicate()
	if not _verified(question.process): return
	var route := _reading_label(question.process).replace("\n"," · ")
	question.feedback = "The instrument recorded "+route+"."
	var answer := CONTENT.answer(REGION,question,id.to_int())
	if not answer.is_empty(): _open_review(group,answer.feedback)

func _save(next: Dictionary) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),[],[],world):
		return true
	_feedback("Setting could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func _reading_label(process: String) -> String:
	var rule: Dictionary = RULES.PROCESSES[process]
	return "%s → %s\nHEAT %s" % [rule.from.to_upper(),rule.to.to_upper(),rule.heat.to_upper()]

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var view := state.duplicate(true)
	var plate_in_place: bool = state.items[PARTS.PLATE] == PARTS.DOCKED
	var liquids := _observed(state,"liquid_gas")
	var done := phase(state,"exit") == "recorded"
	var released := phase(state,"freeze") == "released"
	for group in PARTS.GROUPS:
		var unlocked: bool = {"solid_liquid":true,"liquid_gas":plate_in_place,"solid_gas":liquids}[group]
		var status := "complete" if _observed(state,group) and (group != "solid_liquid" or plate_in_place) else ("ready" if unlocked else "locked")
		_set_phase(view,group,status)
		_labels[group].text = TITLES[group].to_upper()+"\n"+status.to_upper()
	var locations := {}
	for id in assemblies:
		locations[id+"/control"] = points[id]
	for assembly in assemblies.values():
		assembly.present(view.components,view.items,locations)
	component("plate/control").visible = released and state.items[PARTS.PLATE] != "player"
	var labels := {"melt":"MELTWATER INLET","freeze":"EMPTY PLATE JIG","evap":"DAMP LABEL CLOTH",
		"boil":"WATER BOILER","condense":"MEASURING CUP","sublime":"SEALED ICE SOURCE","deposit":"COLD COLLECTOR",
		"dock":"PLATE STAND","heater":"JIG HEATER","wheel":"MODEL WHEEL","blueprint":"BLUEPRINT DESK","exit":"OBSERVATORY EXIT"}
	for id in labels: _labels[id].text = labels[id]
	for process in PARTS.VESSELS:
		if state.get("readings",{}).has(process):
			_labels[PARTS.VESSELS[process]].text = _reading_label(process)
	if phase(state,"freeze") == "liquid": _labels.freeze.text = "JIG FILLED"
	if released: _labels.heater.text = "PLATE RELEASED · HEAT IN"
	if plate_in_place: _labels.dock.text = "PLATE SEATED"
	if phase(state,"evap") == "gas": _labels.evap.text = "SURFACE · LIQUID → GAS\nHEAT IN"
	if phase(state,"boil") == "gas" or phase(state,"boil") == "spent": _labels.boil.text = "BULK · LIQUID → GAS\nHEAT IN"
	if phase(state,"wheel") == "driven": _labels.wheel.text = "WHEEL TESTED\nEXHAUST ROUTED"
	if phase(state,"condense") == "gas": _labels.condense.text = "BOILER VAPOR RECEIVED"
	if phase(state,"condense") == "liquid": _labels.condense.text = "GAS → LIQUID · HEAT OUT\n+8°C · CUP 1"
	if phase(state,"sublime") == "routed": _labels.sublime.text = "VAPOR SENT\nLIQUID 0"
	if phase(state,"deposit") == "gas": _labels.deposit.text = "VAPOR RECEIVED"
	if phase(state,"deposit") == "solid": _labels.deposit.text = "GAS → SOLID · HEAT OUT\nLIQUID 0"
	var supplied := {"melt":phase(state,"melt") == "drained","boil":phase(state,"boil") == "gas",
		"wheel":phase(state,"condense") == "gas","sublime":phase(state,"deposit") == "gas"}
	for id in LINKS:
		_links[id].default_color = Color("8bd3e2") if supplied[id] else Color("647a84")
	for id in ["sublime_setup","deposit_setup"]: _labels[id].text = SETTINGS[phase(state,id)]
	if phase(state,"blueprint") == "recorded": _labels.blueprint.text = "BLUEPRINT RECORDED"
	if done: _labels.exit.text = "OBSERVATORY COMPLETE"
	var task := "Solid–liquid · prepare and seat the plate"
	if plate_in_place: task = "Liquid–gas · dry cloth, drive wheel, fill cup"
	if liquids: task = "Solid–gas · supply vapor and match frost"
	if _observed(state,"solid_gas"): task = "Record the frost-cartridge blueprint"
	if phase(state,"blueprint") == "recorded": task = "Return to the Observatory exit"
	chunk.quests = [{"text":"Observatory complete" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func present() -> void:
	if _state.is_empty():
		return
	_progress_art.clear()
	_apparatus(_state)
	_update_carry()

func _process(delta: float) -> void:
	if not _can_write() or _labels.is_empty():
		return
	if _wheel_spin > 0.0:
		_wheel_spin = maxf(0.0,_wheel_spin-delta)
		var variant := "driven" if _wheel_spin == 0.0 else ("spin_a" if int(_wheel_spin*18)%2 == 0 else "spin_b")
		_apply_sprite("wheel",assemblies.wheel.specs.control.variants[variant])
	for process in PARTS.PROGRESS_ART:
		var target: Node = targets.get(PARTS.target_id(process))
		if not is_instance_valid(target) or target.is_committed() or target.exposure() <= 0:
			continue
		var index := int(target.exposure() >= target.definition().required_exposure*.55)
		if _progress_art.get(process,-1) == index:
			continue
		_progress_art[process] = index
		_apply_sprite(PARTS.VESSELS[process],PARTS.art(PARTS.PROGRESS_ART[process][index]))

func _apply_sprite(id: String, art: Dictionary) -> void:
	var sprite: Sprite2D = component(id+"/control").visuals.get_node("Artwork")
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE*float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	_apparatus(raw if _supported_state(raw) else default_state())

func _checkpoint_attuned(id: String) -> bool:
	return active() and not _state.is_empty() and id in snapshot().checkpoint_progress.unlock_sequence

func _checkpoint_allowed(id: String) -> bool:
	return _checkpoint_attuned(id) and not world.player.carrying

func world_checkpoints() -> Array:
	var result := []
	for id in CHECKPOINTS:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor(REGION,id),
			"attuned":_checkpoint_attuned(id),"allowed":_checkpoint_allowed.bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _checkpoint_allowed(id) and world.activate(REGION,world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	if active() and _state.get("items",{}).get(PARTS.PLATE) == "player":
		var next := _state.duplicate(true)
		next.items[PARTS.PLATE] = PARTS.CRADLE
		_save(next)
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	for record in _disabled_reserves:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.set_deferred("collision_layer",record.layer)
	for prop in _hidden_reserves:
		if is_instance_valid(prop): prop.show()
	if is_instance_valid(_help): _help.queue_free()
	super._exit_tree()
