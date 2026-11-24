extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Two-State Canal. Each step has one ordered, independently committed outcome.
const PARTS = preload("res://Scripts/World/Zone1/canal_assembly.gd")
const CROSSINGS = preload("res://Scripts/World/Zone1/canal_crossings.gd")
const REGION := "Z1L4"
const CHECKPOINTS := ["C0", "C1", "C2"]
enum Step {
	BLOCKED, THAWED, DIVERTED, ISOLATED, SIDE_FROZEN, DRIVE_ENGAGED,
	LOCK_THAWED, CARRYING, SEATED, REFROZEN, LATCHED, RELEASED
}
const TRANSITIONS := {
	"thaw_intake":Step.BLOCKED, "freeze_side":Step.ISOLATED,
	"thaw_lock":Step.DRIVE_ENGAGED, "refreeze_lock":Step.SEATED,
}
const ACTIONS := {
	"divert":Step.THAWED, "isolate":Step.DIVERTED, "drive":Step.SIDE_FROZEN,
	"pickup":Step.LOCK_THAWED, "seat":Step.CARRYING, "latch":Step.REFROZEN,
	"release":Step.LATCHED,
}
var points: Dictionary = {}
var crossings: Node
var exit_marker: Marker2D
var _reservation_art: Array[Node2D] = []
var _labels: Dictionary = {}
var _retry := 0.0
var _recovering := false
var _wheel_frame := -1

func bind_canal(host: Node2D) -> bool:
	var owner = host.chunks.get(REGION + ".shell")
	if owner == null or get_parent() != owner:
		return false
	for station in host.models[0].data.stations:
		if station.subregion == REGION:
			points[station.id.get_slice(".", 1)] = host.models[0].v(station.ground_xy)
	points.court1 += Vector2(24, -51)
	points.court2 += Vector2(23, 0)
	points.court3 += Vector2(0, -38)
	if not bind(host, owner, PARTS.definition(points), _completion_ready):
		return false
	bind_professor_help(points.professor,"canal")
	crossings = CROSSINGS.new()
	add_child(crossings)
	if not crossings.install(world, chunk, points):
		last_error = "Canal crossings require level banks inside their reservations."
		return false
	chunk.checkpoint_provider = self
	exit_marker = Marker2D.new()
	exit_marker.position = points.exit - chunk.ground_origin - Vector2(0, world.raised_surface(points.exit).height)
	chunk.add_child(exit_marker)
	for art in world.props:
		if str(art.get_meta("station_id", "")).begins_with(REGION + ".court"):
			_reservation_art.append(art)
			art.hide()
	for key in ["intake/water", "wheel_channel/main", "branches/side", "correction/lock"]:
		var label := Label.new()
		label.position = Vector2(-60, 5)
		label.size.x = 120
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_outline_color", Color("223c43"))
		label.add_theme_constant_override("outline_size", 4)
		component(key).visuals.add_child(label)
		_labels[key] = label
	sync_world_permissions()
	return true

func default_state() -> Dictionary:
	var state := super.default_state()
	_apply_step(state, Step.BLOCKED)
	return state

func _apply_step(state: Dictionary, step: int) -> void:
	state.canal_step = step
	var parts: Dictionary = state.components
	parts["intake/water"].phase = "liquid" if step >= Step.THAWED else "solid"
	parts["intake/diverter"].phase = "side" if step == Step.DIVERTED else "main"
	parts["branches/isolator"].phase = "closed" if step >= Step.ISOLATED else "open"
	parts["branches/side"].phase = "solid" if step >= Step.SIDE_FROZEN else ("liquid" if step >= Step.DIVERTED else "empty")
	parts["wheel_channel/main"].phase = "liquid" if step >= Step.ISOLATED else "blocked"
	parts["wheel_channel/wheel"].phase = "turning" if step >= Step.ISOLATED else "stopped"
	parts["branches/drive"].phase = "engaged" if step >= Step.DRIVE_ENGAGED else "open"
	parts["correction/lock"].phase = ["wrong", "thawed", "thawed", "seated", "frozen", "latched"][clampi(step - Step.DRIVE_ENGAGED, 0, 5)]
	parts["correction/socket"].phase = "occupied" if step >= Step.SEATED else "empty"
	parts["correction/latch"].phase = "latched" if step >= Step.LATCHED else "open"
	parts["correction/release"].phase = "open" if step == Step.RELEASED else "closed"
	state.items.bridge_lock = "installed:correction/socket" if step >= Step.SEATED else ("player" if step == Step.CARRYING else "world:correction/lock")

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw):
		return false
	var step: Variant = raw.get("canal_step")
	if not step is int or step < Step.BLOCKED or step > Step.RELEASED:
		return false
	var expected := super.default_state()
	_apply_step(expected, step)
	for key in expected.components:
		if raw.components[key].get("phase") != expected.components[key].phase:
			return false
	return raw.items.bridge_lock == expected.items.bridge_lock

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	var earned: Array = ["C0"]
	if state.canal_step >= Step.DIVERTED:
		earned.append("C1")
	if state.canal_step >= Step.DRIVE_ENGAGED:
		earned.append("C2")
	var progress: Dictionary = store.normalize_checkpoint_progress(result.get("checkpoint_progress", {}), CHECKPOINTS, earned)
	for id in earned:
		progress = store.unlock_checkpoint(progress, id, CHECKPOINTS)
	result.checkpoint_progress = progress
	result.checkpoint = progress.latest_unlocked_checkpoint_id
	return result

