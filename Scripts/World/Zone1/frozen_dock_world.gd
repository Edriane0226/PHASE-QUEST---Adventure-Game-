extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Frozen Dock owns its apparatus, six unique parts, and the verified boarding action.
const PARTS = preload("res://Scripts/World/Zone1/dock_assembly.gd")
const CROSSING = preload("res://Scripts/World/Zone1/canal_crossings.gd")
const FINN = preload("res://Scripts/World/Learning/finn_challenge.gd")
const WORKSHOP = preload("res://Scripts/World/Zone1/workshop_world.gd")
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const REGION := "Z1L6"
const CONNECTION := "Z1L6--Z2L1"
const CHECKPOINTS := ["C0", "C1", "C2", "C3"]
const FITTED := "installed:jig/control"
const LAUNCH_RUN := Vector2(46, -16)
const LAUNCH_SECONDS := 1.5
const QUESTIONS := [
	{"id":"plank_ice", "prompt":"Thermal freed a plank from solid ice. What happened to the ice?",
		"choices":["It froze around the plank.", "It absorbed heat and melted into liquid water.", "It became a new substance."], "correct":1,
		"feedback":["Freezing goes from liquid to solid. The casing started solid and gained heat.", "Yes. Adding heat changed solid water to liquid water.", "The substance stayed water. Adding heat changed its state."]},
	{"id":"walkway", "prompt":"Why could you latch the filled walkway after using Cryo?",
		"choices":["Cryo removed heat, so its liquid water froze.", "Cryo added heat and hardened it.", "The latch created ice from an empty frame."], "correct":0,
		"feedback":["Yes. Cryo removed heat from the water, and the latch secured the solid ice in its frame.", "Adding heat cannot freeze this water. Cryo removed heat.", "The latch secured existing ice. The frame needed water before it could freeze."]},
	{"id":"jig", "prompt":"Why did you melt the frozen jig before testing the boat?",
		"choices":["The ice had to become the hull.", "Meltwater powered the boat.", "Melting freed the wooden hull so it could float on liquid water."], "correct":2,
		"feedback":["The wooden hull was already fitted. The ice held it in place during assembly.", "The meltwater released the hull. It supplied no propulsion.", "Yes. The jig held the pieces while you fitted them. Once free, the hull displaced water and floated."]},
]
var finn = FINN.new(QUESTIONS)
var points: Dictionary = {}
var crossing: Node
var travel: Node
var _markers: Dictionary = {}
var _reservation_art: Array[Node2D] = []
var _labels: Dictionary = {}
var _launch_art: Node2D
var _launch_time := -1.0
var _returning_from_help := false

