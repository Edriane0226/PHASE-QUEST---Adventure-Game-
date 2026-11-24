extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone2/skybridge_assembly.gd")
const STEAMWORKS = preload("res://Scripts/World/Zone2/steamworks_garden_world.gd")
const FINN = preload("res://Scripts/World/Learning/finn_challenge.gd")
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const REGION := PARTS.REGION
const CONNECTION := PARTS.CONNECTION
const CHECKPOINTS := ["C0", "C1", "C2", "C3"]
const DRIVE_SECONDS := 1.5
const PROCESSES := {PARTS.INLET:"melting", PARTS.PACK:"freezing",
	PARTS.BOILER:"boiling", PARTS.CONDENSER:"condensation"}
const BATCH := {"version":1, "material":"water", "liquid_measures":PARTS.MEASURES,
	"wheel_turned":true, "droplets_observed":true, "heat_input":"thermal", "heat_removed_by":"cryo"}
const ENGINE_OFFSETS := {
	"boiler":Vector2(-132,-48), "turbine":Vector2(-40,-48), "condenser":Vector2(56,-48),
	"tank":Vector2(148,-48), "drive":Vector2(-40,-5), "recipe":Vector2(56,65),
}

var finn = FINN.new(PARTS.QUESTIONS)
var points := {}
var travel: Node
var _markers := {}
var _labels := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _pipes: Node2D
var _flows := {}
var _pulse := 0.0
var _departing := false

func bind_skybridge(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	var index := 0
	for id in PARTS.RECIPE:
		var court: Vector2 = points.court1 if index < 3 else points.court2
		var x := float(index-1)*58.0 if index < 3 else (float(index)-3.5)*58.0
		points[id] = court + Vector2(x,-38)
		points["rack_"+id] = court + Vector2(x,42)
		index += 1
	points.rack_boiler_shell += Vector2(-20,0)
	points.rack_condenser_coil += Vector2(40,0)
	points.return_tank += Vector2(-20,0)
	points.rack_drive_belt += Vector2(20,0)
	points.inlet = points.court3 + Vector2(-49,-18)
	points.pack = points.court3 + Vector2(27,22)
	for id in ENGINE_OFFSETS:
		points[id] = points.court4 + ENGINE_OFFSETS[id]
	var route: Dictionary = host.connection(CONNECTION)
	if route.is_empty() or model.v(route.source_anchor).distance_to(points.exit) > 1.0:
		return _reject("Skybridge lift requires its authored departure approach.")
	travel = get_parent().context_provider
	if not bind(host, get_parent(), PARTS.definition(points), _completion_ready):
		return false
	chunk.checkpoint_provider = self
	_replace_reserves(model)
	for id in ["professor","recipe","finn","exit"]:
		var marker := Marker2D.new()
		marker.position = points[id]-chunk.ground_origin-Vector2(0,world.raised_surface(points[id]).height)
		chunk.add_child(marker)
		_markers[id] = marker
	for id in ["inlet","pack","boiler","turbine","condenser","tank","recipe"] + PARTS.RECIPE.keys():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-70,6)
		label.size.x = 140
		label.add_theme_font_size_override("font_size",9)
		label.add_theme_color_override("font_outline_color",Color("263e40"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	_build_pipes()
	sync_world_permissions()
	return true

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if placement.station not in [REGION+".court1",REGION+".court2",REGION+".court3",REGION+".court4"]:
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
				_disabled_reserves.append({"record":record,"layer":record.layer,"body_layer":record.body.collision_layer})
				record.layer = 0
				record.body.collision_layer = 0

func _build_pipes() -> void:
	_pipes = ANCHOR.new()
	_pipes.position = points.turbine
	_pipes.elevation = component("turbine/control").elevation
	_pipes.z_index = -1
	world.district_art_parent(chunk).add_child(_pipes)
	for pipe in [["boiler","turbine",Color("fff1cb")],["turbine","condenser",Color("e7cdac")],
			["condenser","tank",Color("7dc2d4")]]:
		var base := Line2D.new()
		base.points = PackedVector2Array([points[pipe[0]]-_pipes.position,points[pipe[1]]-_pipes.position])
		base.width = 11
		base.default_color = Color("687b77")
		base.antialiased = true
		_pipes.visuals.add_child(base)
		var flow := Line2D.new()
		flow.points = base.points
		flow.width = 4
		flow.default_color = pipe[2]
		flow.antialiased = true
		_pipes.visuals.add_child(flow)
		_flows[pipe[0]] = flow

func default_state() -> Dictionary:
	var state := super.default_state()
	state.finn = finn.initial_state()
	state.batch = {}
	state.departure = ""
	return state

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or raw.items.size() != PARTS.RECIPE.size() or not finn.valid(raw.get("finn")):
		return false
	var boiler := phase(raw,"boiler")
	var turbine := phase(raw,"turbine")
	var condenser := phase(raw,"condenser")
	var tank := phase(raw,"tank")
	var fitted := boiler != "unfitted"
	for id in PARTS.RECIPE:
		var owner: String = raw.items[id]
		if (fitted and owner != PARTS.fitted(id)) or (not fitted and owner not in [PARTS.source(id),PARTS.staged(id),"player"]):
			return false
	var tested := tank == "returned"
	return ((turbine != "unfitted") == fitted and (condenser != "unfitted") == fitted
		and (tank != "unfitted") == fitted and (phase(raw,"drive") == "fitted") == fitted
		and (not fitted or _supplies_prepared(raw))
		and (phase(raw,"inlet") == "fed") == (boiler in ["filled","liquid","gas","spent"])
		and (boiler == "spent") == (turbine == "turned")
		and (condenser not in ["gas","liquid","drained"] or turbine == "turned")
		and (phase(raw,"pack") == "spent") == (condenser in ["liquid","drained"])
		and (boiler not in ["filled","liquid","gas","spent"] or phase(raw,"pack") in ["solid","spent"])
		and tested == (condenser == "drained") and raw.get("batch") == (BATCH if tested else {})
		and (tested or raw.finn == finn.initial_state())
		and (raw.get("departure") == "" or (raw.get("departure") == CONNECTION and tested and finn.passed(raw.finn))))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].departure = CONNECTION
	var unlocked := ["C0"]
	if _parts_ready(state): unlocked.append("C1")
	if _parts_ready(state) and _supplies_prepared(state):
		unlocked.append("C2")
	if state.batch == BATCH: unlocked.append("C3")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,unlocked)
	result.checkpoint = unlocked.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _parts_ready(state: Dictionary) -> bool:
	return PARTS.RECIPE.keys().all(func(id): return state.items[id] in [PARTS.staged(id),PARTS.fitted(id)])

