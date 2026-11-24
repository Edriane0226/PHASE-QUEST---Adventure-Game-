extends Node2D
## Local practice uses live controls. Only prepared samples and matched placements enter its save record.
const LAYOUT = preload("res://Scripts/World/Learning/optional_activity_layout.gd")
const ASSEMBLY = preload("res://Scripts/World/Learning/puzzle_assembly.gd")
const TARGET = preload("res://Scripts/World/phase_device_target_2d.gd")
const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
const SAVE_KEY := "optional_world_activities"
const REACH := 42.0
const PAD_RADIUS := 130.0
const ACTIVITY_ID := "optional"

var world: Node2D
var chunk: Node2D
var store: Node
var assembly: ASSEMBLY
var sign: Marker2D
var heading: Label
var labels := {}
var targets := {}
var center: Vector2
var region: String
var station_id: String
var kind: String
var activity: Dictionary
var shapes: Array
var last_error := ""
var _attempt := ""
var _held := ""
var _carry_visual: Sprite2D
var _dry_time := -1.0
var _wrong_slot := ""
var _state := {}
var _control_available := false
var _feedback := ""

func bind(host: Node2D, owner: Node2D) -> bool:
	world = host
	chunk = owner
	store = world.get_node("/root/PlayerSave")
	region = chunk.subregion_id
	station_id = region + "." + ACTIVITY_ID
	kind = LAYOUT.DISPLAYS[region]
	activity = LAYOUT.ACTIVITIES[kind]
	shapes = activity.shapes
	var reservation: Marker2D = chunk.anchors.get(station_id)
	if reservation == null or reservation.get_meta("kind","") != "optional minigame":
		last_error = "Missing reserved minigame pad."
		return false
	var pad := reservation.global_position
	center = pad + LAYOUT.FROST_SIGN if kind == "frost" else pad
	var catalog: Dictionary = world.catalogs[int(region.substr(1,1))-1]
	assembly = ASSEMBLY.new()
	add_child(assembly)
	if not assembly.configure(LAYOUT.definition(station_id,pad,catalog,kind),world,chunk):
		last_error = "Invalid modular assembly. " + assembly.error
		return false
	for prop in world.props:
		if prop.get_meta("station_id","") == station_id: prop.hide()
	for record in world.geometry.region_models[region].blockers:
		if record.get("station","") != station_id: continue
		record.layer = 0
		if is_instance_valid(record.get("body")): record.body.collision_layer = 0
	var grounded = preload("res://Scripts/World/Runtime/grounded_visual.gd").new()
	grounded.position = center
	grounded.elevation = float(world.raised_surface(center).height)
	world.district_art_parent(chunk).add_child(grounded)
	grounded.set_meta("optional_station_id",station_id)
	heading = _label(grounded.visuals,Vector2(-75,-8),150,11)
	sign = Marker2D.new()
	sign.position = center-chunk.ground_origin-Vector2(0,grounded.elevation)
	chunk.add_child(sign)
	for shape: String in shapes:
		for prefix in ["source_","slot_"]:
			var id: String = prefix+shape
			labels[id] = _label(assembly.marker(id).visuals,Vector2(-66,8),132,9)
	if assembly.parts.has("control"):
		labels.control = _label(assembly.marker("control").visuals,Vector2(-86,-42),172,10)
	store.changed.connect(_refresh)
	store.restored.connect(_restore)
	_refresh()
	if _state.is_empty(): _present()
	return true

