extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Sunlit Landing extends earned Thermal with two native observations.
const PARTS = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const CROSSING = preload("res://Scripts/World/Zone1/canal_crossings.gd")
const REGION := "Z2L1"
const CHECKPOINTS := ["C0", "C1", "C2"]
const INSTALLED := "installed:landing/control"
const COURTS := ["Z2L1.court1", "Z2L1.court2", "Z2L1.court3"]
const SAVE_RETRY := "Observation could not be saved. Try again."
const RESERVATIONS := {
	"solar_canopy":"canopy", "solar_shutter":"shutter", "solar_reflector":"reflector", "solar_tray":"tray",
	"float_latch":"float", "boiler":"boiler", "model_turbine":"turbine", "equipment_crate":"crate",
}
var points: Dictionary = {}
var crossing: Node
var travel: Node
var _markers: Dictionary = {}
var _labels: Dictionary = {}
var _reservation_art: Array[Node2D] = []
var _reservation_footprints: Array[Dictionary] = []
var _cue_frame := -1

func bind_sunlit(host: Node2D) -> bool:
	var owner: Node = get_parent()
	travel = owner.context_provider
	var model: RefCounted = host.models[1]
	for station in model.data.stations:
		if station.subregion == REGION:
			points[station.id.get_slice(".", 1)] = model.v(station.ground_xy)
	for placement in model.data.equipment:
		if placement.subregion == REGION and RESERVATIONS.has(placement.group):
			points[RESERVATIONS[placement.group]] = model.v(placement.at)
	var span: Vector2 = points.court3 + Vector2(0,70)
	points.merge({"span":span, "support":span + Vector2(-82,-32),
		"plank":span + Vector2(87,0), "landing":span + Vector2(-89,25)})
	if not bind(host, owner, PARTS.definition(points), _completion_ready):
		return false
	for record in model.blockers:
		if record.get("station") in COURTS:
			_reservation_footprints.append(record)
			record.layer = 0
			if is_instance_valid(record.get("body")):
				record.body.collision_layer = 0
	crossing = CROSSING.new()
	add_child(crossing)
	if not crossing.install(host, owner, {}, {"repair":span}):
		chunk.runtime_provider = null
		chunk.context_provider = travel
		return _reject("Landing repair requires level supported banks.")
	chunk.checkpoint_provider = self
	for id in ["professor", "exit"]:
		var at: Vector2 = points[id]
		var marker := Marker2D.new()
		marker.position = at - chunk.ground_origin - Vector2(0, world.raised_surface(at).height)
		chunk.add_child(marker)
		_markers[id] = marker
	for prop in world.props:
		if prop.get_meta("station_id", "") in COURTS:
			_reservation_art.append(prop)
			prop.hide()
	for id in ["reflector", "tray", "float", "boiler", "turbine", "crate", "support", "landing"]:
		var label := Label.new()
		label.position = Vector2(-79,6)
		label.size.x = 158
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_outline_color", Color("223c43"))
		label.add_theme_constant_override("outline_size", 4)
		component(id + "/control").visuals.add_child(label)
		_labels[id] = label
	sync_world_permissions()
	return true

func _phase(state: Dictionary, id: String) -> String:
	return state.components[id + "/control"].phase

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or raw.items.size() != 1:
		return false
	var tray := _phase(raw, "tray")
	var boiler := _phase(raw, "boiler")
	var support := _phase(raw, "support")
	var plank: String = raw.items[PARTS.PLANK]
	return (
		(_phase(raw, "shutter") == "closed" or _phase(raw, "canopy") == "open")
		and (_phase(raw, "reflector") == "0" or _phase(raw, "shutter") == "open")
		and (tray != "gas" or _phase(raw, "reflector") == "3")
		and (_phase(raw, "float") == "covered" or tray == "gas")
		and (boiler == "empty" or _phase(raw, "float") == "latched")
		and (_phase(raw, "turbine") == "idle" or boiler == "gas")
		and (_phase(raw, "crate") == "solid" or _phase(raw, "turbine") == "latched")
		and (support == "empty" or _phase(raw, "crate") == "liquid")
		and plank in [contract.items[PARTS.PLANK].initial_owner, "player", INSTALLED]
		and (plank == contract.items[PARTS.PLANK].initial_owner or support == "latched")
	)

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	var earned := ["C0"]
	if _phase(state, "tray") == "gas":
		earned.append("C1")
	if _phase(state, "boiler") == "gas":
		earned.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({}, CHECKPOINTS, earned)
	result.checkpoint = earned.back()
	result.position = REGISTRY.ground_to_local(REGION, world.player.safe_save_position())
	return result

