extends RefCounted
## Durable device vocabulary and conservative evidence migration. No runtime controls.
const VERSION := 1
const WORLD_INTRO=preload("res://Scripts/World/Learning/world_intro_evidence.gd")
const SAVE_KEY := "phase_device"
const MODE_THERMAL := "thermal"
const MODE_CRYO := "cryo"
const MODE_VACUUM := "vacuum"
const MODE_PRESSURE := "pressure"
const MODES := [MODE_THERMAL, MODE_CRYO, MODE_VACUUM, MODE_PRESSURE]
# Vaporization includes evaporation and boiling. Plasma is deliberately absent.
const MILESTONES := {
	"z1l1_melting":{"zone":"melting_and_freezing", "level":1, "lesson":"melting", "mode":MODE_THERMAL, "capability":"melting"},
	"z1l3_freezing":{"zone":"melting_and_freezing", "level":3, "lesson":"freezing", "mode":MODE_CRYO, "capability":"freezing"},
	"z2l1_vaporization":{"zone":"vaporization_and_condensation", "level":1, "lesson":"vaporization", "mode":MODE_THERMAL, "capability":"vaporization"},
	"z2l3_condensation":{"zone":"vaporization_and_condensation", "level":3, "lesson":"condensation", "mode":MODE_CRYO, "capability":"condensation"},
	"z3l1_sublimation":{"zone":"sublimation_and_deposition", "level":1, "lesson":"sublimation", "mode":MODE_VACUUM, "capability":"sublimation"},
	"z3l3_deposition":{"zone":"sublimation_and_deposition", "level":3, "lesson":"deposition", "mode":MODE_PRESSURE, "capability":"deposition"}
}

static func defaults() -> Dictionary:
	return {"version":VERSION, "unlocked_modes":{}, "learned_capabilities":{}, "selected_mode":""}

static func supports_record(value: Variant) -> bool:
	# An absent/unversioned record is legacy. Preserve unknown versioned records.
	return not value is Dictionary or not value.has("version") or (value.version is int and value.version == VERSION)

static func normalize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary or not supports_record(value): return result
	var modes: Variant = value.get("unlocked_modes", {})
	if modes is Dictionary:
		for mode: String in MODES:
			if modes.get(mode, false) == true:
				result.unlocked_modes[mode] = true
	var capabilities: Variant = value.get("learned_capabilities", {})
	if capabilities is Dictionary:
		for milestone: Dictionary in MILESTONES.values():
			if result.unlocked_modes.has(milestone.mode) and capabilities.get(milestone.capability, false) == true:
				result.learned_capabilities[milestone.capability] = true
	var selected: Variant = value.get("selected_mode", "")
	if selected is String and result.unlocked_modes.has(selected):
		result.selected_mode = selected
	return _validate_selection(result)

static func has_lesson(profile: Dictionary, milestone: Dictionary) -> bool:
	var extras: Dictionary = profile.get("extras", {})
	var lessons: Variant = extras.get("lessons_seen", {})
	var id := "%s:%d:%s" % [milestone.zone, milestone.level, milestone.lesson]
	if lessons is Dictionary and lessons.get(id, false) == true: return true
	return milestone.capability == "melting" and extras.get("melting_gardens_welcome_seen", false) == true

static func has_success(profile: Dictionary, id: String, registry) -> bool:
	if not MILESTONES.has(id): return false
	var milestone: Dictionary = MILESTONES[id]
	var completed: Dictionary = profile.get("completed", {})
	if completed.get("%s:%d" % [milestone.zone, milestone.level], false) == true: return true
	if WORLD_INTRO.verified(profile,id,milestone):return true
	# Only authored introductory successes qualify. Guide discovery, explanation
	# acknowledgement, active-run level numbers and later practice never qualify.
	var definition: Dictionary = registry.definition(milestone.zone, milestone.level)
	var contracts: Dictionary = definition.get("device_milestone_successes", {})
	var required: Dictionary = contracts.get(id, {})
	var solved: Variant = profile.get("extras", {}).get("solved_puzzle_ids", {})
	if required.is_empty() or not solved is Dictionary: return false
	for puzzle: String in required:
		var key := "%s:%d:%s" % [milestone.zone, milestone.level, puzzle]
		if solved.get(key) != required[puzzle]: return false
	return true

static func state_for_profile(profile: Dictionary, registry) -> Dictionary:
	var raw: Variant = profile.get("extras", {}).get(SAVE_KEY)
	var result := normalize(raw)
	if not supports_record(raw): return result
	for id: String in MILESTONES:
		var milestone: Dictionary = MILESTONES[id]
		var learned := has_success(profile, id, registry)
		if learned or has_lesson(profile, milestone):
			result.unlocked_modes[milestone.mode] = true
		if learned:
			result.learned_capabilities[milestone.capability] = true
	return _validate_selection(result)

static func _validate_selection(state: Dictionary) -> Dictionary:
	if not state.unlocked_modes.has(state.selected_mode):
		state.selected_mode = MODE_THERMAL if state.unlocked_modes.has(MODE_THERMAL) else ""
	return state