func _supplies_prepared(state: Dictionary) -> bool:
	return phase(state,"inlet") != "solid" and phase(state,"pack") != "liquid"

func _near(id: String) -> bool:
	var ground: Vector2 = world.player.position
	var at: Vector2 = points[id]
	if world.player.jump_elapsed >= 0 or ground.distance_to(at) > 43 or not world.world_contact_allowed(ground,at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if assemblies.has(id) and assemblies[id].bodies.has("control"):
		exclude.append(assemblies[id].bodies.control.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(ground,at,1|8,exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func action_allowed(id: String) -> bool:
	if _pulse > 0 or not _can_write() or world.player.action_elapsed >= 0:
		return false
	if _markers.has(id):
		return not world.player.carrying and _near(id) and (id != "exit" or _ready_to_depart())
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"feed": return _has_outcome(store.data.active_run.state,PARTS.INLET) and _has_outcome(store.data.active_run.state,PARTS.PACK)
		"wheel": return _has_outcome(store.data.active_run.state,PARTS.BOILER)
		"drain": return _verified_batch(store.data.active_run.state)
	return true

func world_context() -> Dictionary:
	if active() and not _state.is_empty():
		for id in _markers:
			if action_allowed(id):
				var captions := {"professor":"Ask Professor Reed","recipe":"Inspect engine recipe",
					"finn":"Talk to Finn","exit":"Depart on the lift"}
				return {"key":REGION+":"+id,"caption":captions[id],"target":_markers[id],"enabled":true,
					"allowed":action_allowed.bind(id),"invoke":commit_action.bind(id)}
		var local := super.world_context()
		if not local.is_empty():
			return local
	return travel.world_context() if is_instance_valid(travel) else {}

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor":
			if _state.finn.started and not finn.passed(_state.finn) and not _note_help():
				return false
			return world.input_adapter.open_lesson("skybridge")
		"finn": return _open_finn()
		"recipe": return _open_recipe()
		"exit": return _depart()
		"wheel":
			world.input_adapter.stop_all("wheel_test",true)
			_pulse = DRIVE_SECONDS
			return true
	world.input_adapter.stop_all("skybridge_action",true)
	if not action_allowed(id):
		return false
	var action: Dictionary = contract.actions[id]
	var next := _state.duplicate(true)
	var successes := []
	var events := []
	match action.kind:
		"pickup": next.items[action.item] = "player"
		"place": next.items[action.item] = PARTS.staged(action.item) if id.begins_with("stow_") else PARTS.source(action.item)
		"set": next.components[action.component].phase = action.value
	match id:
		"feed": next.components["inlet/control"].phase = "fed"
		"drain":
			next.components["condenser/control"].phase = "drained"
			next.batch = BATCH.duplicate()
			successes.append({"puzzle":"skybridge_return_test","type":"skybridge_return_test",
				"topic":"condensation","object":"skybridge_engine"})
			events.append({"id":"steam_engineer","members":[]})
	return _commit(next,successes,_events(events,id))

func _commit(next: Dictionary, successes: Array = [], events: Array = []) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,events,world):
		return true
	_feedback("Progress could not be saved. Try again.")
	return false

func _feedback(message: String) -> void:
	world.input_adapter.feedback = message
	world.input_adapter.refresh()

func flags_for(id: String) -> Dictionary:
	var flags := super.flags_for(id)
	if world.player.carrying or _pulse > 0:
		for key in flags:
			flags[key] = false
	return flags

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target) or world.player.carrying or _pulse > 0:
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var binding: Dictionary = contract.targets[outcome.id]
	var next := _state.duplicate(true)
	next.components[binding.component].phase = outcome.to_state
	if outcome.id == PARTS.CONDENSER:
		next.components["pack/control"].phase = "spent"
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(binding.events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	_feedback("Observation could not be saved. Apply the device again.")
	return false

static func _has_outcome(run_state: Dictionary, id: String) -> bool:
	var records: Variant = run_state.get("device_outcomes")
	var receipt: Variant = records.get(id) if records is Dictionary else null
	var process: String = PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	return (receipt is Dictionary and receipt.get("version") == 1 and receipt.get("id") == id
		and receipt.get("process") == process and receipt.get("material") == "water"
		and receipt.get("from_state") == rule.from and receipt.get("to_state") == rule.to)

static func _verified_batch(run_state: Dictionary) -> bool:
	return PROCESSES.keys().all(func(id): return _has_outcome(run_state,id))

func _can_assemble() -> bool:
	return (STEAMWORKS.engine_blueprint_unlocked(store.data) and phase(_state,"boiler") == "unfitted"
		and _parts_ready(_state) and _supplies_prepared(_state))

func _open_recipe(status := "") -> bool:
	var rows := []
	for id in PARTS.RECIPE:
		var owner: String = _state.items[id]
		var location := "Fitted" if owner == PARTS.fitted(id) else ("Delivered" if owner == PARTS.staged(id) else "Recover locally")
		rows.append({"title":PARTS.RECIPE[id],"text":location})
	if status.is_empty():
		status = "Steamworks blueprint ready" if STEAMWORKS.engine_blueprint_unlocked(store.data) else "Record the blueprint at Steamworks."
		if _parts_ready(_state) and not _supplies_prepared(_state):
			status = "Melt feedwater and freeze the separate pack at the supply court."
	var layout := "craft.z2_missing"
	if phase(_state,"boiler") != "unfitted":
		layout = "craft.z2_fitted" if _state.batch.is_empty() else "craft.z2_tested"
	return world.input_adapter.open_provider_panel(self,_recipe_intent,layout,{
		"title":"Skybridge Engine recipe","body":"Recover the exact five parts to their local delivery slots.",
		"status":status,"rows":rows,"actions":[{"id":"assemble","label":"Fit all five parts","enabled":_can_assemble()}]})

func _recipe_intent(id: String, _payload: Dictionary) -> void:
	if id != "assemble":
		return
	world.input_adapter.close_panel()
	if not action_allowed("recipe") or not _can_assemble():
		return
	var next := _state.duplicate(true)
	for part in PARTS.RECIPE:
		next.items[part] = PARTS.fitted(part)
	for component_id in ["boiler","condenser","tank"]:
		next.components[component_id+"/control"].phase = "empty"
	next.components["turbine/control"].phase = "idle"
	next.components["drive/control"].phase = "fitted"
	if not _commit(next):
		_open_recipe("Save failed. All five parts are still in their delivery slots.")

func _open_finn() -> bool:
	if not _test_passed():
		return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.wait",{
			"body":"Fit the engine, turn the wheel and collect liquid in the return tank. Then come see me.",
			"actions":[],"status":""})
	if not _state.finn.started:
		var next := _state.duplicate(true)
		next.finn.started = true
		if not _commit(next):
			return false
	return _show_question(finn.review_index(_state.finn),true)