func _label(parent: Node2D, at: Vector2, width: float, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	label.size.x = width
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_outline_color",Color("243b40"))
	label.add_theme_constant_override("outline_size",4)
	parent.add_child(label)
	return label

func _read_state() -> Dictionary:
	var ledger: Variant = store.data.extras.get(SAVE_KEY,{"version":1,"stations":{}})
	if not ledger is Dictionary or ledger.get("version") != 1 or not ledger.get("stations") is Dictionary:
		return {}
	var raw: Variant = ledger.stations.get(station_id,{"prepared":{},"placed":{}})
	if not raw is Dictionary or not raw.get("prepared") is Dictionary or not raw.get("placed") is Dictionary:
		return {}
	for shape in raw.prepared:
		if shape not in shapes or raw.prepared[shape] != true: return {}
	for shape in raw.placed:
		if shape not in shapes or raw.placed[shape] != true or (kind != "paths" and not raw.prepared.has(shape)): return {}
	return raw.duplicate(true)

func _learned() -> bool:
	var run: Dictionary = store.data.active_run
	var receipts: Variant = run.get("state",{}).get("device_outcomes",{})
	var process: String = activity.get("process", "")
	if not process.is_empty() and not store.device_state().learned_capabilities.has(RULES.PROCESSES[process].capability):
		return false
	if kind == "dry":
		return store.data.extras.get("solved_puzzle_ids",{}).get("vaporization_and_condensation:2:orchard_belt_drying") == "evaporate_drying"
	return receipts is Dictionary and LAYOUT.OUTCOMES[region].all(func(id): return receipts.has(id))

func active() -> bool:
	return (is_inside_tree() and not is_queued_for_deletion() and not chunk.is_queued_for_deletion()
		and world.active_chunk() == chunk and not world.demonstration_mode and store.session_active and not store.read_only
		and store.campaign_source(world,world.SAVE_ZONE,world.SAVE_LEVEL))

func _in_pad() -> bool:
	return active() and world.player.position.distance_to(center) <= PAD_RADIUS

func owns_target(target: Node) -> bool:
	return _control_available and _in_pad() and target in targets.values()

func holding_item() -> bool:
	return is_instance_valid(_carry_visual)

func _ready_item(shape: String) -> bool:
	return not _state.is_empty() and (kind == "paths" or _state.prepared.has(shape)) and not _state.placed.has(shape)

func _refresh() -> void:
	var next := _read_state()
	var available := active() and not next.is_empty() and _learned()
	if _state != next or available != _control_available:
		_state = next
		_control_available = available
		_present()

func _restore() -> void:
	leave()
	_refresh()

func _present() -> void:
	if not is_instance_valid(heading) or assembly.parts.is_empty(): return
	var placed: Dictionary = _state.get("placed",{})
	heading.text = "Optional · %d/%d" % [placed.size(),shapes.size()]
	var states := {}
	for shape: String in shapes:
		var ready := _ready_item(shape)
		var done := placed.has(shape)
		var moved := _held == shape or done
		var id := "source_"+shape
		var part: Node2D = assembly.marker(id)
		var images := LAYOUT.art(kind,shape)
		var phase := "ready" if ready else ("working" if _dry_time >= 0 else "pending")
		if moved and images.has("vacant"): phase = "vacant"
		if done and images.has("returned"): phase = "returned"
		part.visible = not moved or images.has("vacant") or (done and images.has("returned"))
		if kind == "dew" and _held == shape: part.hide()
		if kind == "paths" and not _control_available and not done: phase = "pending"
		states[station_id+"/"+id] = {"phase":phase}
		var caption := _name_for(shape)
		if kind == "ice" and not moved: caption += " · ice" if ready else " · water"
		if kind == "frost" and not moved: caption += " · frost" if ready else " · vapor"
		if kind == "paths": caption = "Liquid detected" if shape == "melting" else "Gas · 0 liquid"
		labels[id].text = caption if part.visible else ""
		if kind == "paths" and not _control_available: labels[id].text = "Awaiting observation"
		if phase == "returned": labels[id].text += " · empty"
		labels["slot_"+shape].text = _name_for(shape)
		states[station_id+"/slot_"+shape] = {"phase":"placed" if done else ("wrong" if _wrong_slot == shape else "empty")}
	if kind == "dry":
		var air := _dry_time >= 0
		states[station_id+"/control"] = {"phase":"running" if air else "idle"}
		labels.control.text = "Airflow · surface drying" if air else "Sunny rack · fan"
	if kind == "dew":
		var collected: bool = not _state.get("prepared",{}).is_empty()
		states[station_id+"/control"] = {"phase":"ready" if collected else "idle"}
		labels.control.text = "+8°C · liquid collected" if collected else "Dew collector · Cryo"
	assembly.present(states,{})

func _name_for(shape: String) -> String:
	if shape == "melting": return "Solid → liquid"
	if shape == "sublimation": return "Solid → gas"
	return shape.capitalize()

func _target_components() -> Array:
	if kind == "dew": return ["control"]
	return shapes.map(func(shape): return "source_"+shape) if activity.has("process") else []

func _bind_targets(attempt: String) -> void:
	_attempt = attempt
	var process: String = activity.get("process", "")
	for id: String in _target_components():
		if _state.prepared.has(_sample_shape(id)): continue
		var target := TARGET.new()
		target.name = (station_id+"_"+id).validate_node_name()
		var body: StaticBody2D = assembly.bodies[id]
		body.add_child(target)
		target.global_position = assembly.interaction_markers[id].global_position
		target.set_meta("ground_xy",assembly.marker(id).position)
		target.hit_collider = body
		targets[id] = target
		var spec := {"id":station_id+"_"+id,"zone":world.SAVE_ZONE,"level":world.SAVE_LEVEL,
			"material":"water","process":process,"allowed_modes":[activity.mode],
			"required_exposure":1.25,"max_range":105.0,"required_flags":[]}
		if target.configure(spec,world,store):
			target.bind_live_context(_sample.bind(id),func(): return {})
			target.outcome_ready.connect(_target_ready.bind(id))
		else:
			targets.erase(id)
			target.queue_free()

func _sample(id: String) -> Dictionary:
	var rule: Dictionary = RULES.PROCESSES[activity.process]
	var done: bool = _state.prepared.has(_sample_shape(id))
	return {"state":rule.to if done else rule.from,"amount":0 if done else (shapes.size() if kind == "dew" else 1),
		"material":"water","phase_region":rule.region,"heat_flow":rule.heat,
		"sealed":kind == "frost","instrumented":kind == "frost","temperature_controlled":kind == "frost",
		"pressure_regime":"high" if kind == "frost" else "normal","liquid_present":kind == "ice"}

func _sample_shape(id: String) -> String:
	return shapes[0] if kind == "dew" else id.trim_prefix("source_")

func _target_ready(_outcome: Dictionary, id: String) -> void:
	var target: Node = targets[id]
	if not _control_available or not _in_pad() or not world.player_controls_allowed() or target.verified_outcome(store,world).is_empty():
		return
	var batch: Array = shapes if kind == "dew" else [_sample_shape(id)]
	if _prepare(batch):
		target.acknowledge_commit(store,world)
		target.remove_from_group(TARGET.TARGET_GROUP)
		_show_feedback({"ice":"Water lost heat and froze. Lift the solid sample.",
			"dew":"Liquid droplets collected at +8°C. The marked cups are full.",
			"frost":"Solid frost collected directly from vapor. Liquid 0."}[kind])
	else:
		target.reset_after_restore(world,store)

func _prepare(batch: Array) -> bool:
	var next := _state.duplicate(true)
	for shape in batch: next.prepared[shape] = true
	return _save(next)

func _save(next: Dictionary) -> bool:
	var previous: Variant = store.data.extras.get(SAVE_KEY)
	var ledger: Dictionary = store.data.extras.get(SAVE_KEY,{"version":1,"stations":{}}).duplicate(true)
	ledger.stations[station_id] = next
	store.data.extras[SAVE_KEY] = ledger
	if store.save_profile(): return true
	if previous == null: store.data.extras.erase(SAVE_KEY)
	else: store.data.extras[SAVE_KEY] = previous
	_show_feedback(store.last_error)
	return false

func _show_feedback(message: String) -> void:
	_feedback = message
	world.input_adapter.feedback = message

func _near(id: String) -> bool:
	var at: Vector2 = center if id == "sign" else assembly.marker(id).position
	var from: Vector2 = world.player.position
	if from.distance_to(at) > REACH or not world.world_contact_allowed(from,at): return false
	if absf(float(world.raised_surface(from).get("height",INF))-float(world.raised_surface(at).height)) > 20.5: return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if assembly.bodies.has(id): exclude.append(assembly.bodies[id].get_rid())
	var ray := PhysicsRayQueryParameters2D.create(from,at,11,exclude)
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _controls_allowed() -> bool:
	return (_in_pad() and world.player_controls_allowed() and world.player.jump_elapsed < 0
		and world.player.action_elapsed < 0 and (not world.player.carrying or holding_item()))

func _action_allowed(id: String) -> bool:
	if not _controls_allowed() or not _near(id): return false
	if id == "sign": return true
	if not _control_available: return false
	if id == "control": return kind == "dry" and _held.is_empty() and _dry_time < 0 and _state.prepared.is_empty()
	if id.begins_with("source_"):
		var shape := id.trim_prefix("source_")
		return _held == shape or (_held.is_empty() and _ready_item(shape))
	return id.begins_with("slot_") and not _held.is_empty()

func world_context() -> Dictionary:
	if not _controls_allowed(): return {}
	var best := INF
	var chosen := ""
	var points := assembly.interaction_markers.duplicate()
	points.sign = sign
	for id in points:
		if not _action_allowed(id): continue
		var at: Vector2 = center if id == "sign" else assembly.marker(id).position
		var distance: float = world.player.position.distance_squared_to(at)
		if distance < best:
			best = distance
			chosen = id
	if chosen.is_empty(): return {}
	var title: String = activity.title
	if chosen == "sign" and holding_item(): title = "Return " + _held
	elif chosen == "control": title = "Start airflow at sunny rack"
	elif chosen.begins_with("source_"):
		var shape := chosen.trim_prefix("source_")
		title = ("Return " if holding_item() else "Lift ") + shape + " " + activity.item
	elif chosen.begins_with("slot_"):
		var shape := chosen.trim_prefix("slot_")
		title = ("Water " if kind == "dew" else "Place at ") + _name_for(shape).to_lower()
	return {"key":station_id+":"+chosen,"caption":title,"target":points[chosen],"enabled":true,
		"allowed":_action_allowed.bind(chosen),"invoke":_interact.bind(chosen)}

func _interact(id: String) -> bool:
	if not _action_allowed(id): return false
	world.input_adapter.stop_all("optional_activity",true)
	if id == "sign":
		if holding_item():
			_return_item()
			return true
		var next := "Walk away whenever you like. Matched placements stay saved."
		if not _control_available: next = "Practice opens after the local experiment is verified. You can continue along the main route."
		return world.input_adapter.open_optional_activity(activity.title,activity.objective,activity.cue+"\n\n"+next)
	if id == "control":
		_dry_time = 0.0
		_present()
		return true
	if id.begins_with("source_"):
		if holding_item(): _return_item()
		else: _lift(id.trim_prefix("source_"))
		return true
	var slot := id.trim_prefix("slot_")
	if slot != _held:
		_wrong_slot = slot if not _state.placed.has(slot) else ""
		_show_feedback("Match %s at its own marked display." % _name_for(_held).to_lower())
		_present()
		return true
	var next := _state.duplicate(true)
	next.placed[slot] = true
	if not _save(next): return false
	_return_item()
	var matched := "Practice complete!" if next.placed.size() == shapes.size() else "Matched."
	if kind == "dew": matched += " Planter watered. Cup is empty."
	_show_feedback(matched)
	return true

func _lift(shape: String) -> void:
	_held = shape
	var entry: Dictionary = world.catalogs[int(region.substr(1,1))-1][LAYOUT.art(kind,shape).held]
	_carry_visual = Sprite2D.new()
	_carry_visual.name = "OptionalPracticeItem"
	_carry_visual.set_meta("unique_item_id",station_id+":"+shape)
	_carry_visual.texture = load(entry.path)
	_carry_visual.scale = Vector2.ONE * float(entry.world_scale)
	world.player.get_node("CarriedModule").add_child(_carry_visual)
	world.player._fit_carried_objects()
	world.player.carrying = true
	_present()

func _return_item() -> void:
	_held = ""
	_wrong_slot = ""
	if holding_item() and is_instance_valid(world.player):
		world.player._grip_offsets.erase(_carry_visual.get_instance_id())
		_carry_visual.get_parent().remove_child(_carry_visual)
		_carry_visual.queue_free()
		_carry_visual = null
		world.player.carrying = false
	_present()

func leave() -> void:
	var was_drying := _dry_time >= 0
	_dry_time = -1.0
	if holding_item() or was_drying or not _wrong_slot.is_empty(): _return_item()
	if is_instance_valid(world.input_adapter) and not _feedback.is_empty() and world.input_adapter.feedback == _feedback:
		world.input_adapter.feedback = ""
	_feedback = ""
	for target in targets.values():
		if is_instance_valid(target):
			target.remove_from_group(TARGET.TARGET_GROUP)
			target.queue_free()
	targets.clear()
	_attempt = ""

func _physics_process(delta: float) -> void:
	if not _in_pad():
		if not _attempt.is_empty() or holding_item() or _dry_time >= 0: leave()
		return
	if not _control_available:
		_refresh()
		if not _control_available: return
	var current: String = store.data.active_run.get("attempt_id", "")
	if _attempt != current:
		leave()
		_bind_targets(current)
	if _dry_time >= 0:
		_dry_time += delta
		if _dry_time >= 2.0:
			_dry_time = -1.0
			if _prepare(shapes): _show_feedback("Surface water evaporated. Lift the dry pennants.")
			_present()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(assembly): leave()

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player): leave()
	if is_instance_valid(sign): sign.queue_free()
	if is_instance_valid(heading): heading.get_parent().get_parent().queue_free()