func _near(at: Vector2, own_body: StaticBody2D = null) -> bool:
	var ground: Vector2 = world.player.position
	if ground.distance_to(at) > 39 or not world.world_contact_allowed(ground, at):
		return false
	var exclusions: Array[RID] = [world.player.get_rid()]
	if is_instance_valid(own_body):
		exclusions.append(own_body.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(ground, at, 1 | 2 | 8, exclusions)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func action_allowed(id: String) -> bool:
	if id in _markers:
		return (_can_write() and not world.player.carrying and world.player.jump_elapsed < 0 and world.player.action_elapsed < 0
			and _near(points[id]) and (id == "professor" or _completion_ready(_state)))
	if not super.action_allowed(id):
		return false
	var assembly: Node = assemblies[contract.actions[id].component.get_slice("/",0)]
	return _near(assembly.marker("control").position, assembly.bodies.get("control"))

func world_context() -> Dictionary:
	if active() and not _state.is_empty():
		for id in _markers:
			if action_allowed(id):
				return {"key":REGION + ":" + id, "caption":"Ask Professor Reed" if id == "professor" else "Survey repaired landing",
					"target":_markers[id], "enabled":true, "allowed":Callable(self,"action_allowed").bind(id),
					"invoke":Callable(self,"commit_action").bind(id)}
		var local := super.world_context()
		if not local.is_empty():
			return local
	return travel.world_context() if is_instance_valid(travel) else {}

func commit_action(id: String) -> bool:
	if id not in _markers:
		return super.commit_action(id)
	if not action_allowed(id):
		return false
	if id == "professor":
		return world.input_adapter.open_lesson("vaporization", PARTS.MILESTONE)
	return finish()

func _completion_ready(state: Dictionary) -> bool:
	return (state.items[PARTS.PLANK] == INSTALLED and _phase(state, "tray") == "gas" and _phase(state, "boiler") == "gas"
		and DEVICE.WORLD_INTRO.verified(store.data, PARTS.MILESTONE, DEVICE.MILESTONES[PARTS.MILESTONE]))

func completion_authorized() -> bool:
	return super.completion_authorized() and _near(points.exit)

func flags_for(id: String) -> Dictionary:
	var result := super.flags_for(id)
	if not result.is_empty() and world.player.carrying:
		for flag in result:
			result[flag] = false
	return result

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store, world)
	if outcome.is_empty():
		return false
	var binding: Dictionary = contract.targets[outcome.id]
	var next := _state.duplicate(true)
	next.components[binding.component].phase = outcome.to_state
	if not _supported_state(next):
		return false
	if store.commit_device_outcome(target, snapshot(next), world, [], _events(binding.events, outcome.id)):
		return true
	target.reset_after_restore(world, store)
	last_error = store.last_error
	world.input_adapter.feedback = SAVE_RETRY
	return false

func _frame(id: String, kit_id: String, label: String) -> void:
	var sprite: Sprite2D = component(id + "/control").visuals.get_node("Artwork")
	sprite.texture = load(PARTS.art(kit_id).path)
	_labels[id].text = label

func _apparatus(state: Dictionary) -> void:
	if not is_instance_valid(crossing) or crossing.spans.is_empty() or _labels.is_empty():
		return
	var support := _phase(state, "support")
	var installed: bool = state.items[PARTS.PLANK] == INSTALLED
	var protected_support := support == "latched"
	crossing.present("repair", protected_support,
		Color("b48b5e") if installed else (CROSSING.SOLID if support in ["solid","latched"] else CROSSING.OPEN_WATER))
	_labels.reflector.text = "ALIGNED" if _phase(state, "reflector") == "3" else "AIM SUNLIGHT"
	var tray := _phase(state, "tray")
	_frame("tray", {"empty":"solar_tray_empty","liquid":"solar_tray_supplied","gas":"solar_tray_observed"}[tray],
		{"empty":"SUNNY TRAY · EMPTY","liquid":"SHALLOW WATER","gas":"SURFACE LOSS OBSERVED"}[tray])
	var float_phase := _phase(state, "float")
	if tray == "gas" and float_phase == "covered":
		float_phase = "revealed"
	_frame("float", "float_latch_" + float_phase, {"covered":"LATCH COVERED","revealed":"LATCH EXPOSED","latched":"LATCH SET"}[float_phase])
	var boiler := _phase(state, "boiler")
	_frame("boiler", {"empty":"boiler_empty","open":"boiler_cover_open","liquid":"boiler_covered","gas":"boiler_cooled"}[boiler],
		{"empty":"COMPARISON · EMPTY","open":"FILLED · GUARD OPEN","liquid":"GUARDED · VENT OPEN","gas":"BULK BOILING OBSERVED"}[boiler])
	var turbine := _phase(state, "turbine")
	_frame("turbine", "model_turbine_" + turbine, "MODEL WHEEL · LATCH SET" if turbine == "latched" else "MODEL WHEEL")
	_labels.crate.text = "CRATE THAWED" if _phase(state, "crate") == "liquid" else "ICE-PACKED CRATE"
	_labels.support.text = {"empty":"SUPPORT · EMPTY","liquid":"LIQUID · UNSUPPORTED","solid":"SOLID · SECURE FRAME","latched":"SECURED · WALK ACROSS"}[support]
	_frame("landing", "landing_repaired" if installed else "landing_damaged", "LANDING REPAIRED" if installed else "DAMAGED LANDING")