func _test_passed() -> bool:
	return _state.batch == BATCH and _verified_batch(store.data.active_run.get("state",{}))

func _show_question(index: int, feedback: bool, status := "") -> bool:
	if index == PARTS.QUESTIONS.size():
		return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.z2_passed",{
			"body":"All four answers are correct. Board at the Skybridge lift approach.",
			"status":"4 / 4 correct","actions":[]})
	var model: Dictionary = finn.question_view(_state.finn,index,feedback)
	if finn.passed(_state.finn):
		model.actions = model.actions.filter(func(action): return action.id != "help")
	model.context_key = str(index)
	if not status.is_empty():
		model.status = status
	return world.input_adapter.open_provider_panel(self,_finn_intent,"finn.z2_question",model)

func _note_help() -> bool:
	if _state.finn.help_used:
		return true
	var next := _state.duplicate(true)
	next.finn.help_used = true
	return _commit(next)

func _finn_intent(id: String, payload: Dictionary) -> void:
	if not active() or _state.is_empty() or not _test_passed() or not _near("finn"):
		return
	var current: int = finn.passed_count(_state.finn)
	var index := str(payload.get("context_key","")).to_int() if str(payload.get("context_key","")).is_valid_int() else -1
	match id:
		"next_question":
			var next := _state.duplicate(true)
			if not finn.acknowledge_review(next.finn,index): return
			if _commit(next): _show_question(finn.review_index(_state.finn),true)
			else: _show_question(index,true,"Feedback could not be acknowledged. Try again.")
		"back_to_finn": _show_question(finn.review_index(_state.finn),true)
		"retry_question":
			if index == current: _show_question(current,false)
		"help":
			if index < 0 or index >= PARTS.QUESTIONS.size() or index != current:
				return
			if not _note_help():
				_show_question(current,true,"Help is free. The save failed. Try again.")
				return
			var question: Dictionary = PARTS.QUESTIONS[index]
			world.input_adapter.open_provider_panel(self,_finn_intent,"guides.library",{
				"title":"Finn · free help","speaker":"finn","body":question.feedback[question.correct],
				"search":false,"rows":[],"actions":[{"id":"back_to_finn","label":"Back to Finn","enabled":true}]})
		"submit":
			var next := _state.duplicate(true)
			if not finn.record(next.finn,index,str(payload.get("selected_choice",""))):
				return
			var events := _events([{"id":"clear_explanation","event":"first_attempts","members":[]}],"finn") if finn.perfect(next.finn) else []
			if _commit(next,[],events):
				_show_question(index,true)
			else:
				_show_question(current,false,"Answer could not be saved. Try again.")

