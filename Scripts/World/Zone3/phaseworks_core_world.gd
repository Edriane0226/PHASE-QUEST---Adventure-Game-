extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/phaseworks_core_assembly.gd")
const OBSERVATORY = preload("res://Scripts/World/Zone3/observatory_world.gd")
const FINN = preload("res://Scripts/World/Learning/finn_challenge.gd")
const REGION := PARTS.CORE
const CHECKPOINTS := ["C0","C1","C2","C3"]
const WATER := ["inlet","jig"]
const VAPOR := ["seal","boiler","condenser"]
const TEST := ["port","source","collector"]
const WATER_PARTS := ["housing","collector_plate"]
const VAPOR_PARTS := ["vapor_tube","calibrated_sensor"]
const RACK_NAMES := {"housing":"HOUSING","collector_plate":"PLATE","vapor_tube":"TUBE",
	"calibrated_sensor":"SENSOR","water_ice_sample":"ICE"}
const PART_WINGS := {"housing":"water","collector_plate":"water","vapor_tube":"vapor",
	"calibrated_sensor":"vapor","water_ice_sample":"frost"}
const MEASURED_FROST := {"version":1,"material":"water","solid_measures":1,"liquid_measures":0}
const LINES := {"inlet":"jig","boiler":"wheel","wheel":"condenser","source":"collector"}
const PROGRESS_ART := {"inlet":"normal_warmer_melting_late","seal":"utility_seal_drying",
	"boiler":"utility_boiler_boil_b","port":"delivery_port_clearing","source":"cartridge_source_shrinking",
	"collector":"cartridge_depositing","scanner":"exit_scanner_removing"}
const TITLES := {"inlet":"WATER SUPPLY","jig":"ASSEMBLY JIG","seal":"DAMP SEAL","boiler":"GUARDED BOILER",
	"condenser":"EXHAUST COLLECTOR","wheel":"LOCKER WHEEL","port":"DELIVERY PORT","source":"CARTRIDGE SOURCE",
	"collector":"FROST COLLECTOR","scanner":"EXIT SCANNER","recipe":"CARTRIDGE RECIPE","exit":"CAMPAIGN RECORD"}

var points := {}
var finn := FINN.new(PARTS.QUESTIONS)
var _markers := {}
var _labels := {}
var _lines := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _gate: Dictionary
var _gate_art: Sprite2D
var _growing := {}
var _practice: Dictionary
var _pulse := 0.0

