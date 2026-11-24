extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Snowbound practice chain. The equipment stays in this subregion.
const PARTS = preload("res://Scripts/World/Zone1/workshop_assembly.gd")
const REGION := "Z1L5"
const CHECKPOINTS := ["C0", "C1", "C2"]
const BLUEPRINT_ID := "melting_and_freezing:5:boat_blueprint"
const PLANK := "practice_plank"
const RACK := "world:rig/rack"
const FRAME := "installed:rig/frame"
const RELAY_SECONDS := 3.0
enum Step { FROSTED, THAWED, OPEN, FILLED, FROZEN, FITTED, RELEASED, DRAINED, RECORDED }
const HINTS := [
	"Turn both mirrors to feed the latch heater.",
	"Open the thawed storage latch.",
	"Open the walkback gate and fill the jig.",
	"Cryo · freeze water in the filled jig.",
	"Carry the practice plank to the frozen jig.",
	"Thermal · melt the jig to release the workpiece.",
	"Open the drain to collect meltwater.",
	"Return the released sample to its rack.",
	"Boat blueprint recorded. Return to the workshop exit.",
]
var points: Dictionary = {}
var _labels: Dictionary = {}
var _reservation_art: Array[Node2D] = []
var _outlet: Marker2D
var _beam: Line2D
var _heat := 0.0
var _retry := 0.0
var _recovering := false
var _relay_attempt := ""

static func boat_blueprint_unlocked(profile: Dictionary) -> bool:
	var extras: Variant = profile.get("extras")
	if not extras is Dictionary:
		return false
	var receipts: Variant = extras.get("independent_puzzle_ids")
	return receipts is Dictionary and receipts.get(BLUEPRINT_ID) == "freeze_jig_release"

func bind_workshop(host: Node2D) -> bool:
	var owner = host.chunks.get(REGION + ".shell")
	if owner == null or get_parent() != owner:
		return false
	for station in host.models[0].data.stations:
		if station.subregion == REGION:
			points[station.id.get_slice(".", 1)] = host.models[0].v(station.ground_xy)
	points.court1 += Vector2(0, 58)
	points.court2 += Vector2(0, 56)
	points.court3 += Vector2(-38, 0)
	if not bind(host, owner, PARTS.definition(points), _completion_ready):
		return false
	bind_professor_help(points.professor,"workshop")
	chunk.checkpoint_provider = self
	_outlet = Marker2D.new()
	_outlet.position = points.exit - chunk.ground_origin - Vector2(0, world.raised_surface(points.exit).height)
	chunk.add_child(_outlet)
	_beam = Line2D.new()
	_beam.width = 2.5
	_beam.z_index = 1
	world.district_art_parent(chunk).add_child(_beam)
	for art in world.props:
		if str(art.get_meta("station_id", "")).begins_with(REGION + ".court"):
			_reservation_art.append(art)
			art.hide()
	for key in ["storage/latch", "storage/receiver", "rig/jig", "rig/rack", "desk/bench"]:
		var label := Label.new()
		label.position = Vector2(-65, -9 if key in ["storage/latch", "rig/jig"] else 6)
		label.size.x = 130
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_outline_color", Color("223c43"))
		label.add_theme_constant_override("outline_size", 4)
		component(key).visuals.add_child(label)
		_labels[key] = label
	present()
	return true

func default_state() -> Dictionary:
	var state := super.default_state()
	_set_step(state, Step.FROSTED)
	return state