func sample_for(id: String) -> Dictionary:
	var sample: Dictionary = contract.targets[id].sample.duplicate()
	if _state.is_empty():
		return {}
	var parts: Dictionary = _state.components
	match id:
		"thaw_intake":
			sample.state = parts["intake/water"].phase
		"freeze_side":
			sample.state = parts["branches/side"].phase
			sample.amount = 0 if sample.state == "empty" else 1
		"thaw_lock":
			sample.state = "solid" if parts["correction/lock"].phase == "wrong" else "liquid"
		"refreeze_lock":
			sample.state = "liquid" if parts["correction/lock"].phase == "seated" else "solid"
			sample.amount = 1 if _state.items.bridge_lock == "installed:correction/socket" else 0
	return sample

func flags_for(id: String) -> Dictionary:
	return {"ready":not _state.is_empty() and _state.canal_step == TRANSITIONS[id]}

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store, world)
	if outcome.is_empty() or _state.canal_step != TRANSITIONS.get(outcome.id, -1):
		return false
	var next := _state.duplicate(true)
	_apply_step(next, next.canal_step + 1)
	var events := _events([{"id":"six_changes", "event":"observe-" + outcome.process, "members":[outcome.process]}], outcome.id)
	var prior: Dictionary = store.data.active_run.state.get("device_outcomes",{})
	if outcome.id == "refreeze_lock" and prior.get("thaw_lock",{}).get("process") == "melting":
		events.append_array(_events([{"id":"back_and_forth","members":[]}],"bridge_lock"))
	if store.commit_device_outcome(target, snapshot(next), world, [], events):
		return true
	_failed()
	return false

func _near(at: Vector2) -> bool:
	if world.player.position.distance_to(at) > 42 or not world.world_contact_allowed(world.player.position, at):
		return false
	var query := PhysicsRayQueryParameters2D.create(world.player.position, at, 1 | 2 | 8, [world.player.get_rid()])
	query.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func action_allowed(id: String) -> bool:
	if id == "exit":
		return _can_write() and _completion_ready(_state)
	return not _state.is_empty() and _state.canal_step == ACTIONS.get(id, -1) and super.action_allowed(id) and _near(component(contract.actions[id].component).position)

func world_context() -> Dictionary:
	if action_allowed("exit"):
		return {"key":REGION + ":exit", "caption":"Leave Two-State Canal", "target":exit_marker, "enabled":true,
			"allowed":Callable(self, "action_allowed").bind("exit"), "invoke":Callable(self, "commit_action").bind("exit")}
	return super.world_context()

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	if id == "exit":
		if finish():
			return true
		_failed()
		return false
	world.input_adapter.stop_all("canal_action", true)
	if not action_allowed(id):
		return false
	var next := _state.duplicate(true)
	_apply_step(next, next.canal_step + 1)
	var successes: Array = []
	if id == "drive":
		successes.append({"puzzle":"liquid_main_frozen_side", "type":"phase_branch_isolation", "topic":"freezing", "object":"canal_branches"})
	elif id == "latch":
		successes.append({"puzzle":"corrected_bridge_lock", "type":"melt_freeze_sequence", "topic":"freezing", "object":"bridge_lock"})
	if store.update_run_with_events(snapshot(next), successes, [], world):
		return true
	_failed()
	return false

func _completion_ready(state: Dictionary) -> bool:
	return state.get("canal_step") == Step.RELEASED and world.player.jump_elapsed < 0 and not world.player.carrying and _near(points.exit)

func _failed() -> void:
	last_error = store.last_error
	world.input_adapter.feedback = "Save failed. Retry to commit canal progress."
	_retry = 1.0