func bind_core(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	_place_modules()
	if not bind(host,get_parent(),PARTS.core_definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	for id in ["professor","finn","entry"]:
		var marker := Marker2D.new()
		marker.position = points[id]-chunk.ground_origin-Vector2(0,world.raised_surface(points[id]).height)
		chunk.add_child(marker)
		_markers[id] = marker
	for id in assemblies:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-75,8)
		label.size.x = 150
		label.z_index = 1
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	for id in LINES:
		var from: Node2D = component(id+"/control")
		var to: Node2D = component(LINES[id]+"/control")
		var offset := to.position-from.position-Vector2(0,to.elevation-from.elevation)
		var pipe := Line2D.new()
		pipe.points = PackedVector2Array([Vector2.ZERO,Vector2(offset.x*.5,offset.y),offset])
		pipe.width = 4
		pipe.z_index = -1
		from.visuals.add_child(pipe)
		_lines[id] = pipe
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _place_modules() -> void:
	points.merge({
		"inlet":points.court1+Vector2(85,-45),"jig":points.court1+Vector2(87,-5),
		"housing":points.court1+Vector2(40,126),"rack_housing":points.court1+Vector2(-10,90),
		"collector_plate":points.court1+Vector2(42,85),"rack_collector_plate":points.court1+Vector2(98,60),
		"seal":points.court2+Vector2(-85,-59),"boiler":points.court2+Vector2(-91,-1),
		"condenser":points.court2+Vector2(10,95),"wheel":points.court2+Vector2(27,26),
		"vapor_tube":points.court2+Vector2(-89,27),"rack_vapor_tube":points.court2+Vector2(-38,57),
		"calibrated_sensor":points.court2+Vector2(87,93),"rack_calibrated_sensor":points.court2+Vector2(27,167),
		"port":points.court3+Vector2(94,92),"port_control":points.court3+Vector2(85,36),
		"water_ice_sample":points.court3+Vector2(105,71),"rack_water_ice_sample":points.court3+Vector2(67,108),
		"recipe":points.court4+Vector2(-29,5),"source":points.court4+Vector2(-65,-40),
		"collector":points.court4+Vector2(30,-27),"source_control":points.court4+Vector2(-80,50),
		"collector_control":points.court4+Vector2(70,46),"scanner":points.court5+Vector2(-30,39),
		"scanner_control":points.court5+Vector2(76,66),
	})

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if not placement.station.begins_with(REGION+".court"):
			continue
		var at: Vector2 = model.v(placement.at)
		var gate: bool = placement.asset == "final_exit_locked"
		for prop in world.props:
			if (prop.get_meta("station_id","") == placement.station and prop.get_meta("asset_id","") == placement.asset
					and prop.position.distance_to(at) < 1):
				if gate:
					_gate_art = prop.visuals.get_node("Artwork")
				else:
					prop.hide()
					_hidden_reserves.append(prop)
		for record in model.blockers:
			if (record.get("station","") != placement.station or record.bounds.get_center().distance_to(at) >= 1
					or not is_instance_valid(record.get("body"))):
				continue
			if gate:
				_gate = record
			else:
				record.layer = 0
				record.body.collision_layer = 0
				_disabled_reserves.append(record)

func default_state() -> Dictionary:
	var result := super.default_state()
	result.finn = finn.initial_state()
	return result

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _set_phase(state: Dictionary, id: String, value: String) -> void:
	state.components[id+"/control"].phase = value

func _parts_staged(state: Dictionary) -> bool:
	return PARTS.RECIPE.keys().all(func(id): return state.items[id] == PARTS.staged(id))

func _parts_seated(state: Dictionary, ids: Array) -> bool:
	return ids.all(func(id): return state.items[id] in [PARTS.staged(id),PARTS.FITTED])

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not finn.valid(raw.get("finn")) or raw.items.size() != PARTS.RECIPE.size():
		return false
	var fitted := phase(raw,"recipe") == "fitted"
	for id in PARTS.RECIPE:
		var owner: String = raw.items[id]
		if owner not in [PARTS.origin(id), "player", PARTS.staged(id), PARTS.FITTED] or (owner == PARTS.FITTED) != fitted:
			return false
	var source := phase(raw,"source")
	var collector := phase(raw,"collector")
	var scanner := phase(raw,"scanner")
	var exhausted := phase(raw,"boiler") == "spent"
	var sent := collector == "sent"
	return ((phase(raw,"jig") != "empty") == (phase(raw,"inlet") == "fed")
		and (phase(raw,"boiler") == "unguarded" or phase(raw,"seal") == "gas")
		and exhausted == (phase(raw,"wheel") == "driven") and exhausted == (phase(raw,"condenser") != "empty")
		and fitted == (source != "empty") and (source == "sent") == (collector != "empty")
		and sent == (scanner != "empty")
		and raw.get("frost",{}) == (MEASURED_FROST if collector in ["solid","sent"] else {})
		and (not raw.finn.started or not raw.get("frost",{}).is_empty())
		and (phase(raw,"scanner_control") == "off" or (finn.passed(raw.finn) and scanner in ["solid","gas"]))
		and (scanner != "gas" or phase(raw,"scanner_control") == "low")
		and (phase(raw,"exit") == "closed" or scanner == "gas"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		_set_phase(result[STATE_KEY],"exit","open")
	var earned := ["C0"]
	if _parts_seated(state,WATER_PARTS):
		earned.append("C1")
	if _parts_staged(state) or phase(state,"recipe") == "fitted": earned.append("C2")
	if state.get("frost") == MEASURED_FROST: earned.append("C3")
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

func _verified(bench: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var id := PARTS.target_id(bench)
	var process: String = PARTS.BENCHES[bench]
	var rule: Dictionary = RULES.PROCESSES[process]
	return records is Dictionary and records.get(id) == {"version":1,"id":id,"material":"water","process":process,
		"from_state":rule.from,"to_state":rule.to,"capability":rule.capability,"puzzle_type":rule.type}

func _water_ready() -> bool:
	return WATER.all(_verified) and _parts_seated(_state,WATER_PARTS)

func _vapor_ready() -> bool:
	return VAPOR.all(_verified) and _parts_seated(_state,VAPOR_PARTS) and _water_ready()

func _part_ready(id: String) -> bool:
	match PART_WINGS[id]:
		"water": return WATER.all(_verified)
		"vapor": return VAPOR.all(_verified)
		"frost": return _verified("port")
	return false

func _test_passed(state: Dictionary) -> bool:
	return (state.get("frost") == MEASURED_FROST and phase(state,"recipe") == "fitted"
		and WATER.all(_verified) and VAPOR.all(_verified) and TEST.all(_verified))

func _ready_to_fit() -> bool:
	return (phase(_state,"recipe") == "open" and _parts_staged(_state) and OBSERVATORY.cartridge_blueprint_unlocked(store.data)
		and WATER.all(_verified) and VAPOR.all(_verified) and _verified("port"))

func _completion_ready(state: Dictionary) -> bool:
	return (_test_passed(state) and finn.passed(state.finn) and phase(state,"scanner") == "gas"
		and _verified("scanner") and OBSERVATORY.cartridge_blueprint_unlocked(store.data))

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func action_allowed(id: String) -> bool:
	if not _can_write() or world.player.action_elapsed >= 0 or world.player.jump_elapsed >= 0:
		return false
	if _markers.has(id):
		return not world.player.carrying and _near(id)
	if not contract.actions.has(id):
		return false
	if id.begins_with("return_"):
		var item := id.trim_prefix("return_")
		return _state.items[item] == "player" and _near(item)
	if id.begins_with("seat_"):
		return world.player.carrying and _state.items.values().has("player") and _near("rack_"+id.trim_prefix("seat_"))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	if id.begins_with("take_"): return _part_ready(id.trim_prefix("take_"))
	match id:
		"fill": return _verified("inlet")
		"spread","guard": return _water_ready()
		"drive": return _verified("boiler")
		"port_setup": return _vapor_ready()
		"route": return _verified("source") and phase(_state,"collector") == "empty"
		"send","insert": return _test_passed(_state)
		"power": return _test_passed(_state) and finn.passed(_state.finn)
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	var captions := {"entry":"Inspect frost-cartridge recipe","professor":"Ask Professor Aster","finn":"Talk to Finn"}
	for id in _markers:
		if action_allowed(id):
			return {"key":REGION+":"+id,"caption":captions[id],
				"target":_markers[id],"enabled":true,"allowed":action_allowed.bind(id),"invoke":commit_action.bind(id)}
	return super.world_context()

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	var bench := id.trim_prefix("phaseworks_")
	var process: String = PARTS.BENCHES[bench]
	var ready: bool = sample.state == RULES.PROCESSES[process].from
	if bench in VAPOR: ready = ready and _water_ready()
	if bench == "port": ready = ready and _vapor_ready()
	if bench == "scanner": ready = ready and _test_passed(_state) and finn.passed(_state.finn)
	if bench in ["port","source","collector","scanner"]:
		var setting := phase(_state,bench+"_control")
		var controlled := setting == ("cold" if bench == "collector" else "low")
		sample.merge({"sealed":controlled,"instrumented":true,"temperature_controlled":controlled,
			"pressure_regime":("high" if setting == "cold" else "low") if controlled else "normal",
			"heat_flow":RULES.PROCESSES[process].heat if controlled else "none","liquid_present":false},true)
	if bench == "condenser":
		sample.pane_c = 8
		sample.pressure_regime = "normal"
	sample.amount = 1 if ready else 0
	return sample

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var bench: String = contract.targets[outcome.id].component.get_slice("/",0)
	var next := _state.duplicate(true)
	_set_phase(next,bench,outcome.to_state)
	var events := [{"id":"six_changes","members":[outcome.process]}]
	if bench == "collector":
		next.frost = MEASURED_FROST.duplicate()
		events.append({"id":"frost_engineer","members":[]})
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	present()
	_feedback("Reading could not be saved. Try Fire again.")
	return false

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("core")
		"finn": return _open_finn()
		"recipe","entry": return _open_recipe()
		"exit": return _finish_core()
	world.input_adapter.stop_all("core_action",true)
	if not action_allowed(id):
		return false
	var action: Dictionary = contract.actions[id]
	var next := _state.duplicate(true)
	match action.kind:
		"pickup": next.items[action.item] = "player"
		"place":
			var held: String = next.items.find_key("player")
			if id.begins_with("return_"):
				next.items[held] = PARTS.origin(held)
				return _save(next)
			next.items[held] = PARTS.staged(held) if held == action.item else PARTS.origin(held)
			if not _save(next): return false
			if held != action.item: _feedback("Wrong slot. Part returned to its pickup point.")
			return true
		"set": next.components[action.component].phase = action.value
	match id:
		"fill": _set_phase(next,"inlet","fed")
		"drive":
			_set_phase(next,"boiler","spent")
			_set_phase(next,"condenser","gas")
		"route": _set_phase(next,"source","sent")
		"send": _set_phase(next,"scanner","arrived")
	if not _save(next): return false
	if id == "drive": _pulse = 1.25
	return true

func _open_recipe(status := "") -> bool:
	var rows := []
	for id in PARTS.RECIPE:
		var owner: String = _state.items[id]
		var location := "Recover locally"
		if owner == PARTS.staged(id): location = "Seated"
		if owner == PARTS.FITTED: location = "Installed"
		rows.append({"title":PARTS.RECIPE[id],"text":location})
	var layout := "craft.z3_missing"
	if phase(_state,"recipe") == "fitted":
		layout = "craft.z3_tested" if _test_passed(_state) else "craft.z3_fitted"
	if status.is_empty():
		status = "Observatory blueprint verified" if OBSERVATORY.cartridge_blueprint_unlocked(store.data) else "Earn the Observatory blueprint."
	return world.input_adapter.open_provider_panel(self,_recipe_intent,layout,{
		"title":"Frost cartridge","body":"Seat the five parts in their wing racks, then fit the cartridge.",
		"rows":rows,"status":status,"actions":[{"id":"assemble","label":"Fit all five parts","enabled":_near("recipe") and _ready_to_fit()}]})

func _recipe_intent(id: String, _payload: Dictionary) -> void:
	if id != "assemble":
		return
	world.input_adapter.close_panel()
	if not action_allowed("recipe") or not _ready_to_fit():
		return
	var next := _state.duplicate(true)
	for item in PARTS.RECIPE:
		next.items[item] = PARTS.FITTED
	_set_phase(next,"recipe","fitted")
	_set_phase(next,"source","solid")
	if not _save(next):
		_open_recipe("Save failed. All five parts are still seated.")

func _open_finn() -> bool:
	_practice.clear()
	if not _test_passed(_state):
		return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.wait",{
			"body":"Fit and test the cartridge. Bring it to the scanner, then come see me.","actions":[]})
	if phase(_state,"scanner") in ["empty","arrived"]:
		return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.wait",{
			"body":"Insert your tested cartridge in the scanner first.","actions":[]})
	if not _state.finn.started:
		var next := _state.duplicate(true)
		next.finn.started = true
		if not _save(next): return false
	return _show_question(finn.review_index(_state.finn),true)

