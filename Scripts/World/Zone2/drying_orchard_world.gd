extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Applied vaporization at three authored outdoor courts.
const PARTS = preload("res://Scripts/World/Zone2/orchard_assembly.gd")
const SERVICE_STEPS = preload("res://Scripts/World/Zone2/orchard_service_steps.gd")
const REGION := "Z2L2"
const CHECKPOINTS := ["C0","C1","C2"]
const RESERVES := {"drying_rack":"rack","drive_belt":"socket","orchard_fan":"fan","solar_shutter":"shutter",
	"boiler":"boiler","model_turbine":"turbine","harvest_gate":"gate","tool_choice":"cloth"}
const DRY_SECONDS := 2.0
var points := {}
var _footprints := {}
var _reserved_art: Array[Node2D] = []
var _elapsed := 0.0
var _help: Marker2D
var _service_steps: SERVICE_STEPS
var _labels := {}
var _frame := -1

func bind_orchard(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	for placement in model.data.equipment:
		if placement.subregion == REGION and placement.station != REGION + ".optional" and RESERVES.has(placement.group):
			points[RESERVES[placement.group]] = model.v(placement.at)
	points.merge({"belt":points.rack + Vector2(5,45), "fill":points.boiler + Vector2(-72,55),
		"cover":points.boiler + Vector2(72,55), "valve":points.turbine + Vector2(68,8),
		"wheel":points.cloth + Vector2(-95,75)})
	points.curb = points.rack + Vector2(-62,67)
	points.plinth = points.cloth
	if not bind(host,get_parent(),PARTS.definition(points),_completion_ready):
		return false
	for record in model.blockers:
		if record.get("station","") not in [REGION+".court1", REGION+".court2", REGION+".court3"]:
			continue
		for id in RESERVES.values():
			if record.bounds.get_center().distance_to(points[id]) < 1.0:
				_footprints[id] = record
	for prop in world.props:
		if prop.get_meta("station_id","") in [REGION+".court1", REGION+".court2", REGION+".court3"] and prop.get_meta("asset_id","") in ["drying_rack_empty","drive_belt_wet","orchard_fan_off","solar_shutter_closed","boiler_empty","model_turbine_idle","harvest_gate_closed","tool_choice_evaporation"]:
			_reserved_art.append(prop)
			prop.hide()
	_footprints.boiler.body.collision_layer = 0
	_footprints.cloth.layer = 0
	_footprints.cloth.body.collision_layer = 0
	_service_steps = SERVICE_STEPS.new()
	add_child(_service_steps)
	_service_steps.install(world,chunk,points.curb,points.plinth)
	component("cloth/control").elevation += 20
	assemblies.cloth.interaction_markers.control.position.y -= 20
	_help = Marker2D.new()
	_help.position = points.professor - chunk.ground_origin - Vector2(0, world.raised_surface(points.professor).height)
	chunk.add_child(_help)
	for id in ["rack","boiler","socket","cloth","wheel"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-76,5)
		label.size.x = 152
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_outline_color",Color("263e40"))
		label.add_theme_constant_override("outline_size",4)
		component(id + "/control").visuals.add_child(label)
		_labels[id] = label
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func phase(state: Dictionary, id: String) -> String:
	return state.components[id + "/control"].phase

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or raw.items.size() != 1:
		return false
	var belt: String = raw.items[PARTS.BELT]
	return (belt in [PARTS.SOURCE,"player",PARTS.INSTALLED]
		and (phase(raw,"rack") not in ["drying","dry"] or (phase(raw,"fan") == "airflow" and phase(raw,"shutter") == "open"))
		and (belt == PARTS.SOURCE or phase(raw,"rack") == "dry")
		and (phase(raw,"fill") == "empty" or belt == PARTS.INSTALLED)
		and ((phase(raw,"fill") == "empty") == (phase(raw,"boiler") == "empty"))
		and (phase(raw,"cover") == "open" or phase(raw,"fill") == "filled")
		and (phase(raw,"boiler") != "gas" or phase(raw,"cover") == "guarded")
		and (phase(raw,"valve") == "closed" or phase(raw,"boiler") == "gas")
		and (phase(raw,"cloth") == "wet" or phase(raw,"valve") == "routed")
		and (phase(raw,"wheel") == "idle" or phase(raw,"cloth") == "dry"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	var earned := ["C0"]
	if state.items[PARTS.BELT] == PARTS.INSTALLED:
		earned.append("C1")
	if phase(state,"valve") == "routed":
		earned.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,earned)
	result.checkpoint = earned.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _near(id: String) -> bool:
	var at: Vector2 = points[id]
	var from: Vector2 = world.player.position
	if from.distance_to(at) > 44 or not world.world_contact_allowed(from,at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if _footprints.has(id):
		exclude.append(_footprints[id].body.get_rid())
	if id == "cloth" and world.raised_surface(from).get("body_path") == "OrchardPlinth":
		exclude.append(world.source_bodies[REGION+":OrchardPlinth"].get_rid())
	var ray := PhysicsRayQueryParameters2D.create(from,at,11,exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func action_allowed(id: String) -> bool:
	if id == "professor":
		return _can_write() and not world.player.carrying and world.player.jump_elapsed < 0 and world.player.action_elapsed < 0 and _near(id)
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"inspect": return _elapsed >= DRY_SECONDS
		"fill": return _state.items[PARTS.BELT] == PARTS.INSTALLED
		"cloth": return world.raised_surface(world.player.position).get("body_path") == "OrchardPlinth"
		"exit": return not world.access.completed(REGION)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_help) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Reed","enabled":true,"target":_help,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("vaporization")
		"exit": return finish()
		"cloth","wheel": return _tool_panel(id)
		"fill":
			world.input_adapter.stop_all("context_action",true)
			if not action_allowed(id):
				return false
			var next := _state.duplicate(true)
			next.components["fill/control"].phase = "filled"
			next.components["boiler/control"].phase = "liquid"
			return _write(next)
		"inspect":
			world.input_adapter.stop_all("context_action",true)
			if not action_allowed(id):
				return false
			var next := _state.duplicate(true)
			next.components["rack/control"].phase = "dry"
			var success := {"puzzle":"orchard_belt_drying","type":"evaporate_drying","topic":"vaporization","object":"orchard_rack"}
			return _write(next,[success],_events([{"id":"surface_escape","members":[]},{"id":"six_changes","members":["evaporation"]}],id))
	return super.commit_action(id)

func _write(next: Dictionary, successes: Array = [], events: Array = []) -> bool:
	if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,events,world):
		return true
	world.input_adapter.feedback = "Could not save this setup. Try again."
	return false

func _tool_panel(id: String) -> bool:
	var cloth := id == "cloth"
	var wrong := phase(_state,id) == "wrong"
	var body := "Dry the wet cloth on the rack." if cloth else "Drive the service wheel from the guarded vapor line."
	if wrong:
		body = "The boiler leaves the cloth wet. Water can escape from the cloth’s surface below boiling." if cloth else "The drying rack releases moisture into open air. The wheel needs directed vapor from boiling water."
	var choices := [{"id":"reset","label":"Reset setup · free"}] if wrong else [
		{"id":"evaporation","label":"Sunlit rack · evaporation"},{"id":"boiling","label":"Guarded boiler · boiling"}]
	choices.append({"id":"leave","label":"Leave"})
	return world.input_adapter.open_provider_panel(self,_tool_intent.bind(id,_attempt),"guides.library",
		{"title":"Wet cloth" if cloth else "Powered wheel","body":body,"rows":[],"search":false,"actions":choices})

func _tool_intent(choice: String, _payload: Variant, id: String, attempt: String) -> void:
	world.input_adapter.close_panel()
	if choice == "leave" or attempt != _attempt or not action_allowed(id):
		return
	var next := _state.duplicate(true)
	var cloth := id == "cloth"
	var successes := []
	var events := []
	if phase(_state,id) == "wrong":
		if choice != "reset":
			return
		next.components[id+"/control"].phase = "wet" if cloth else "idle"
	elif choice in ["evaporation","boiling"]:
		var correct := choice == ("evaporation" if cloth else "boiling")
		next.components[id+"/control"].phase = ("dry" if cloth else "turning") if correct else "wrong"
		if correct:
			# Both apparatus results precede this application test. The selection
			# adds neither native phase evidence nor a phase badge.
			successes.append({"puzzle":"orchard_tool_"+id,"type":"evaporate_drying" if cloth else "boil_volume",
				"topic":"vaporization","object":"orchard_"+id})
			if next.get("wrong_tool_tests",{}).get(id,false):
				events = _events([{"id":"try_another_way","members":[]}],"orchard_tool_"+id)
		else:
			var wrong: Dictionary = next.get("wrong_tool_tests",{})
			wrong[id] = true
			next.wrong_tool_tests = wrong
	else:
		return
	if not _write(next,successes,events): return
	if phase(next,id) == "wrong":
		_tool_panel(id)
	elif phase(next,id) in ["dry","turning"]:
		world.input_adapter.feedback = "Surface evaporation dried the cloth." if cloth else "Directed vapor from boiling powered the wheel."
		world.input_adapter.refresh()

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	sample.amount = 1 if phase(_state,"fill") == "filled" else 0
	return sample

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var next := _state.duplicate(true)
	next.components["boiler/control"].phase = outcome.to_state
	if store.commit_device_outcome(target,snapshot(next),world,[],_events(contract.targets[outcome.id].events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	world.input_adapter.feedback = "Boiling observation could not be saved. Heat the chamber again."
	return false

func _completion_ready(state: Dictionary) -> bool:
	return (state.items[PARTS.BELT] == PARTS.INSTALLED and phase(state,"valve") == "routed"
		and phase(state,"cloth") == "dry" and phase(state,"wheel") == "turning")

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func _art(id: String, asset: String) -> void:
	var sprite: Sprite2D = component(id+"/control").visuals.get_node("Artwork")
	var art := PARTS.KIT.art(asset)
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE * float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1]) * sprite.scale

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var owner: String = state.items[PARTS.BELT]
	var routed := phase(state,"valve") == "routed"
	var rack := phase(state,"rack")
	# The dry rack already depicts the belt. The pickup marker owns the
	# carried sprite, while only the rack or socket depicts a grounded belt.
	component("belt/control").visible = false
	if owner != PARTS.SOURCE:
		_art("rack","drying_rack_cleared")
	_art("socket","drive_belt_fitted" if owner == PARTS.INSTALLED else "engine_socket_drive_belt_empty")
	_labels.socket.text = "BELT FITTED" if owner == PARTS.INSTALLED else "DRIVE SOCKET"
	_labels.rack.text = {"folded":"FOLDED · WET","wet":"SPREAD · WET","drying":"SURFACE DRYING","dry":"DRY BELT"}[rack] if owner == PARTS.SOURCE else "RACK EMPTY"
	var gas := phase(state,"boiler") == "gas"
	var guarded := phase(state,"cover") == "guarded"
	var filled := phase(state,"fill") == "filled"
	_art("boiler","boiler_boil_a" if gas else ("boiler_covered" if guarded else ("boiler_filled" if filled else "boiler_empty")))
	_labels.boiler.text = "BULK BOILING" if gas else ("GUARDED · VENT OPEN" if guarded else ("WATER SUPPLIED" if filled else "EMPTY"))
	_art("gate","harvest_gate_open" if routed else "harvest_gate_closed")
	_footprints.gate.layer = 0 if routed else _footprints.gate.original_layer
	_footprints.gate.body.collision_layer = _footprints.gate.layer
	_service_steps.set_plinth_access(routed)
	_art("turbine","model_turbine_turn_a" if routed else "model_turbine_idle")
	_labels.cloth.text = {"wet":"WET CLOTH","wrong":"WET · RESET","dry":"DRY CLOTH"}[phase(state,"cloth")]
	_labels.wheel.text = {"idle":"SERVICE WHEEL","wrong":"STILL · RESET","turning":"WHEEL POWERED"}[phase(state,"wheel")]
	if world.access.completed(REGION):
		_art("exit","float_latch_latched")
	_frame = -1

func present() -> void:
	super.present()
	_apparatus(_state)
	var fitted: bool = _state.items[PARTS.BELT] == PARTS.INSTALLED
	var routed := phase(_state,"valve") == "routed"
	var belt_task: String = {"folded":"Spread the wet belt","wet":"Open shutter, start fan, then dry belt",
		"drying":"Watch surface drying, then check belt","dry":"Lift dry belt and fit it to drive socket"}[phase(_state,"rack")]
	var boiler_task := "Supply boiler water"
	if phase(_state,"fill") == "filled": boiler_task = "Close the inspection cover"
	if phase(_state,"cover") == "guarded": boiler_task = "Aim Thermal at guarded boiler"
	if phase(_state,"boiler") == "gas": boiler_task = "Route vapor to the turbine"
	var tool_task := "Dry the cloth on the service plinth"
	if phase(_state,"cloth") == "dry": tool_task = "Choose a process to power the wheel"
	if _completion_ready(_state): tool_task = "Release the orchard exit latch"
	var complete: bool = world.access.completed(REGION)
	chunk.quests = [{"text":"Fit dry belt" if fitted else belt_task,"state":"done" if fitted else "active"},
		{"text":"Drive harvest turbine" if routed else boiler_task,"state":"done" if routed else ("active" if fitted else "blocked")},
		{"text":"Orchard exit open" if complete else tool_task,"state":"done" if complete else ("active" if routed else "blocked")}]
	if routed:
		chunk.quests.push_front(chunk.quests.pop_back())
	# Keep the camera center clear so surface moisture and bubbles stay visible.
	chunk.tutorial = ""

func _process(delta: float) -> void:
	if not _can_write():
		return
	if phase(_state,"rack") == "drying":
		_elapsed = minf(DRY_SECONDS,_elapsed + delta)
	else:
		_elapsed = 0
	var boiler: Node = targets.get(PARTS.TARGET_ID)
	var exposure: float = boiler.exposure() if is_instance_valid(boiler) and not boiler.is_committed() else 0.0
	var frame := int(Time.get_ticks_msec()/250) % 2
	var heating := 2 if exposure >= 2.5 else (1 if exposure > 0 else 0)
	var key := frame + heating * 2
	if key == _frame or _labels.is_empty():
		return
	if _frame >= 2 and heating == 0:
		_apparatus(_state)
	_frame = key
	var suffix := "a" if frame == 0 else "b"
	if phase(_state,"fan") == "airflow": _art("fan","orchard_fan_air_"+suffix)
	if heating == 1:
		_art("boiler","boiler_warm")
		_labels.boiler.text = "HEATING WATER"
	elif heating == 2 or phase(_state,"boiler") == "gas":
		_art("boiler","boiler_boil_"+suffix)
		_labels.boiler.text = "BUBBLES THROUGHOUT"
	if phase(_state,"valve") == "routed": _art("turbine","model_turbine_turn_"+suffix)
	if phase(_state,"wheel") == "turning": _art("wheel","model_turbine_turn_"+suffix)

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

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_checkpoints() -> Array:
	var result := []
	for id in CHECKPOINTS:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor(REGION,id),"attuned":_travel_allowed(id),"allowed":_travel_allowed.bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION,world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	for id in ["gate","boiler","cloth"]:
		if _footprints.has(id):
			var record: Dictionary = _footprints[id]
			record.layer = record.original_layer
			if is_instance_valid(record.body):
				record.body.collision_layer = record.layer
	for art in _reserved_art:
		if is_instance_valid(art):
			art.show()
	if is_instance_valid(_help): _help.queue_free()
	super._exit_tree()
