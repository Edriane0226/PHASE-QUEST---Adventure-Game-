extends RefCounted
## Only committed L1 actions enter this adapter. Loading snapshots never creates
## events. The level commits this evidence with its gameplay snapshot.
var level
var attempt_id := ""
var history_known := false
var deaths := 0
var low_warmth := false
var pending_respawn := false
var held_parts: Dictionary = {}
var delivered_parts: Dictionary = {}
var puzzles: Dictionary = {}
var crystals: Dictionary = {}
var pending: Array[Dictionary] = []
var help_puzzle := ""

func bind(owner_level) -> void:
	level = owner_level
	var run: Dictionary = level.get_node("/root/PlayerSave").data.active_run
	attempt_id = str(run.get("attempt_id", ""))
	history_known = run.get("achievement_history_known", false) == true and run.get("state", {}).is_empty()

func eligible() -> bool:
	var store = level.get_node("/root/PlayerSave")
	return not level.demonstration_mode and level.persistent_session and store.session_active and level == level.get_tree().current_scene and not attempt_id.is_empty() and store.data.active_run.get("attempt_id", "") == attempt_id

func snapshot() -> Dictionary:
	return {"version":1, "attempt_id":attempt_id, "history_known":history_known,
		"deaths":deaths, "low_warmth":low_warmth, "pending_respawn":pending_respawn,
		"held_parts":held_parts.duplicate(), "delivered_parts":delivered_parts.duplicate(),
		"puzzles":puzzles.duplicate(), "crystals":crystals.duplicate()}

func restore(value: Variant) -> void:
	help_puzzle = ""
	if not value is Dictionary or value.get("version") != 1 or value.get("attempt_id") != attempt_id:
		history_known = false
		deaths = 0
		low_warmth = false
		pending_respawn = false
		held_parts.clear()
		delivered_parts.clear()
		puzzles.clear()
		crystals.clear()
		return
	var count: Variant = value.get("deaths")
	history_known = value.get("history_known", false) == true and count is int and count >= 0
	deaths = count if count is int and count >= 0 else 0
	low_warmth = value.get("low_warmth", false) == true
	pending_respawn = value.get("pending_respawn", false) == true
	for field in ["held_parts","delivered_parts","puzzles","crystals"]:
		var entries: Variant = value.get(field, {})
		var clean := {}
		if entries is Dictionary:
			for key: Variant in entries:
				if key is String and entries[key] == true: clean[key] = true
		set(field,clean)

func _queue(id: String, event: String, members: Array = [], guide: Dictionary = {}) -> void:
	if not eligible(): return
	var entry := {"id":id, "event":attempt_id + ":" + event, "members":members}
	if not guide.is_empty(): entry.guide = guide
	if not pending.any(func(existing): return existing.id == entry.id and existing.event == entry.event):
		pending.append(entry)

func picked(part: String) -> void:
	if eligible(): held_parts[part] = true

func delivered(part: String, destination: String) -> void:
	if not eligible() or not held_parts.get(part,false): return
	if {"module":"heater_dock","wood":"brazier1","blades":"vent"}.get(part,"") != destination: return
	held_parts.erase(part)
	delivered_parts[part] = true
	_queue("hands_on","delivery:" + part)

func puzzle_solved(index: int) -> void:
	if not eligible() or not level.manual_puzzle_actions[index] or level.melted[index] < 1.0: return
	if index == 0:
		if level.has_method("device_first_task"):
			if not level.device_first_task(): return
		elif level.module_state != "docked" or not level.lit[0]: return
	if index == 1 and (not level.has_wood or not level.fan_installed or not level.lit[1]): return
	if index == 2 and (not level.receiver_lit or not level.lit[2]): return
	var puzzle := "puzzle%d" % index
	puzzles[puzzle] = true
	_queue(["first_thaw","helping_breeze","follow_light"][index],puzzle)
	_queue("six_changes","observe-melting",["melting"])
	lesson_observed()

func lesson_observed() -> void:
	_queue("field_notes","lesson-melting",["melting"],{"topic":"melting","object":"lesson_melting"})

func crystal_collected(index: int) -> void:
	if not eligible() or not level.collected.has(index): return
	crystals["crystal%d" % index] = true
	_queue("pocket_scientist","crystal%d" % index,["melting_and_freezing:1:crystal%d" % index])

func waypoint_unlocked(index: int) -> void:
	if index > 0 and index < level.WAYPOINTS.size():
		_queue("trail_mapper","waypoint%d" % index,["melting_and_freezing:1:waypoint%d" % index])

func warmth_changed(previous: float, current: float, shelter: bool, delta: float) -> bool:
	if not eligible() or level.dead or level.get_tree().paused or delta <= 0: return false
	if not shelter and current < previous and current > 0 and current <= 25 and not low_warmth:
		low_warmth = true
		return true
	if shelter and low_warmth and previous < 90 and current >= 90:
		low_warmth = false
		_queue("back_to_fire","warm-life%d" % deaths)
		return true
	return false

func cold_death() -> void:
	if not eligible() or pending_respawn: return
	deaths += 1
	low_warmth = false
	pending_respawn = true
	_queue("chilled_to_death","cold-death%d" % deaths)

func fall_death() -> void:
	if not eligible() or pending_respawn: return
	deaths += 1
	low_warmth = false
	pending_respawn = true

func teleported() -> void:
	low_warmth = false

func recovered(was_dead: bool, restoring_save: bool) -> void:
	if was_dead and pending_respawn and eligible():
		var target: String = level.checkpoint_progress.get("latest_unlocked_checkpoint_id","C0")
		if target != "C0" and level.player.position.distance_to(level._respawn_position()) < 1.0 and level.player.is_physics_processing() and level.player_controls_allowed():
			_queue("safe_return","respawn%d" % deaths)
	if was_dead or pending_respawn or not restoring_save: low_warmth = false
	if not was_dead and not restoring_save: history_known = false
	pending_respawn = false

func help_shown() -> void:
	help_puzzle = ""
	if not eligible(): return
	for i in range(3):
		if level.melted[i] < 1.0:
			help_puzzle = "puzzle%d" % i
			break

func help_acknowledged() -> void:
	if help_puzzle.is_empty() or not eligible(): return
	var index := int(help_puzzle.trim_prefix("puzzle"))
	if level.melted[index] < 1.0: _queue("good_question","help:" + help_puzzle)
	help_puzzle = ""

func completion_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not eligible() or not level._remaining_objectives().is_empty(): return result
	if puzzles.size() != 3 or crystals.size() != 6: return result
	var required := ["wood", "blades"] if level.has_method("device_first_task") else ["module", "wood", "blades"]
	for part: String in required:
		if not delivered_parts.get(part, false): return result
	result.append({"id":"phase_explorer", "event":attempt_id + ":completion",
		"members":["melting_and_freezing:1"]})
	if history_known and deaths == 0:
		result.append({"id":"steady_explorer", "event":attempt_id + ":deathless", "members":[]})
	return result