func _show_question(index: int, feedback: bool, status := "") -> bool:
	var answers: Dictionary = _practice if not _practice.is_empty() else _state.finn
	if index == PARTS.QUESTIONS.size():
		_practice.clear()
		var instruction := "Power the scanner and use Vacuum."
		if phase(_state,"scanner") == "gas": instruction = "The scanner verified your cartridge."
		return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.z3_passed",{
			"body":instruction,"status":"6 / 6 correct",
			"actions":[{"id":"practice","label":"Replay for practice","enabled":true}]})
	var model: Dictionary = finn.question_view(answers,index,feedback)
	model.context_key = str(index)
	if not status.is_empty(): model.status = status
	return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.z3_question",model)

func _finn_intent(id: String, payload: Dictionary) -> void:
	if not active() or not _near("finn") or not _state.finn.started or not _test_passed(_state):
		return
	var answers: Dictionary = _practice if not _practice.is_empty() else _state.finn
	var current: int = finn.passed_count(answers)
	var raw := str(payload.get("context_key",""))
	var index := raw.to_int() if raw.is_valid_int() else -1
	match id:
		"practice":
			if not finn.passed(_state.finn): return
			_practice = finn.initial_state()
			_practice.started = true
			_show_question(0,false)
		"next_question":
			if not _practice.is_empty():
				if finn.acknowledge_review(_practice,index): _show_question(finn.review_index(_practice),true)
				return
			var next := _state.duplicate(true)
			if not finn.acknowledge_review(next.finn,index): return
			if _save(next): _show_question(finn.review_index(_state.finn),true)
			else: _show_question(index,true,"Feedback could not be acknowledged. Try again.")
		"back_to_finn": _show_question(finn.review_index(answers),true)
		"retry_question":
			if index == current: _show_question(current,false)
		"help":
			if index not in range(PARTS.QUESTIONS.size()) or index != current: return
			if _practice.is_empty() and not _state.finn.help_used:
				var helped := _state.duplicate(true)
				helped.finn.help_used = true
				if not _save(helped):
					_show_question(current,true,"Free help could not be saved. Try again.")
					return
			var question: Dictionary = PARTS.QUESTIONS[index]
			world.input_adapter.open_provider_panel(self,_finn_intent,"guides.library",{
				"title":"Finn · free help","speaker":"finn","body":question.feedback[question.correct],
				"search":false,"rows":[],"actions":[{"id":"back_to_finn","label":"Back to Finn"}]})
		"submit":
			var choice := str(payload.get("selected_choice",""))
			if not _practice.is_empty():
				if finn.record(_practice,index,choice): _show_question(index,true)
				return
			var next := _state.duplicate(true)
			if not finn.record(next.finn,index,choice): return
			var events := _events([{"id":"clear_explanation","event":"first_attempts","members":[]}],"finn") if finn.perfect(next.finn) else []
			if _save(next,events):
				_show_question(index,true)
			else:
				_show_question(current,false,"Answer could not be saved. Try again.")