func bind_dock(host: Node2D) -> bool:
	var owner: Node = get_parent()
	travel = owner.context_provider
	for station in host.models[0].data.stations:
		if station.subregion == REGION:
			points[station.id.get_slice(".", 1)] = host.models[0].v(station.ground_xy)
	var storage: Vector2 = points.court1
	var span: Vector2 = points.court2 + Vector2(-18, 15)
	var rig: Vector2 = points.court3
	points.merge({
		"plank1":storage + Vector2(-65,-37), "plank2":storage + Vector2(0,-54), "plank3":storage + Vector2(65,-37),
		"ramp":storage + Vector2(0, 36), "plank_rack":storage + Vector2(0, 83),
		"bridge":span, "tray":span + Vector2(-74, 0), "water":span + Vector2(-107, 60),
		"latch":span + Vector2(-104,-18), "shutter":span + Vector2(-129,-57),
		"rope":span + Vector2(86,-16), "sailcloth":span + Vector2(86,16), "rudder":span + Vector2(-150, 36),
		"rigging_rack":span + Vector2(-116, 19),
		"jig":rig, "fill_jig":rig + Vector2(-85, 26), "launch":points.court4 + Vector2(-53, 22),
	})
	if not bind(host, owner, PARTS.definition(points), _completion_ready):
		return false
	crossing = CROSSING.new()
	add_child(crossing)
	if not crossing.install(host, owner, {}, {"dock":span}):
		chunk.runtime_provider = null
		chunk.context_provider = travel
		return _reject("Dock walkway requires level supported banks.")
	chunk.checkpoint_provider = self
	for id in ["finn", "professor", "exit"]:
		var marker := Marker2D.new()
		var at: Vector2 = points[id]
		marker.position = at - chunk.ground_origin - Vector2(0, world.raised_surface(at).height)
		chunk.add_child(marker)
		_markers[id] = marker
	for art in world.props:
		var station: String = art.get_meta("station_id", "")
		if station in ["Z1L6.court1", "Z1L6.court2", "Z1L6.court3", "Z1L6.court4"]:
			_reservation_art.append(art)
			art.hide()
	for id in ["plank1","plank2","plank3","ramp","plank_rack","water","latch","shutter","rope","sailcloth","rudder","rigging_rack","jig","fill_jig","launch"]:
		var label := Label.new()
		label.position = Vector2(-58, 5)
		label.size.x = 116
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_outline_color", Color("223c43"))
		label.add_theme_constant_override("outline_size", 4)
		var label_anchor: Node2D = component(id + "/ice") if id in PARTS.PLANKS or id == "rudder" else null
		if label_anchor == null:
			label_anchor = component(contract.actions[_label_action(id)].component)
		label_anchor.visuals.add_child(label)
		_labels[id] = label
	_build_launch_basin()
	sync_world_permissions()
	return true

func _label_action(id: String) -> String:
	match id:
		"plank_rack": return "rack_plank1"
		"rigging_rack": return "rack_rope"
		"water": return "fill_walkway"
		"latch": return "latch_walkway"
		"shutter": return "isolate_heat"
		"jig": return "recipe"
		"launch": return "test"
	return "take_" + id if PARTS.RECIPE.has(id) else id

func _build_launch_basin() -> void:
	var basin = ANCHOR.new()
	basin.name = "LaunchBasin"
	basin.position = points.launch + Vector2(66, -22)
	basin.elevation = world.raised_surface(basin.position).get("height", 0)
	world.district_art_parent(chunk).add_child(basin)
	_launch_art = basin
	for layer in [{"id":"Frame", "size":Vector2(114,56), "color":Color("5a5254")}, {"id":"Water", "size":Vector2(106,48), "color":Color("4d8aa1")}]:
		var surface := Polygon2D.new()
		surface.name = layer.id
		surface.polygon = world.models[0].rect_poly(Rect2(-layer.size / 2, layer.size))
		surface.color = layer.color
		basin.visuals.add_child(surface)
	var hull := Sprite2D.new()
	var art := PARTS.visual("boat_assembly_launched", .66)
	hull.name = "Hull"
	hull.centered = false
	hull.texture = load(art.path)
	hull.scale = Vector2.ONE * float(art.scale)
	hull.offset = -Vector2(art.pivot_px[0], art.pivot_px[1])
	hull.position = -LAUNCH_RUN / 2
	hull.hide()
	basin.visuals.add_child(hull)

func default_state() -> Dictionary:
	var state := super.default_state()
	state.finn = finn.initial_state()
	return state

func _phase(state: Dictionary, key: String) -> String:
	return state.components[key].phase

func _staged(id: String) -> String:
	return "installed:" + contract.items[id].rack + "/control"