func _ready_to_depart() -> bool:
	return (_state.departure.is_empty() and _test_passed() and finn.passed(_state.finn)
		and STEAMWORKS.engine_blueprint_unlocked(store.data))

func _completion_ready(state: Dictionary) -> bool:
	return (_departing and state.departure.is_empty() and _ready_to_depart()
		and not world.player.carrying and world.player.action_elapsed < 0 and _near("exit"))

func _depart() -> bool:
	_departing = true
	var committed := finish()
	_departing = false
	if not committed:
		_feedback("Departure could not be saved. Board again.")
		return false
	if not world.start_transit(CONNECTION):
		_feedback("Board at the lift approach to resume departure.")
	return true

func lift_earned() -> bool:
	var saved := _archived_run_state()
	var state: Variant = saved.get(STATE_KEY)
	return (store.is_level_complete(store.ZONES[1],6) and _supported_state(state)
		and state.departure == CONNECTION and _verified_batch(saved))

func _archived_run_state() -> Dictionary:
	var state: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{})
	return state if state is Dictionary else {}

func _present_apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	for id in PARTS.RECIPE:
		var owner: String = state.items[id]
		component(id+"/control").visible = owner in [PARTS.source(id),PARTS.staged(id)]
		_labels[id].text = PARTS.RECIPE[id]
	var boiler := phase(state,"boiler")
	var condenser := phase(state,"condenser")
	_labels.inlet.text = {"solid":"FEEDWATER ICE","liquid":"LIQUID FEEDWATER","fed":"FEEDWATER SUPPLIED"}[phase(state,"inlet")]
	_labels.pack.text = {"liquid":"LIQUID COOLANT","solid":"FROZEN COOLANT","spent":"COOLANT SPENT"}[phase(state,"pack")]
	_labels.boiler.text = {"unfitted":"BOILER SOCKET","empty":"BOILER EMPTY","filled":"GUARD OPEN",
		"liquid":"ADD HEAT","gas":"VAPOR READY","spent":"HEAT OFF"}[boiler]
	_labels.turbine.text = {"unfitted":"TURBINE SOCKET","idle":"WHEEL IDLE","turned":"WHEEL STOPPED"}[phase(state,"turbine")]
	_labels.condenser.text = {"unfitted":"COIL SOCKET","empty":"CONDENSER","gas":"EXHAUST GAS",
		"liquid":"DROPLETS","drained":"DRAINED"}[condenser]
	_labels.tank.text = {"unfitted":"TANK SOCKET","empty":"TANK EMPTY","returned":"2 MEASURES"}[phase(state,"tank")]
	_labels.recipe.text = "ENGINE RECIPE"
	_pipes.visible = boiler != "unfitted"
	_flows.boiler.hide()
	_flows.turbine.visible = condenser == "gas"
	_flows.condenser.visible = condenser == "drained"
	var task := "Recover five parts at the north and west courts"
	if _parts_ready(state):
		task = "Fit five parts at the engine recipe desk" if _supplies_prepared(state) else "Melt feedwater and freeze the separate pack"
	match boiler:
		"empty": task = "Connect feedwater and cooling at the boiler"
		"filled": task = "Close the boiler guard and leave the vent open"
		"liquid": task = "Boil the feedwater with Thermal"
		"gas": task = "Send vapor through the wheel"
		"spent": task = "Route the exhaust to the condenser"
	match condenser:
		"gas": task = "Use Cryo at the condenser to form droplets"
		"liquid": task = "Drain the droplets into the return tank"
		"drained": task = "See Finn after the test"
	if finn.passed(state.finn): task = "Depart from the Skybridge lift approach"
	var departed: bool = state.departure == CONNECTION
	chunk.quests = [{"text":"Skybridge lift ready" if departed else task,"state":"done" if departed else "active"}]
	chunk.tutorial = ""