func _process(delta: float) -> void:
	if _retry > 0:
		_retry = maxf(0.0, _retry - delta)
	if _recovering and _retry == 0:
		_recover_checkpoint()
	if not _can_write():
		return
	if _retry == 0:
		for target in targets.values():
			if not target.is_committed() and not target.verified_outcome(store, world).is_empty():
				commit_target(target)
				break
	if _state.canal_step >= Step.ISOLATED:
		_animate_wheel()

func _animate_wheel() -> void:
	var frame := int(Time.get_ticks_msec() / 220.0) % 2
	if frame == _wheel_frame:
		return
	_wheel_frame = frame
	var sprite: Sprite2D = component("wheel_channel/wheel").visuals.get_node("Artwork")
	sprite.texture = load(PARTS.visual("canal_wheel_turn_a" if frame == 0 else "canal_wheel_turn_b").path)

func present() -> void:
	if _state.is_empty():
		return
	super.present()
	_wheel_frame = -1
	var step: int = _state.canal_step
	_present_spans(step)
	if _labels.is_empty():
		return
	_labels["intake/water"].text = "BLOCKED" if step == Step.BLOCKED else "THAWED"
	_labels["wheel_channel/main"].text = "MAIN · FLOWING" if step >= Step.ISOLATED else "MAIN · STOPPED"
	_labels["branches/side"].text = ["SIDE · EMPTY", "SIDE · CONNECTED", "SIDE · ISOLATED", "SIDE · FROZEN"][clampi(step - Step.THAWED, 0, 3)]
	_labels["correction/lock"].text = ["LOCK · MISALIGNED", "LOCK · THAWED", "", "LOCK · SEATED", "LOCK · REFROZEN", "LOCK · LATCHED"][clampi(step - Step.DRIVE_ENGAGED, 0, 5)]
	chunk.quests = [
		{"text":"Thaw intake and divert water", "state":"done" if step >= Step.DIVERTED else "active"},
		{"text":"Isolate side channel, freeze and cross to drive", "state":"done" if step >= Step.DRIVE_ENGAGED else "active"},
		{"text":"Correct bridge lock and release exit", "state":"done" if step == Step.RELEASED else "active"},
	]
	chunk.tutorial = [
		"Thermal · thaw blocked intake.", "Operate intake diverter.", "Close side divider to restore main flow.",
		"Cryo · freeze isolated side water.", "Cross frozen side channel. Engage wheel drive.",
		"Thermal · thaw misaligned bridge lock.", "Pick up freed lock.", "Carry lock to support socket.",
		"Cryo · refreeze seated lock.", "Secure crossing with mechanical latch.",
		"Walk across secured bridge. Release canal exit.", "Return to marked canal exit.",
	][step]

func _present_spans(step: int) -> void:
	if not is_instance_valid(crossings) or not crossings.spans.has("bridge"):
		return
	var side_color := CROSSINGS.OPEN_WATER
	if step < Step.DIVERTED:
		side_color = Color("526267")
	elif step == Step.ISOLATED:
		side_color = CROSSINGS.ISOLATED_WATER
	elif step >= Step.SIDE_FROZEN:
		side_color = CROSSINGS.SOLID
	crossings.present("side", step >= Step.SIDE_FROZEN, side_color)
	crossings.present("bridge", step >= Step.LATCHED, CROSSINGS.SOLID if step >= Step.LATCHED else CROSSINGS.OPEN_WATER)

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var attempt: Dictionary = store.world_record().get("attempts", {}).get(REGION, {}).get("attempt", {})
	var saved: Variant = attempt.get("state", {}).get(STATE_KEY, {})
	# Restore support before shared Continue validates a grounded location.
	var step: int = saved.canal_step if _supported_state(saved) else Step.BLOCKED
	_present_spans(step)

func world_checkpoints() -> Array:
	var records: Array = []
	for id in CHECKPOINTS:
		records.append({"id":id, "name":id, "position":world.checkpoint_anchor(REGION, id),
			"attuned":_travel_allowed(id), "allowed":Callable(self, "_travel_allowed").bind(id)})
	return records

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION, world.checkpoint_anchor(REGION, id))

func recover_world_fall() -> bool:
	if not active() or _state.is_empty():
		return false
	world.input_adapter.stop_all("canal_fall", true)
	world.dead = true
	_recovering = true
	_recover_checkpoint()
	return true

func _recover_checkpoint() -> void:
	if world.recover_world_checkpoint(world.access):
		_recovering = false
	else:
		world.dead = true
		_retry = 1.0

func _exit_tree() -> void:
	for art in _reservation_art:
		if is_instance_valid(art):
			art.show()
	if is_instance_valid(exit_marker):
		exit_marker.queue_free()
	super._exit_tree()