func _cargo_ready(state: Dictionary, ids: Array) -> bool:
	return ids.all(func(id): return state.items[id] in [_staged(id), FITTED])

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or not finn.valid(raw.get("finn")) or raw.items.size() != PARTS.RECIPE.size():
		return false
	var jig := _phase(raw, "jig/control")
	var assembled := jig in ["assembled", "released", "tested"]
	var latched := _phase(raw, "walkway/tray") == "latched"
	var isolated := _phase(raw, "shutter/control") == "isolated"
	if (_phase(raw, "latch/control") == "latched") != latched or (isolated and not latched):
		return false
	if (_phase(raw, "walkway/tray") == "dry") != (_phase(raw, "water/control") == "dry"):
		return false
	if (jig == "empty") != (_phase(raw, "fill_jig/control") == "full"):
		return false
	if jig != "tested" and raw.finn != finn.initial_state():
		return false
	for id in PARTS.RECIPE:
		var owner: String = raw.items[id]
		var ready := latched
		if id in PARTS.PLANKS:
			ready = _phase(raw, "ramp/control") == "open" and _phase(raw, id + "/ice") == "liquid"
		elif id == "rudder":
			ready = isolated and _phase(raw, "rudder/ice") == "liquid"
		if (owner == FITTED) != assembled or owner not in [contract.items[id].initial_owner, "player", _staged(id), FITTED]:
			return false
		if owner != contract.items[id].initial_owner and not ready:
			return false
	return true

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	var earned := ["C0"]
	if _cargo_ready(state, PARTS.PLANKS):
		earned.append("C1")
	if _cargo_ready(state, PARTS.RECIPE.keys()):
		earned.append("C2")
	if _phase(state, "jig/control") == "tested":
		earned.append("C3")
	var progress: Dictionary = store.normalize_checkpoint_progress(result.get("checkpoint_progress", {}), CHECKPOINTS, earned)
	for id in earned:
		progress = store.unlock_checkpoint(progress, id, CHECKPOINTS)
	result.checkpoint_progress = progress
	result.checkpoint = progress.latest_unlocked_checkpoint_id
	result.position = REGISTRY.ground_to_local(REGION, world.player.safe_save_position())
	return result