func _finish_core() -> bool:
	if not finish():
		_feedback("Campaign result could not be saved. Try again.")
		return false
	if store.enter_world_subregion(world,REGION):
		refresh_binding()
		world.input_adapter.open_provider_panel(self,_finish_intent,"completion.campaign_complete",{
			"title":"Phase Quest complete","body":"The scanner verified the cartridge. All three zones remain open to explore.",
			"status":"%d / 18 stars" % store.total_stars(),"actions":[{"id":"return_world","label":"Keep exploring"}]})
	return true

func _finish_intent(id: String, _payload: Dictionary) -> void:
	if id == "return_world": world.input_adapter.close_panel()

func _save(next: Dictionary, events := []) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),[],events,world):
		return true
	_feedback("Progress could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var view := state.duplicate(true)
	var locations := {}
	for id in assemblies:
		locations[id+"/control"] = points[id]
	for id in PARTS.RECIPE:
		if state.items[id] in [PARTS.staged(id),PARTS.FITTED]: _set_phase(view,"rack_"+id,"seated")
	for assembly in assemblies.values(): assembly.present(view.components,view.items,locations)
	for id in PARTS.RECIPE:
		var owner: String = state.items[id]
		var staged := owner == PARTS.staged(id)
		var available: bool
		match PART_WINGS[id]:
			"water": available = phase(state,"jig") == "solid"
			"vapor": available = phase(state,"condenser") == "liquid"
			"frost": available = phase(state,"port") == "gas"
		component(id+"/control").visible = available and owner == PARTS.origin(id)
		_labels[id].text = PARTS.RECIPE[id].to_upper()
		_labels["rack_"+id].text = RACK_NAMES[id]+(" SEATED" if staged or owner == PARTS.FITTED else " SLOT")
	for id in TITLES: _labels[id].text = TITLES[id]
	for bench in PARTS.BENCHES:
		var rule: Dictionary = RULES.PROCESSES[PARTS.BENCHES[bench]]
		if phase(state,bench) == rule.to:
			_labels[bench].text = "%s → %s\nHEAT %s" % [rule.from.to_upper(),rule.to.to_upper(),rule.heat.to_upper()]
	if phase(state,"condenser") == "liquid": _labels.condenser.text = "+8°C · LIQUID 1"
	if phase(state,"source") == "gas": _labels.source.text = "CAPTURED GAS 1\nLIQUID 0"
	if phase(state,"collector") == "solid": _labels.collector.text = "MEASURED FROST 1\nLIQUID 0"
	if phase(state,"scanner") == "arrived": _labels.scanner.text = "CARTRIDGE RECEIVED"
	if phase(state,"scanner") == "gas": _labels.scanner.text = "FROST 0 · LIQUID 0\nABSENCE SIGNAL"
	var active_lines := {"inlet":phase(state,"inlet") == "fed","boiler":phase(state,"boiler") == "gas",
		"wheel":phase(state,"condenser") == "gas","source":phase(state,"collector") == "gas"}
	for id in LINES:
		_lines[id].default_color = Color("8bd3e2") if active_lines[id] else Color("647a84")
	for bench in ["port","source","collector","scanner"]:
		var id: String = bench+"_control"
		_labels[id].text = {"off":"STANDBY","low":"LOW · HEAT IN","cold":"REGULATED · HEAT OUT"}[phase(state,id)]
	var gate_open := phase(state,"scanner") == "gas"
	if not _gate.is_empty() and is_instance_valid(_gate.body):
		_gate.layer = 0 if gate_open else _gate.original_layer
		_gate.body.set_deferred("collision_layer",_gate.layer)
	if is_instance_valid(_gate_art):
		_artwork(_gate_art,PARTS.art("final_exit_allowed" if gate_open else "final_exit_locked"))
	var task := "Water Wing · fill and freeze the jig"
	if phase(state,"jig") == "solid": task = "Water Wing · seat housing and plate"
	if _parts_seated(state,WATER_PARTS): task = "Vapor Wing · dry seal, drive wheel, collect liquid"
	if phase(state,"condenser") == "liquid": task = "Vapor Wing · seat tube and sensor"
	if _parts_seated(state,VAPOR_PARTS):
		task = "Frost Wing · clear port and seat ice"
	if _parts_staged(state): task = "Recipe bench · fit cartridge"
	if phase(state,"recipe") == "fitted": task = "Craft test · capture vapor and measure frost"
	if state.has("frost"): task = "Send cartridge and insert at scanner"
	if phase(state,"scanner") == "solid": task = "Finn · answer all six questions"
	if finn.passed(state.finn): task = "Scanner · power and use Vacuum"
	if gate_open: task = "Campaign desk · record completion"
	var done := phase(state,"exit") == "open"
	chunk.quests = [{"text":"Phase Quest complete" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func _artwork(sprite: Sprite2D, art: Dictionary) -> void:
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE*float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale

func present() -> void:
	if _state.is_empty(): return
	_growing.clear()
	_apparatus(_state)
	_update_carry()

func _process(delta: float) -> void:
	if not _can_write() or _labels.is_empty(): return
	if _pulse > 0.0:
		_pulse = maxf(0.0,_pulse-delta)
		var id := "model_turbine_latched" if _pulse == 0.0 else ("model_turbine_turn_a" if int(_pulse*20)%2 == 0 else "model_turbine_turn_b")
		_artwork(component("wheel/control").visuals.get_node("Artwork"),PARTS.STEAMWORKS.KIT.art(id))
	for bench in PROGRESS_ART:
		var target: Node = targets.get(PARTS.target_id(bench))
		if is_instance_valid(target) and target.exposure() > 0 and not target.is_committed() and not _growing.has(bench):
			_growing[bench] = true
			_artwork(component(bench+"/control").visuals.get_node("Artwork"),PARTS.art(PROGRESS_ART[bench]))

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty(): return
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
	if active() and _state.get("items",{}).values().has("player"):
		var next := _state.duplicate(true)
		var held: String = next.items.find_key("player")
		next.items[held] = PARTS.origin(held)
		_save(next)
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	var blockers := _disabled_reserves.duplicate()
	if not _gate.is_empty(): blockers.append(_gate)
	for record in blockers:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.set_deferred("collision_layer",record.layer)
	for prop in _hidden_reserves:
		if is_instance_valid(prop): prop.show()
	if is_instance_valid(_gate_art): _artwork(_gate_art,PARTS.art("final_exit_locked"))
	for marker in _markers.values():
		if is_instance_valid(marker): marker.queue_free()
	super._exit_tree()
