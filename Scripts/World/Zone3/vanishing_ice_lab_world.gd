extends "res://Scripts/World/Learning/subregion_adapter.gd"

const PARTS = preload("res://Scripts/World/Zone3/vanishing_ice_assembly.gd")
const REGION := PARTS.REGION
const CHECKPOINTS := ["C0","C1","C2"]
const REPLACED := ["condition_gauge_normal","heat_exchanger_off","preview_source_solid","sublimation_solid",
	"sample_slot_frozen","utility_seal_wet","utility_boiler_filled","recovery_condenser_warm","utility_tank_empty"]
const UTILITY_RETURN := {"version":1,"source":PARTS.BOILER,"material":"water","measures":PARTS.MEASURES,
	"states":["liquid","gas","liquid"],"pane_c":8}
const QUESTION := {"choices":["Yes. It became a puddle first.","No. It changed directly into captured gas."],
	"correct":1,"feedback":"The gas indicator rose while the liquid sensor stayed at zero. The water changed directly from solid to gas."}
const EXPOSURE_ART := {
	"observation":["sublimation_shrinking_early","sublimation_shrinking_late"],
	"plug":["sample_slot_clearing","sample_slot_clearing"],
	"seal":["utility_seal_drying","utility_seal_drying"],
	"boiler":["utility_boiler_boil_a","utility_boiler_boil_b"],
}

var points := {}
var _markers := {}
var _labels := {}
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _visible_exposure := {}
var _return_line: Line2D
var _travel: Node

func bind_vanishing_lab(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	points.merge({
		"observation":points.court1+Vector2(58,-36), "plug":points.court1+Vector2(163,-36),
		"cover":points.court1+Vector2(30,42), "gauge":points.court1+Vector2(90,42),
		"heater":points.court1+Vector2(150,42),
		"seal":points.court2+Vector2(-46,-58), "boiler":points.court2+Vector2(56,-28),
		"condenser":points.court3+Vector2(-48,-8), "tank":points.court3+Vector2(22,42),
	})
	var owner_chunk := get_parent()
	_travel = owner_chunk.context_provider
	if not bind(host,owner_chunk,PARTS.definition(points),_completion_ready):
		return false
	_replace_reserves(model)
	var marker := Marker2D.new()
	marker.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(marker)
	_markers.professor = marker
	for id in ["observation","plug","cover","gauge","heater","seal","boiler","condenser","tank","exit"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-70,8)
		if id in ["cover","gauge","heater"]: label.position.y = -42
		label.size.x = 140
		label.add_theme_font_size_override("font_size",9)
		label.add_theme_color_override("font_outline_color",Color("26383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	_return_line = Line2D.new()
	_return_line.points = PackedVector2Array([Vector2.ZERO,points.tank-points.condenser])
	_return_line.z_index = -1
	_return_line.width = 6
	_return_line.antialiased = true
	component("condenser/control").visuals.add_child(_return_line)
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _replace_reserves(model: RefCounted) -> void:
	for placement in model.data.equipment:
		if placement.subregion != REGION or placement.asset not in REPLACED:
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

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not raw.items.is_empty():
		return false
	var observed := phase(raw,"observation") == "gas"
	var cleared := phase(raw,"plug") == "gas"
	var sealed := phase(raw,"cover") == "sealed"
	var low := phase(raw,"gauge") == "low"
	var heated := phase(raw,"heater") == "regulated"
	var boiler := phase(raw,"boiler")
	var condenser := phase(raw,"condenser")
	var returned := phase(raw,"tank") == "full"
	return ((not low or sealed) and (not heated or low) and (not observed or heated)
		and (not cleared or observed) and (phase(raw,"seal") == "covered" or cleared)
		and (boiler == "open" or phase(raw,"seal") == "gas")
		and (boiler == "spent") == (condenser != "empty")
		and returned == (condenser == "drained")
		and raw.get("utility_return",{}) == (UTILITY_RETURN if returned else {})
		and (phase(raw,"exit") == "locked" or returned))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].components["exit/control"].phase = "released"
	var earned := ["C0"]
	if phase(state,"observation") == "gas": earned.append("C1")
	if phase(state,"plug") == "gas": earned.append("C2")
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
	return DEVICE.has_lesson(store.data,DEVICE.MILESTONES[PARTS.MILESTONE])

func introduce(milestone_id: String) -> bool:
	return action_allowed("professor") and super.introduce(milestone_id)

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and world.access.allowed(REGION) and world.player.jump_elapsed < 0
			and world.player.action_elapsed < 0 and not world.player.carrying and _near("professor"))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"seal_chamber": return _lesson_seen()
		"question": return _receipt_matches(PARTS.OBSERVATION)
		"route": return _receipt_matches(PARTS.BOILER)
		"collect": return _verified_route()
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_markers.get("professor")) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Aster","target":_markers.professor,"enabled":true,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	var local := super.world_context()
	if not local.is_empty():
		return local
	return _travel.world_context() if is_instance_valid(_travel) else {}

