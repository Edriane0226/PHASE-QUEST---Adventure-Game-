extends SceneTree

const WORLD_SAVE = preload("res://Scripts/Content/world_save.gd")
const DEVICE = preload("res://Scripts/Content/phase_device_progress.gd")
const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
const DOCK = preload("res://Scripts/World/Zone1/frozen_dock_world.gd")
const ENGINE = preload("res://Scripts/World/Zone2/skybridge_engine_world.gd")
const CORE = preload("res://Scripts/World/Zone3/phaseworks_core_world.gd")
const MILESTONES := [
	["030", "restore.save", 6, "Z2L1", "check", 2, 2],
	["037", "fresh-z2l6.save", 12, "Z3L1", "fresh", 4, 2],
	["044", "fresh-z3l6.save", 18, "Z3L6", "fresh", 6, 4],
]

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", detail)

func read(path: String) -> Dictionary:
	var file := FileAccess.open("res://../../r3-prompt" + path, FileAccess.READ)
	if file == null:
		check(false, "missing passing binary " + path)
		return {}
	var value: Variant = file.get_var(false)
	if not value is Dictionary:
		check(false, "unreadable passing binary " + path)
		return {}
	return value

func attempt_content(record: Dictionary) -> Dictionary:
	var copy := record.duplicate(true)
	var state: Dictionary = copy.attempt.state
	state.erase("position")
	return copy

func discovery_cells(prompt: String, suite: String, identity: String) -> Dictionary:
	var path := "res://../../r3-prompt%s/local-user/%s/Godot/app_userdata/Phase Quest R3 %s isolated/world-discovery/%s.json"
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path % [prompt, suite, prompt, identity]))
	var cells := {}
	if document is Dictionary and document.get("cells") is Array:
		for cell in document.cells:
			cells[JSON.stringify(cell)] = true
	return cells

func run() -> void:
	var prior: Dictionary = {}
	var prior_cells: Dictionary = {}
	var districts := WORLD_SAVE.REGISTRY.definitions()
	for milestone in MILESTONES:
		var data := read(milestone[0] + "/fixtures/" + milestone[1])
		if data.is_empty(): break
		var world: Dictionary = data.extras[WORLD_SAVE.KEY]
		var count: int = milestone[2]
		var district: String = milestone[3]
		var zone: String = WORLD_SAVE.REGISTRY.definition(district).zone_id
		check(world.active_subregion == district and world.active_zone == zone
			and world.location.subregion == district and world.location.grounded
			and WORLD_SAVE.region_for_run(data.active_run) == district, "grounded arrival " + district)
		check(data.completed.size() == count, "exact completion count " + str(count))
		var device := DEVICE.normalize(data.extras.get(DEVICE.SAVE_KEY))
		check(device.learned_capabilities.size() == milestone[5] and device.unlocked_modes.size() == milestone[6],
			"only earned device capabilities and modes " + district)
		check(WORLD_SAVE.migrate(WORLD_SAVE.migrate(data)) == data, "binary migration stable " + district)
		var cells := discovery_cells(milestone[0], milestone[4], world.discovery.namespace)
		check(not cells.is_empty() and prior_cells.keys().all(func(cell): return cells.has(cell)),
			"discovery cells persist and extend into " + district)
		prior_cells = cells
		var ids := {}
		for index in districts.size():
			var row: Dictionary = districts[index]
			if index >= count:
				check(not data.completed.has(row.completion_key), "no early completion " + row.id)
				continue
			check(data.completed.get(row.completion_key) == true and world.attempts.has(row.id),
				"earned district and archived attempt " + row.id)
			var attempt_id: String = world.attempts[row.id].attempt.attempt_id
			check(not attempt_id.is_empty() and not ids.has(attempt_id), "one unique attempt ID " + row.id)
			ids[attempt_id] = true
		if not prior.is_empty():
			var old: Dictionary = prior.extras[WORLD_SAVE.KEY]
			check(world.profile_id == old.profile_id and world.discovery.namespace == old.discovery.namespace
				and data.player_name == prior.player_name, "same earned profile and discovery identity at " + district)
			for id in old.attempts:
				if not world.attempts.has(id):
					check(false, "missing earlier attempt " + id)
					continue
				var start: Dictionary = old.attempts[id]
				var end: Dictionary = world.attempts[id]
				check(start.attempt.attempt_id == end.attempt.attempt_id, "retained attempt at " + id)
				if id != old.active_subregion:
					check(attempt_content(start) == attempt_content(end), "retained work and ownership at " + id)
			for key in ["lessons_seen", "guides_unlocked", "independent_phase_evidence", "achievement_unlocks"]:
				var advances: Dictionary = data.extras.get(key, {})
				for id in prior.extras.get(key, {}):
					check(advances.get(id) == prior.extras[key][id], "retained " + key + " " + id)
		prior = data
	if prior.get("completed", {}).size() == 18:
		check_terminal(prior)
	print("LINEAGE048 %s · %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func check_terminal(data: Dictionary) -> void:
	var attempts: Dictionary = data.extras[WORLD_SAVE.KEY].attempts
	var observed := {}
	for id in attempts:
		var receipts: Dictionary = attempts[id].attempt.state.get("device_outcomes", {})
		for key in receipts:
			var receipt: Dictionary = receipts[key]
			var rule: Dictionary = RULES.PROCESSES.get(receipt.process, {})
			check(not rule.is_empty() and receipt.id == key and receipt.material == "water"
				and receipt.from_state == rule.from and receipt.to_state == rule.to, "native receipt " + id + "/" + key)
			observed[receipt.process] = true
	check(observed.size() == RULES.PROCESSES.size(), "all seven observed processes")
	for case in [
		["Z1L6", DOCK.PARTS.RECIPE, DOCK.QUESTIONS, "boatwright", "snow_scholar", func(_id): return DOCK.FITTED],
		["Z2L6", ENGINE.PARTS.RECIPE, ENGINE.PARTS.QUESTIONS, "steam_engineer", "sun_scholar", ENGINE.PARTS.fitted],
		["Z3L6", CORE.PARTS.RECIPE, CORE.PARTS.QUESTIONS, "frost_engineer", "lab_scholar", func(_id): return CORE.PARTS.FITTED],
	]:
		var district: String = case[0]
		var state: Dictionary = attempts[district].attempt.state.modular_puzzles
		var expected: Array = case[1].keys()
		check(state.items.size() == expected.size() and expected.all(func(id): return state.items.get(id) == case[5].call(id)),
			"each required craft item sits in its one installed slot " + district)
		check(DOCK.FINN.new(case[2]).passed(state.finn), "saved capstone Finn answers " + district)
		for award in case.slice(3, 5):
			var events: Dictionary = data.extras.achievement_progress[award].events
			check(data.extras.achievement_unlocks.has(award) and events.size() == 1, "one award event " + award)