func _set_step(state: Dictionary, step: int) -> void:
	state.workshop_step = step
	var parts: Dictionary = state.components
	var warmed := step >= Step.THAWED
	parts["storage/receiver"].phase = "on" if warmed else "off"
	parts["storage/heater"].phase = "on" if warmed else "off"
	parts["storage/latch"].phase = "solid" if not warmed else ("liquid" if step == Step.THAWED else "open")
	parts["rig/valve"].phase = "open" if step >= Step.FILLED else "closed"
	parts["rig/supply"].phase = "empty" if step >= Step.FILLED else "liquid"
	parts["rig/jig"].phase = ["empty", "liquid", "solid", "fitted", "released", "drained"][clampi(step - Step.OPEN, 0, 5)]
	parts["rig/drain"].phase = "open" if step >= Step.DRAINED else "closed"
	parts["rig/basin"].phase = "liquid" if step >= Step.DRAINED else "empty"
	parts["rig/plank"].phase = "finished" if step >= Step.RELEASED else "rough"
	state.boat_blueprint = step == Step.RECORDED

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw):
		return false
	var step: Variant = raw.get("workshop_step")
	if not step is int or step < Step.FROSTED or step > Step.RECORDED:
		return false
	var expected := super.default_state()
	_set_step(expected, step)
	for key in expected.components:
		if key not in ["storage/mirror_a", "storage/mirror_b", "rig/gate"] and raw.components[key].get("phase") != expected.components[key].phase:
			return false
	if not raw.get("boat_blueprint") is bool or raw.boat_blueprint != expected.boat_blueprint:
		return false
	var plank_owner: String = raw.items[PLANK]
	var gate_open: bool = raw.components["rig/gate"].phase == "open"
	if step < Step.OPEN:
		return plank_owner == RACK and not gate_open
	if step >= Step.FITTED and not gate_open:
		return false
	if step == Step.RECORDED:
		return plank_owner == RACK and gate_open
	if plank_owner != RACK and not gate_open:
		return false
	if step < Step.FITTED:
		return plank_owner in [RACK, "player"]
	return step == Step.DRAINED and plank_owner in [RACK, "player"] or plank_owner == FRAME

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	var earned: Array = ["C0"]
	if state.workshop_step >= Step.THAWED:
		earned.append("C1")
	if state.workshop_step >= Step.FITTED:
		earned.append("C2")
	var progress: Dictionary = store.normalize_checkpoint_progress(result.get("checkpoint_progress", {}), CHECKPOINTS, earned)
	for id in earned:
		progress = store.unlock_checkpoint(progress, id, CHECKPOINTS)
	result.checkpoint_progress = progress
	result.checkpoint = progress.latest_unlocked_checkpoint_id
	return result