func sample_for(id: String) -> Dictionary:
	var result := super.sample_for(id)
	if id in [PARTS.OBSERVATION,PARTS.PLUG]:
		var regulated := phase(_state,"heater") == "regulated"
		var low := phase(_state,"gauge") == "low"
		result.merge({"sealed":phase(_state,"cover") == "sealed","instrumented":true,
			"temperature_controlled":regulated,"pressure_regime":"low" if low else "normal","liquid_present":false,
			"phase_region":"solid_gas" if low and regulated else "unqualified",
			"heat_flow":"in" if regulated else "none"},true)
	return result

func _receipt_matches(id: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var record: Variant = records.get(id) if records is Dictionary else null
	var process: String = PARTS.TARGET_PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	return (record is Dictionary and record.get("version") == 1 and record.get("id") == id
		and record.get("process") == process and record.get("material") == "water"
		and record.get("from_state") == rule.from and record.get("to_state") == rule.to)

func _verified_route() -> bool:
	return PARTS.TARGET_PROCESSES.keys().all(_receipt_matches)

func _completion_ready(state: Dictionary) -> bool:
	return state.get("utility_return") == UTILITY_RETURN and _verified_route()

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("sublimation",PARTS.MILESTONE)
		"question": return _show_question()
		"exit": return finish()
	world.input_adapter.stop_all("lab_action",true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var action: Dictionary = contract.actions[id]
	next.components[action.component].phase = action.value
	var successes := []
	match id:
		"route": next.components["condenser/control"].phase = "gas"
		"collect":
			next.components["condenser/control"].phase = "drained"
			next.utility_return = UTILITY_RETURN.duplicate()
			successes.append({"puzzle":"lab_utility_return","type":"boil_condense_cycle",
				"topic":"condensation","object":"lab_utility_tank"})
	if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,[],world):
		return true
	_feedback("Lab setup could not be saved. Try again.")
	return false

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var binding: Dictionary = contract.targets[outcome.id]
	var next := _state.duplicate(true)
	next.components[binding.component].phase = outcome.to_state
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(binding.events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	_feedback("Observation could not be saved. Apply the device again.")
	return false

func _feedback(text: String) -> void:
	world.input_adapter.feedback = text
	world.input_adapter.refresh()

func _show_question(feedback := "") -> bool:
	var actions := []
	for index in QUESTION.choices.size():
		actions.append({"id":str(index),"label":QUESTION.choices[index]})
	return world.input_adapter.open_provider_panel(self,_answer,"guides.library",{
		"title":"Did the chamber ice melt first?","speaker":"professor_z3","body":feedback,
		"rows":[],"search":false,"actions":actions})

func _answer(id: String, _payload: Dictionary) -> void:
	if not active() or not _near("observation") or not id.is_valid_int():
		return
	var answer := CONTENT.answer(REGION,QUESTION,id.to_int())
	if not answer.is_empty():
		_show_question(answer.feedback)

func _art(id: String, sprite_id: String) -> void:
	var sprite: Sprite2D = component(id+"/control").visuals.get_node("Artwork")
	var art := PARTS.art(sprite_id)
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE*float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	_labels.cover.text = "SEALED" if phase(state,"cover") == "sealed" else "OPEN"
	_labels.gauge.text = "LOW PRESSURE" if phase(state,"gauge") == "low" else "NORMAL PRESSURE"
	_labels.heater.text = "HEAT IN" if phase(state,"heater") == "regulated" else "HEAT OFF"
	_labels.observation.text = "GAS 1 · LIQUID 0" if phase(state,"observation") == "gas" else "OBSERVATION ICE"
	_labels.plug.text = "SLOT CLEAR · GAS 1" if phase(state,"plug") == "gas" else "ICE PLUG"
	_labels.seal.text = "DRY SEAL" if phase(state,"seal") == "gas" else "DAMP SEAL"
	_labels.boiler.text = {"open":"GUARD OPEN","liquid":"ADD HEAT","gas":"VAPOR READY","spent":"UTILITY DRIVEN"}[phase(state,"boiler")]
	_labels.condenser.text = {"empty":"CONDENSER","gas":"COOL EXHAUST","liquid":"+8°C · DROPLETS","drained":"DRAINED"}[phase(state,"condenser")]
	_labels.tank.text = "2 LIQUID MEASURES" if phase(state,"tank") == "full" else "TANK EMPTY"
	_return_line.default_color = Color("77b9cf") if phase(state,"tank") == "full" else Color("566a72")
	_labels.exit.text = "LAB ACCESS SEAL"
	var task := "Ask Professor Aster about sublimation"
	if _lesson_seen(): task = "Seal the observation chamber"
	if phase(state,"cover") == "sealed": task = "Set low pressure"
	if phase(state,"gauge") == "low": task = "Enable regulated heat input"
	if phase(state,"heater") == "regulated": task = "Use Vacuum at the observation port"
	if phase(state,"observation") == "gas": task = "Clear the ice plug with Vacuum"
	if phase(state,"plug") == "gas": task = "Spread and dry the damp utility seal"
	if phase(state,"seal") == "gas": task = "Fit the dry seal and close the boiler guard"
	match phase(state,"boiler"):
		"liquid": task = "Boil utility water with Thermal"
		"gas": task = "Drive the utility and route exhaust"
		"spent": task = "Use Cryo at the utility condenser"
	if phase(state,"condenser") == "liquid": task = "Drain the liquid droplets to the supply tank"
	if phase(state,"tank") == "full": task = "Record the lab access seal at the exit"
	var done := phase(state,"exit") == "released"
	chunk.quests = [{"text":"Lab access seal recorded" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func present() -> void:
	super.present()
	if not _state.is_empty():
		_visible_exposure.clear()
		_apparatus(_state)

func _process(_delta: float) -> void:
	if not _can_write() or _labels.is_empty():
		return
	for id in PARTS.TARGET_PROCESSES:
		var target: Node = targets.get(id)
		var part: String = contract.targets[id].component.get_slice("/",0)
		if not EXPOSURE_ART.has(part) or not is_instance_valid(target) or target.is_committed() or target.exposure() <= 0:
			continue
		var fraction: float = target.exposure()/target.definition().required_exposure
		var stage := 1 if fraction >= .55 else 0
		if _visible_exposure.get(part,-1) != stage:
			_visible_exposure[part] = stage
			_art(part,EXPOSURE_ART[part][stage])
			if id in [PARTS.OBSERVATION,PARTS.PLUG]:
				_labels[part].text = "GAS RISING · LIQUID 0"
			elif id == PARTS.SEAL:
				_labels.seal.text = "SURFACE EVAPORATION"

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
	for marker in _markers.values():
		if is_instance_valid(marker): marker.queue_free()
	super._exit_tree()