func _near(at: Vector2, control := "") -> bool:
	var ground: Vector2 = world.player.position
	if world.player.jump_elapsed >= 0 or ground.distance_to(at) > 36 or not world.world_contact_allowed(ground, at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if control == "ramp":
		exclude.append(assemblies.ramp.bodies.control.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(ground, at, 1 | 2 | 8, exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _recoverable(id: String) -> bool:
	if id in PARTS.PLANKS:
		return _phase(_state, "ramp/control") == "open" and _phase(_state, id + "/ice") == "liquid"
	if id == "rudder":
		return _phase(_state, "rudder/ice") == "liquid"
	return _phase(_state, "walkway/tray") == "latched"

func action_allowed(id: String) -> bool:
	if not _can_write() or world.player.action_elapsed >= 0 or _launch_time >= 0:
		return false
	if id in _markers:
		return not world.player.carrying and _near(points[id]) and (id != "exit" or _completion_ready(_state))
	var action: Dictionary = contract.actions.get(id, {})
	if action.is_empty() or not _near(component(action.component).position, id):
		return false
	if action.kind == "pickup":
		return not world.player.carrying and _recoverable(action.item) and _state.items[action.item] == contract.items[action.item].initial_owner
	if action.kind == "place":
		return _state.items[action.item] == "player"
	if world.player.carrying:
		return false
	match id:
		"ramp": return _phase(_state, "ramp/control") == "closed"
		"fill_walkway": return _phase(_state, "walkway/tray") == "dry"
		"latch_walkway": return _phase(_state, "walkway/tray") == "solid"
		"isolate_heat": return _phase(_state, "walkway/tray") == "latched" and _phase(_state, "shutter/control") == "connected"
		"fill_jig": return WORKSHOP.boat_blueprint_unlocked(store.data) and _phase(_state, "jig/control") == "empty"
		"recipe": return true
		"test": return _phase(_state, "jig/control") == "released" and _near(points.launch)
	return false

func world_context() -> Dictionary:
	if active() and not _state.is_empty():
		for id in _markers:
			if action_allowed(id):
				var caption: String = {"finn":"Talk to Finn", "professor":"Ask Professor Scaldwell", "exit":"Board boat"}[id]
				return _context_for(id, caption, _markers[id])
		var local := super.world_context()
		if not local.is_empty():
			return local
	return travel.world_context() if is_instance_valid(travel) else {}

func _context_for(id: String, caption: String, marker: Node2D) -> Dictionary:
	return {"key":REGION + ":" + id, "caption":caption, "target":marker, "enabled":true,
		"allowed":Callable(self, "action_allowed").bind(id), "invoke":Callable(self, "commit_action").bind(id)}

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"exit": return _board()
		"professor": return _open_professor()
		"finn": return _open_finn()
		"recipe": return _open_recipe()
		"test":
			world.input_adapter.stop_all("launch_test", true)
			_launch_time = 0.0
			return true
	world.input_adapter.stop_all("dock_action", true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var action: Dictionary = contract.actions[id]
	match action.kind:
		"pickup": next.items[action.item] = "player"
		"place": next.items[action.item] = _staged(action.item) if id.begins_with("rack_") else contract.items[action.item].initial_owner
		"set":
			match id:
				"ramp": next.components["ramp/control"].phase = "open"
				"fill_walkway":
					next.components["water/control"].phase = "filled"
					next.components["walkway/tray"].phase = "liquid"
				"latch_walkway":
					next.components["latch/control"].phase = "latched"
					next.components["walkway/tray"].phase = "latched"
				"isolate_heat": next.components["shutter/control"].phase = "isolated"
				"fill_jig":
					next.components["fill_jig/control"].phase = "empty"
					next.components["jig/control"].phase = "liquid"
	return _commit(next)

func _commit(next: Dictionary, successes: Array = [], events: Array = []) -> bool:
	if not _supported_state(next):
		return false
	if store.update_run_with_events(snapshot(next), successes, events, world):
		return true
	_failed()
	return false

func flags_for(id: String) -> Dictionary:
	if _state.is_empty() or world.player.carrying:
		return {"ready":false}
	var binding: Dictionary = contract.targets[id]
	var gate: Dictionary = binding.flags.ready
	var ready: bool = _phase(_state, gate.component) == gate.value
	if id == "thaw_rudder":
		ready = ready and _phase(_state, "shutter/control") == "isolated"
	elif id.begins_with("thaw_"):
		ready = ready and _phase(_state, "ramp/control") == "open"
	return {"ready":ready}

func sample_for(id: String) -> Dictionary:
	if _state.is_empty():
		return {}
	var binding: Dictionary = contract.targets[id]
	var result: Dictionary = binding.sample.duplicate()
	var phase := _phase(_state, binding.component)
	result.state = "solid" if phase == "assembled" else phase
	result.amount = 0 if phase in ["dry", "empty", "tested"] else 1
	return result

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store, world)
	if outcome.is_empty() or not flags_for(outcome.id).ready:
		return false
	var next := _state.duplicate(true)
	next.components[contract.targets[outcome.id].component].phase = "released" if outcome.id == "release_jig" else outcome.to_state
	if not _supported_state(next):
		return false
	var events := _events([{"id":"six_changes", "event":outcome.process, "members":[outcome.process]}], outcome.id)
	if store.commit_device_outcome(target, snapshot(next), world, [], events):
		return true
	# A failed binary write leaves the material unchanged. A fresh exposure can retry.
	target.reset_after_restore(world, store)
	_failed()
	return false

func _open_recipe(status := "") -> bool:
	var rows: Array = []
	for id in PARTS.RECIPE:
		var owner: String = _state.items[id]
		var text := "Fitted" if owner == FITTED else ("At local rack" if owner == _staged(id) else "Recover to local rack")
		rows.append({"title":PARTS.RECIPE[id], "text":text})
	var blueprint := WORKSHOP.boat_blueprint_unlocked(store.data)
	var jig := _phase(_state, "jig/control")
	var can_fit := blueprint and jig == "solid" and _cargo_ready(_state, PARTS.RECIPE.keys())
	var hint := "Jig · " + jig.capitalize() if blueprint else "Record the boat blueprint in Snowbound Workshop."
	return world.input_adapter.open_provider_panel(self, _recipe_intent, "craft.z1_missing", {
		"title":"Boat recipe", "body":"Three plank bundles, one rope coil, one sailcloth and one rudder kit.",
		"status":hint if status.is_empty() else status, "rows":rows,
		"actions":[{"id":"assemble", "label":"Fit all six parts", "enabled":can_fit}],
	})

func _recipe_intent(id: String, _payload: Dictionary) -> void:
	if id != "assemble":
		return
	world.input_adapter.close_panel()
	if not action_allowed("recipe") or not WORKSHOP.boat_blueprint_unlocked(store.data) or _phase(_state, "jig/control") != "solid" or not _cargo_ready(_state, PARTS.RECIPE.keys()):
		return
	var next := _state.duplicate(true)
	for part in PARTS.RECIPE:
		next.items[part] = FITTED
	next.components["jig/control"].phase = "assembled"
	if not _commit(next):
		_open_recipe("Save failed. All six parts are still at their racks.")

func _process(delta: float) -> void:
	if _launch_time < 0:
		return
	if not _can_write() or world.player.carrying or not _near(points.launch):
		_launch_time = -1.0
		_present_launch(false)
		return
	_launch_time += delta
	_present_launch(false)
	if _launch_time >= LAUNCH_SECONDS:
		_launch_time = -1.0
		var next := _state.duplicate(true)
		next.components["jig/control"].phase = "tested"
		var success := {"puzzle":"boat_float_test", "type":"freeze_jig_release", "topic":"melting", "object":"dock_jig"}
		if not _commit(next, [success], _events([{"id":"boatwright", "event":"float_test", "members":[]}], "launch")):
			_present_launch(false)

func _open_professor() -> bool:
	if not _note_finn_help():
		return false
	return world.input_adapter.open_lesson("freezing")

func _note_finn_help() -> bool:
	if _phase(_state, "jig/control") != "tested" or _state.finn.help_used or not _state.finn.started or finn.passed(_state.finn):
		return true
	var next := _state.duplicate(true)
	next.finn.help_used = true
	return _commit(next)

func _open_finn() -> bool:
	_returning_from_help = false
	if _phase(_state, "jig/control") != "tested":
		return world.input_adapter.open_provider_panel(self, _finn_intent, "finn.wait", {
			"body":"Recover the parts and test the boat in liquid water. Then come see me.", "actions":[], "status":"",
		})
	if not _state.finn.started:
		var next := _state.duplicate(true)
		next.finn.started = true
		if not _commit(next):
			return false
	return _show_question(finn.review_index(_state.finn), true)

func _show_question(index: int, feedback: bool, status := "") -> bool:
	if index == QUESTIONS.size():
		return world.input_adapter.open_provider_panel(self, _finn_intent, "finn.z1_passed", {
			"body":"All three answers are correct. Board at the dock exit.", "status":"3 / 3 correct", "actions":[],
		})
	var model: Dictionary = finn.question_view(_state.finn, index, feedback)
	model.context_key = str(index)
	if not status.is_empty():
		model.status = status
	return world.input_adapter.open_provider_panel(self, _finn_intent, "finn.z1_question", model)

func _finn_intent(id: String, payload: Dictionary) -> void:
	if _phase(_state, "jig/control") != "tested" or not _near(points.finn):
		return
	var raw := str(payload.get("context_key",""))
	var index := raw.to_int() if raw.is_valid_int() else -1
	match id:
		"next_question":
			var next := _state.duplicate(true)
			if not finn.acknowledge_review(next.finn,index): return
			if _commit(next): _show_question(finn.review_index(_state.finn),true)
			else: _show_question(index,true,"Feedback could not be acknowledged. Try again.")
		"retry_question":
			if index == finn.passed_count(_state.finn): _show_question(index, false)
		"help":
			if index < 0 or index >= QUESTIONS.size() or index != finn.passed_count(_state.finn): return
			var next := _state.duplicate(true)
			next.finn.help_used = true
			if not _commit(next):
				_show_question(index, false, "Help is free. The save failed. Try again.")
				return
			_returning_from_help = true
			var question: Dictionary = QUESTIONS[index]
			world.input_adapter.open_provider_panel(self, _finn_intent, "guides.library", {
				"title":"Finn · free help", "speaker":"finn", "body":question.feedback[question.correct],
				"search":false, "rows":[], "actions":[{"id":"back_to_finn", "label":"Back to Finn", "enabled":true}],
			})
		"back_to_finn":
			if _returning_from_help:
				_returning_from_help = false
				_show_question(finn.review_index(_state.finn), true)
		"submit":
			var next := _state.duplicate(true)
			if not finn.record(next.finn, index, str(payload.get("selected_choice", ""))):
				return
			var events := _events([{"id":"clear_explanation", "event":"first_attempts", "members":[]}], "finn") if finn.perfect(next.finn) else []
			if _commit(next, [], events):
				_show_question(index, true)
			else:
				_show_question(index, false, "Answer could not be saved. Try again.")

func _completion_ready(state: Dictionary) -> bool:
	return not state.is_empty() and WORKSHOP.boat_blueprint_unlocked(store.data) and _phase(state, "jig/control") == "tested" and finn.passed(state.finn) and not world.player.carrying and _near(points.exit)

func _board() -> bool:
	if store.is_level_complete(world.SAVE_ZONE, world.SAVE_LEVEL):
		return world.start_transit(CONNECTION)
	contract.completion_events = [{"id":"snow_scholar", "event":"board_boat", "members":[]}]
	if not finish():
		_failed()
		return false
	return world.start_transit(CONNECTION)

func boat_earned() -> bool:
	if not store.is_level_complete(store.ZONES[0], 6):
		return false
	var saved: Variant = _archived_state()
	return _supported_state(saved) and _phase(saved, "jig/control") == "tested" and finn.passed(saved.finn)

func _archived_state() -> Variant:
	return store.world_record().get("attempts", {}).get(REGION, {}).get("attempt", {}).get("state", {}).get(STATE_KEY, {})

func sync_world_permissions() -> void:
	if not is_instance_valid(crossing) or not crossing.spans.has("dock"):
		return
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var saved: Variant = _archived_state()
	_present_apparatus(saved if _supported_state(saved) else default_state())

func present() -> void:
	if _state.is_empty():
		return
	super.present()
	_present_apparatus(_state)
	if _labels.is_empty():
		return
	var jig := _phase(_state, "jig/control")
	var ready := _cargo_ready(_state, PARTS.RECIPE.keys())
	chunk.quests = [
		{"text":"Stow 3 plank bundles at storage", "state":"done" if _cargo_ready(_state, PARTS.PLANKS) else "active"},
		{"text":"Secure walkway and stow rope, sailcloth, rudder", "state":"done" if _cargo_ready(_state, PARTS.RIGGING) else "active"},
		{"text":"Fill, freeze, fit, release and test boat", "state":"done" if jig == "tested" else ("active" if ready else "blocked")},
		{"text":"Answer Finn and board at dock exit", "state":"done" if boat_earned() else ("active" if jig == "tested" else "blocked")},
	]
	chunk.tutorial = "Local racks accept one carried part at a time." if not ready else (
		"The released hull goes to the launch basin." if jig == "released" else
		"See Finn at the sheltered dock." if jig == "tested" and not finn.passed(_state.finn) else
		"Board the boat at the dock exit." if jig == "tested" else "Use the recipe at the frozen assembly jig.")

func _present_apparatus(state: Dictionary) -> void:
	var latched := _phase(state, "walkway/tray") == "latched"
	var frozen := latched or _phase(state, "walkway/tray") == "solid"
	if is_instance_valid(crossing) and crossing.spans.has("dock"):
		crossing.present("dock", latched, CROSSING.SOLID if frozen else CROSSING.OPEN_WATER)
	assemblies.ramp.bodies.control.collision_layer = 0 if _phase(state, "ramp/control") == "open" else 2
	for id in PARTS.RECIPE:
		var owner: String = state.items[id]
		var placed := owner == _staged(id)
		var loose: bool = owner == contract.items[id].initial_owner
		var ice: Node2D = component(id + "/ice")
		var source: Node2D = component(id + "/cargo")
		var visible_cargo := loose and (ice == null or _phase(state, id + "/ice") == "liquid")
		source.visible = visible_cargo or placed
		var rack: String = contract.items[id].rack
		var rack_spots := PARTS.PLANKS if id in PARTS.PLANKS else PARTS.RIGGING
		source.position = points[rack] + Vector2((rack_spots.find(id) - 1) * 24, -10) if placed else points[id]
		if ice:
			ice.visible = loose
			if id in PARTS.PLANKS:
				source.visible = placed
		if _labels.has(id):
			_labels[id].text = PARTS.RECIPE[id].to_upper()
		if placed and _labels.has(id):
			_labels[id].hide()
		elif _labels.has(id):
			_labels[id].show()
	if not _labels.is_empty():
		_labels.plank_rack.text = "PLANKS · %d / 3" % _staged_count(state, PARTS.PLANKS)
		_labels.rigging_rack.text = "RIGGING · %d / 3" % _staged_count(state, PARTS.RIGGING)
		_labels.ramp.text = "CARGO RAMP · " + _phase(state, "ramp/control").to_upper()
		_labels.water.text = "WALKWAY SUPPLY"
		_labels.latch.text = "WALKWAY · " + _phase(state, "walkway/tray").to_upper()
		_labels.shutter.text = "HEAT SHUTTER"
		_labels.jig.text = "JIG · " + _phase(state, "jig/control").to_upper()
		_labels.fill_jig.text = "JIG SUPPLY"
		_labels.launch.text = "LAUNCH BASIN"
	_present_launch(_phase(state, "jig/control") == "tested")

func _staged_count(state: Dictionary, ids: Array) -> int:
	return ids.filter(func(id): return state.items[id] in [_staged(id), FITTED]).size()

func _present_launch(tested: bool) -> void:
	if not is_instance_valid(_launch_art):
		return
	var hull := _launch_art.get_node("Visuals/Hull") as Sprite2D
	hull.visible = tested or _launch_time >= 0
	component("jig/control").visible = _launch_time < 0
	var progress := 1.0 if tested else clampf(_launch_time / LAUNCH_SECONDS, 0, 1)
	hull.position = LAUNCH_RUN * (progress - .5)

func _failed() -> void:
	last_error = store.last_error
	world.input_adapter.feedback = "Dock progress could not be saved. Try again."

func suspend() -> void:
	_cancel_launch()
	super.suspend()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_launch()

func _cancel_launch() -> void:
	if _launch_time >= 0:
		_launch_time = -1.0
		_present_launch(false)

func world_checkpoints() -> Array:
	var result: Array = []
	for id in CHECKPOINTS:
		result.append({"id":id, "name":id, "position":world.checkpoint_anchor(REGION, id),
			"attuned":_travel_allowed(id), "allowed":Callable(self, "_travel_allowed").bind(id)})
	return result

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION, world.checkpoint_anchor(REGION, id))

func recover_world_fall() -> bool:
	_launch_time = -1.0
	return world.recover_world_checkpoint(world.access)

func _exit_tree() -> void:
	for art in _reservation_art:
		if is_instance_valid(art):
			art.show()
	for node in _markers.values() + [_launch_art]:
		if is_instance_valid(node):
			node.queue_free()
	super._exit_tree()