func present() -> void:
	super.present()
	if not _state.is_empty():
		_present_apparatus(_state)

func _process(delta: float) -> void:
	if _pulse <= 0:
		return
	if not _can_write() or not _near("turbine"):
		_pulse = 0
		present()
		return
	_pulse = maxf(_pulse-delta,0)
	if _pulse > 0:
		var frame := "model_turbine_turn_a" if int(_pulse*12)%2 == 0 else "model_turbine_turn_b"
		var sprite: Sprite2D = component("turbine/control").visuals.get_node("Artwork")
		var art := PARTS.KIT.art(frame)
		sprite.texture = load(art.path)
		sprite.scale = Vector2.ONE*float(art.scale)
		sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale
		_labels.turbine.text = "WHEEL TURNING"
		_flows.boiler.show()
		return
	var next := _state.duplicate(true)
	next.components["boiler/control"].phase = "spent"
	next.components["turbine/control"].phase = "turned"
	if not _commit(next):
		present()

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var saved: Variant = _archived_run_state().get(STATE_KEY)
	var state: Dictionary = saved if _supported_state(saved) else default_state()
	var locations := {}
	for id in assemblies:
		locations[id+"/control"] = points[id]
	for assembly in assemblies.values():
		assembly.present(state.components,state.items,locations)
	_present_apparatus(state)

func _checkpoint_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

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

func suspend() -> void:
	_pulse = 0
	super.suspend()

func _exit_tree() -> void:
	for entry in _disabled_reserves:
		entry.record.layer = entry.layer
		if is_instance_valid(entry.record.body):
			entry.record.body.collision_layer = entry.body_layer
	for prop in _hidden_reserves:
		if is_instance_valid(prop): prop.show()
	for marker in _markers.values():
		if is_instance_valid(marker): marker.queue_free()
	if is_instance_valid(_pipes): _pipes.queue_free()
	super._exit_tree()
