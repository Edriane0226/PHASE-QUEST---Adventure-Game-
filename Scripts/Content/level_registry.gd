extends RefCounted
## Legacy puzzle and lesson metadata used for saved Garden and Mill attempts.
const LEVELS := {
	"melting_and_freezing:2": {
		"zone":"melting_and_freezing", "level":2,
		"title":"The Frozen Mill",
		"puzzle_ids":["resonance_bells","thaw_sort","counterweight_lift"],
		"puzzle_types":["ice_resonance","melt_direct","mill_counterweight"],
		"checkpoints":{"C0":"Checkpoints/C0/SafeSpawn","C1":"Checkpoints/C1/SafeSpawn","C2":"Checkpoints/C2/SafeSpawn"},
		"question_bank":1,
		"practice_question":{
			"text":"What changed when the heater warmed the frozen parts?",
			"choices":["Solid water becomes liquid water.","The heater created new water.","The wheel created water."],
			"correct":0,
			"feedback":"Ice gained heat and became liquid water. The metal parts remained solid."
		}
	},
	"melting_and_freezing:1": {
		"zone": "melting_and_freezing", "level": 1,
		"title": "The Melting Garden",
		"puzzle_ids": ["puzzle0", "puzzle1", "puzzle2"],
		"puzzle_types": ["melt_direct", "melt_fueled_airflow", "melt_solar_relay"],
		"device_milestone_successes": {"z1l1_melting":{"puzzle0":"melt_direct"}},
		"checkpoints": {"C0":"Spawn", "C1":"RouteCheckpoints/Checkpoint0",
			"C2":"RouteCheckpoints/Checkpoint1", "C3":"RouteCheckpoints/Checkpoint2"},
		"question_bank": 1,
		"practice_question": {
			"text":"Ice became liquid water. What changed?",
			"choices":["Its state changed.", "It became a new substance.", "The water disappeared."],
			"correct":0,
			"feedback":"Heat changed solid ice into liquid water. It is still water."
		}
	}
}
const QUESTIONS = preload("res://Scripts/Content/level_questions.gd")

static func definition(zone: String, number: int) -> Dictionary:
	var entry: Dictionary = LEVELS.get("%s:%d" % [zone, number], {})
	if entry.get("zone") != zone or entry.get("level") != number: return {}
	if not entry.get("puzzle_ids") is Array or not entry.get("puzzle_types") is Array: return {}
	if entry.puzzle_ids.is_empty() or entry.puzzle_ids.size() != entry.puzzle_types.size(): return {}
	if not entry.get("checkpoints") is Dictionary or not entry.checkpoints.has("C0"): return {}
	if not QUESTIONS.BANKS.has(entry.get("question_bank", -1)): return {}
	return entry.duplicate(true)

static func scene_for_level(_zone: String, _number: int) -> String:
	# CampaignWorld owns both districts. WorldSave resolves the original saved paths.
	return ""

static func questions(zone: String, number: int) -> Array:
	var entry := definition(zone, number)
	return QUESTIONS.BANKS.get(entry.get("question_bank", -1), []).duplicate(true)