func _near(at: Vector2, control := "") -> bool:
	var ground: Vector2 = world.player.position
	if world.player.jump_elapsed >= 0 or ground.distance_to(at) > 42 or not world.world_contact_allowed(ground, at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if control == "walkback":
		exclude.append(assemblies.rig.bodies.gate.get_rid())
	var query := PhysicsRayQueryParameters2D.create(ground, at, 1 | 2 | 8, exclude)
	query.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func action_allowed(id: String) -> bool:
	if not _can_write() or world.player.action_elapsed >= 0:
		return false
	if id == "exit":
		return _completion_ready(_state)
	var action: Dictionary = contract.actions.get(id, {})
	if action.is_empty() or not _near(component(action.component).position, id):
		return false
	var step: int = _state.workshop_step
	var owner: String = _state.items[PLANK]
	# Moving a fitted piece back out of its frame changes its unique owner,
	# so use the fitted owner rather than the base pickup's loose-item rule.
	if id == "retrieve":
		return step == Step.DRAINED and owner == FRAME and not world.player.carrying
	if not super.action_allowed(id):
		return false
	match id:
		"mirror_a", "mirror_b": return step == Step.FROSTED
		"open": return step == Step.THAWED
		"walkback", "fill": return step >= Step.OPEN and step <= Step.FROZEN
		"take": return step >= Step.OPEN and step <= Step.FROZEN and _state.components["rig/gate"].phase == "open" and owner == RACK
		"put_back": return step >= Step.OPEN and step <= Step.FROZEN
		"fit": return step == Step.FROZEN
		"drain": return step == Step.RELEASED
		"stow": return step == Step.DRAINED
		"draft": return step == Step.DRAINED and owner == RACK
	return false

func world_context() -> Dictionary:
	if action_allowed("exit"):
		return {"key":REGION + ":exit", "caption":"Leave Snowbound Workshop", "target":_outlet,
			"enabled":true, "allowed":Callable(self, "action_allowed").bind("exit"), "invoke":Callable(self, "commit_action").bind("exit")}
	return super.world_context()

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	if id == "exit":
		if finish():
			return true
		_failed()
		return false
	world.input_adapter.stop_all("workshop_action", true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	var successes: Array = []
	match id:
		"mirror_a", "mirror_b":
			var mirror: Dictionary = next.components["storage/" + id]
			mirror.phase = str((int(mirror.phase) + 1) % 8)
		"open": _set_step(next, Step.OPEN)
		"walkback": next.components["rig/gate"].phase = "open"
		"fill": _set_step(next, Step.FILLED)
		"take", "retrieve": next.items[PLANK] = "player"
		"put_back", "stow": next.items[PLANK] = RACK
		"fit":
			next.items[PLANK] = FRAME
			_set_step(next, Step.FITTED)
		"drain":
			_set_step(next, Step.DRAINED)
			successes.append({"puzzle":"release_practice_sample", "type":"freeze_jig_release", "topic":"freezing", "object":"workshop_jig"})
		"draft":
			_set_step(next, Step.RECORDED)
			successes.append({"puzzle":"boat_blueprint", "type":"freeze_jig_release"})
	return _commit(next, successes)

func _commit(next: Dictionary, successes: Array = [], events: Array = []) -> bool:
	if not _supported_state(next):
		return false
	if store.update_run_with_events(snapshot(next), successes, events, world):
		return true
	_failed()
	return false

func flags_for(id: String) -> Dictionary:
	var needed := Step.FILLED if id == "freeze_jig" else Step.FITTED
	return {"ready":not _state.is_empty() and _state.workshop_step == needed and not world.player.carrying}

func sample_for(id: String) -> Dictionary:
	if _state.is_empty():
		return {}
	var result: Dictionary = contract.targets[id].sample.duplicate()
	var phase: String = _state.components["rig/jig"].phase
	result.state = "solid" if phase == "fitted" else ("liquid" if phase == "released" else phase)
	result.amount = 0 if phase in ["empty", "drained"] else 1
	return result

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store, world)
	if outcome.is_empty() or not flags_for(outcome.id).ready:
		return false
	var next := _state.duplicate(true)
	_set_step(next, Step.FROZEN if outcome.id == "freeze_jig" else Step.RELEASED)
	var events := _events([{"id":"six_changes", "event":"observe-" + outcome.process, "members":[outcome.process]}], outcome.id)
	if store.commit_device_outcome(target, snapshot(next), world, [], events):
		return true
	_failed()
	return false

func _ray_open(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 | 2 | 8, [world.player.get_rid()])
	return world.world_contact_allowed(from, to) and world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _relay() -> bool:
	var first: Vector2 = component("storage/source").position
	var chain := PackedVector2Array([first])
	for key in ["mirror_a", "mirror_b", "receiver"]:
		chain.append(component("storage/" + key).position)
	var segments := PackedVector2Array([first])
	var valid := true
	for index in range(3):
		var from := chain[index]
		var to := chain[index + 1]
		if not _ray_open(from, to):
			valid = false
			break
		if index > 0:
			var key := "storage/mirror_a" if index == 1 else "storage/mirror_b"
			var angle := int(_state.components[key].phase) * PI / 4
			var aim := Vector2(sin(angle), cos(angle) * .5).normalized()
			if aim.dot(from.direction_to(to)) < .999:
				segments.append(from + aim * 24)
				valid = false
				break
		segments.append(to)
	var height: float = component("storage/source").elevation + 19
	for index in range(segments.size()):
		segments[index].y -= height
	_beam.points = segments
	_beam.default_color = Color("ffd77e") if valid else Color("ffeab199")
	return valid

func _process(delta: float) -> void:
	_retry = maxf(0, _retry - delta)
	if _recovering and _retry == 0:
		_recover()
	if not _can_write() or not is_instance_valid(_beam):
		return
	if _relay_attempt != _attempt:
		_relay_attempt = _attempt
		_heat = 0.0
	_beam.visible = world.player.position.distance_to(points.court1) < 230
	var aligned := _beam.visible and _relay()
	if _state.workshop_step == Step.FROSTED:
		_heat = minf(RELAY_SECONDS, _heat + delta) if aligned else 0.0
		if _heat >= RELAY_SECONDS and _retry == 0:
			var next := _state.duplicate(true)
			_set_step(next, Step.THAWED)
			var success := {"puzzle":"mirror_storage_latch", "type":"melt_solar_relay", "topic":"reflection", "object":"workshop_latch"}
			var events := _events([{"id":"six_changes", "event":"observe-melting", "members":["melting"]}], "mirror_storage_latch")
			_commit(next, [success], events)
	if _retry == 0:
		for target in targets.values():
			if not target.is_committed() and not target.verified_outcome(store, world).is_empty():
				commit_target(target)
				break

func refresh_binding() -> void:
	super.refresh_binding()
	if is_instance_valid(_beam):
		_beam.visible = active()

func suspend() -> void:
	_heat = 0.0
	super.suspend()

func present() -> void:
	if _state.is_empty():
		return
	super.present()
	var step: int = _state.workshop_step
	component("desk/blueprint").visible = boat_blueprint_unlocked(store.data)
	assemblies.rig.bodies.gate.collision_layer = 0 if _state.components["rig/gate"].phase == "open" else 2
	if _labels.is_empty():
		return
	_labels["storage/latch"].text = ["LATCH · FROZEN", "LATCH · THAWED", "LATCH · OPEN"][mini(step, Step.OPEN)]
	_labels["storage/receiver"].text = "RECEIVER"
	_labels["rig/jig"].text = "JIG · " + str(_state.components["rig/jig"].phase).to_upper()
	_labels["rig/rack"].text = "FINISHED SAMPLE" if step >= Step.RELEASED and _state.items[PLANK] == RACK else "SAMPLE RACK"
	_labels["desk/bench"].text = "BOAT BLUEPRINT" if step >= Step.RECORDED else "DRAFTING BENCH"
	chunk.quests = [
		{"text":"Align mirrors and open storage", "state":"done" if step >= Step.OPEN else "active"},
		{"text":"Fill, freeze and fit local plank", "state":"done" if step >= Step.FITTED else "active"},
		{"text":"Release, drain and record blueprint", "state":"done" if step >= Step.RECORDED else "active"},
	]
	chunk.tutorial = HINTS[step]
	if world.player.carrying and step < Step.FROZEN:
		chunk.tutorial = "Return plank to rack before freezing."
	elif step == Step.DRAINED and _state.items[PLANK] == RACK:
		chunk.tutorial = "Record the blueprint at the drafting bench."

func _completion_ready(state: Dictionary) -> bool:
	return state.get("workshop_step") == Step.RECORDED and boat_blueprint_unlocked(store.data) and not world.player.carrying and _near(points.exit)

func _failed() -> void:
	last_error = store.last_error
	world.input_adapter.feedback = "Save failed. Retry to commit workshop progress."
	_retry = 1.0

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
	if not active() or _state.is_empty():
		return false
	world.input_adapter.stop_all("workshop_fall", true)
	world.dead = true
	_recovering = true
	_recover()
	return true

func _recover() -> void:
	if world.recover_world_checkpoint(world.access):
		_recovering = false
	else:
		world.dead = true
		_retry = 1.0

func _exit_tree() -> void:
	for art in _reservation_art:
		if is_instance_valid(art):
			art.show()
	for node in [_outlet, _beam]:
		if is_instance_valid(node):
			node.queue_free()
	super._exit_tree()