func present() -> void:
	super.present()
	_apparatus(_state)
	_cue_frame = -1
	var compared := _phase(_state, "boiler") == "gas"
	var evaporated := _phase(_state, "tray") == "gas"
	var repaired: bool = _state.items[PARTS.PLANK] == INSTALLED
	chunk.quests = [
		{"text":"Sunny Tray · observe surface evaporation", "state":"done" if evaporated else "active"},
		{"text":"Guarded chamber · observe bubbling throughout", "state":"done" if compared else ("active" if evaporated else "blocked")},
		{"text":"Melt crate ice, freeze support, carry and fit plank", "state":"done" if repaired else ("active" if compared else "blocked")},
	]
	if not DEVICE.has_lesson(store.data, DEVICE.MILESTONES[PARTS.MILESTONE]):
		chunk.tutorial = "Ask Professor Reed about vaporization."
	elif not evaporated:
		chunk.tutorial = "Sunny Tray · open, align, fill, then heat."
	elif not compared:
		chunk.tutorial = "Set float latch. Fill, guard, then heat."
	elif _state.items[PARTS.PLANK] == "player":
		chunk.tutorial = "Carry the plank back to the landing."
	elif not repaired and _phase(_state, "support") == "latched":
		chunk.tutorial = "Cross the ice to pick up the plank."
	elif not repaired:
		chunk.tutorial = "Set wheel latch. Thaw crate; freeze and secure support."
	else:
		chunk.tutorial = "Survey the repaired landing at the exit."

func _process(_delta: float) -> void:
	if not active() or _state.is_empty():
		return
	var tray: Node = targets.get("sunny_tray_evaporation")
	var boiler: Node = targets.get("sunlit_chamber_boiling")
	var frame := -1
	if is_instance_valid(tray) and not tray.is_committed() and tray.exposure() > 0:
		frame = mini(3, int(tray.exposure() * 4) % 2 + (2 if tray.exposure() >= 2 else 0))
	elif is_instance_valid(boiler) and not boiler.is_committed() and boiler.exposure() > 0:
		frame = 4 if boiler.exposure() < 2.5 else 5 + int(boiler.exposure() * 4) % 2
	if frame == _cue_frame:
		return
	if frame >= 0 and world.input_adapter.feedback == SAVE_RETRY:
		world.input_adapter.feedback = ""
	_cue_frame = frame
	if frame < 0:
		_apparatus(_state)
	elif frame < 4:
		_frame("tray", ["solar_tray_evap_a","solar_tray_evap_b","solar_tray_low","solar_tray_evap_b"][frame], "SURFACE LOSS · MODEL CUE")
	elif frame == 4:
		_frame("boiler", "boiler_warm", "GUARDED · HEATING")
	else:
		var suffix := "a" if frame == 5 else "b"
		_frame("boiler", "boiler_boil_" + suffix, "BUBBLES THROUGHOUT")
		_frame("turbine", "model_turbine_turn_" + suffix, "VAPOR FLOW · MODEL CUE")

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var saved: Variant = store.world_record().get("attempts", {}).get(REGION, {}).get("attempt", {}).get("state", {}).get(STATE_KEY)
	var state: Dictionary = saved if _supported_state(saved) else default_state()
	var locations: Dictionary = {}
	for assembly in assemblies.values():
		for id in assembly.specs:
			locations[assembly.assembly_id + "/" + id] = assembly.ground_point(assembly.specs[id])
	for assembly in assemblies.values():
		assembly.present(state.components, state.items, locations)
	_apparatus(state)

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_checkpoints() -> Array:
	var result: Array = []
	for id in CHECKPOINTS:
		result.append({"id":id, "name":id, "position":world.checkpoint_anchor(REGION,id), "attuned":_travel_allowed(id),
			"allowed":Callable(self,"_travel_allowed").bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION, world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	for record in _reservation_footprints:
		record.layer = record.original_layer
		if is_instance_valid(record.get("body")):
			record.body.collision_layer = record.layer
	for prop in _reservation_art:
		if is_instance_valid(prop):
			prop.show()
	for marker in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	super._exit_tree()
