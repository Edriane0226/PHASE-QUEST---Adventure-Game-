extends Node
## All durable player data lives here. Add future save fields under data["extras"].
signal changed
signal restored
const ZONES := ["melting_and_freezing","vaporization_and_condensation","sublimation_and_deposition"]
const LEVELS_PER_ZONE := 6
const STARS_PER_RANK := 6
const ACHIEVEMENTS = preload("res://Scripts/Autoload/achievement_registry.gd")
const LEVEL_REGISTRY = preload("res://Scripts/Content/level_registry.gd")
const WORLD_SOURCE = preload("res://Scripts/Content/world_source_authority.gd")
const WORLD_SAVE = preload("res://Scripts/Content/world_save.gd")
const MENU_CAMPAIGN = preload("res://Scripts/Content/menu_campaign.gd")
const DEVICE = preload("res://Scripts/Content/phase_device_progress.gd")
const DEVICE_TARGET = preload("res://Scripts/World/phase_device_target_2d.gd")
const STANDARD_SAVE := "user://phasequest_profile.save"
var save_path := STANDARD_SAVE
var data: Dictionary = {"version":1,"player_name":"","completed":{},"active_run":{},"extras":{}}
var resume_requested := false
var session_active := false
var requested_zone := ""
var last_error := ""
var read_only := false
var recovered_backup := false
var retained_document: Variant
var world_entry_request: Dictionary = {}
var last_new_game_archive := ""
var _loaded_path := ""
var _loaded_checksum := ""
var _disk_document: Dictionary = {}
var _campaign_rollback: Dictionary = {}
var _legacy_campaign_attempt := false

func campaign_staging_enabled() -> bool:
	return not OS.has_feature("phasequest_android_export") and OS.get_cmdline_user_args().has("--stage-campaign-garden")

func menu_world_scene() -> String:
	return WORLD_SAVE.REGISTRY.CAMPAIGN_SCENE

func menu_world_ready(id: String) -> bool:
	return WORLD_SAVE.REGISTRY.can_enter_campaign(self,id)

func menu_context() -> String:
	return "%s:%s:%s" % [save_path, data.hash(), read_only]

func menu_resume() -> Dictionary:
	return MENU_CAMPAIGN.resume(self)

func request_world_continue() -> String:
	var path := menu_world_scene()
	if not ResourceLoader.exists(path, "PackedScene"): return ""
	var resume := menu_resume()
	if resume.is_empty(): return ""
	world_entry_request = {"context":menu_context(),"subregion":resume.subregion,"continue_campaign":true}
	return path

func begin_campaign_continue(resume: Dictionary) -> void:
	_campaign_rollback = {"data":data.duplicate(true),"session":session_active,"resume":resume_requested}
	var id: String = resume.subregion
	var run: Dictionary = resume.attempt.duplicate(true)
	var world := world_record()
	_legacy_campaign_attempt = not world.has("campaign_layout_version") and id in ["Z1L1","Z1L2"] and not run.state.has("modular_puzzles")
	if not run.get("attempt_id") is String or run.get("attempt_id","").is_empty():
		run.attempt_id=Crypto.new().generate_random_bytes(16).hex_encode()
		run.achievement_history_known=false
	data.active_run=run
	data=WORLD_SAVE.migrate(data)
	if _legacy_campaign_attempt:
		# Old local coordinates never select an authored campaign landing.
		data.extras[WORLD_SAVE.KEY].location.grounded = false
	session_active=true
	resume_requested=true

func finish_campaign_continue(committed: bool) -> void:
	if not committed and not _campaign_rollback.is_empty():
		data = _campaign_rollback.data
		session_active = _campaign_rollback.session
		resume_requested = _campaign_rollback.resume
	_campaign_rollback.clear()
	_legacy_campaign_attempt = false

# Retained standalone controllers call these methods when launched for review.
# Only the authored campaign district can continue or complete a live attempt.
func next_world_region(_source) -> String:return ""

func request_next_world(_source) -> String:return ""

func start_new_world(player_name: String, expected_context: String) -> String:
	last_error = ""
	var path := menu_world_scene()
	if not ResourceLoader.exists(path, "PackedScene"):
		last_error = "The starting world could not be opened. Current adventure retained."
		return ""
	if read_only or expected_context != menu_context():
		last_error = "Adventure changed. Review it before starting again."
		return ""
	var clean := player_name.strip_edges().replace("\n", "").replace("\r", "").replace("\t", "").left(24)
	if clean.is_empty() or not menu_world_ready("Z1L1"):
		last_error = "Enter a name and ensure the starting world is available."
		return ""
	# Keep a durable, uniquely named whole-profile archive before replacement.
	var original: String = save_path + ".bak" if recovered_backup else save_path
	var archive := save_path + ".before-new-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".save"
	if FileAccess.file_exists(original) and DirAccess.copy_absolute(original, archive) != OK:
		last_error = "Cannot preserve the current adventure. New Game cancelled."
		return ""
	var previous := data.duplicate(true)
	data = {"version":1,"player_name":clean,"completed":{},"active_run":{"zone":ZONES[0],"level":1,"state":{},"attempt_id":Crypto.new().generate_random_bytes(16).hex_encode(),"achievement_history_known":true},"extras":{DEVICE.SAVE_KEY:DEVICE.defaults()}}
	if previous.extras.has("level1_reduced_effects"):data.extras.level1_reduced_effects=previous.extras.level1_reduced_effects
	if not save_profile():
		data = previous
		return ""
	last_new_game_archive = archive if FileAccess.file_exists(archive) else ""
	session_active = true
	resume_requested = false
	world_entry_request = {"context":menu_context(),"subregion":"Z1L1"}
	return path

func _init() -> void:
	data.extras[DEVICE.SAVE_KEY] = DEVICE.defaults()

func device_state() -> Dictionary:
	return DEVICE.state_for_profile(data, LEVEL_REGISTRY)

func is_device_mode_unlocked(mode: String) -> bool:
	return device_state().unlocked_modes.has(mode)

func has_device_capability(capability: String) -> bool:
	return device_state().learned_capabilities.has(capability)

func selected_device_mode() -> String:
	return device_state().selected_mode

func select_device_mode(mode: String) -> bool:
	last_error = ""
	var state := device_state()
	if not state.unlocked_modes.has(mode):
		last_error = "Device mode is locked or unknown."
		return false
	state.selected_mode = mode
	return _save_device_state(state)

# Generic introductions enable mode access; L1's guided melting grant is explicit.
func introduce_thermal_melting(source, guide_object := "") -> bool:
	if not _device_milestone_source("z1l1_melting", source): return false
	if not DEVICE.supports_record(data.extras.get(DEVICE.SAVE_KEY)):
		last_error = "Device save version is unsupported."
		return false
	if data.extras.get("thermal_introduction_version") == 1 and has_device_capability("melting"): return true
	var previous := data.duplicate(true)
	var state := device_state()
	state.unlocked_modes.thermal = true
	state.learned_capabilities.melting = true
	data.extras[DEVICE.SAVE_KEY] = DEVICE.normalize(state)
	var lessons: Dictionary = data.extras.get("lessons_seen", {}).duplicate(true)
	lessons[instance_id(ZONES[0], 1, "melting")] = true
	data.extras.lessons_seen = lessons
	data.extras.melting_gardens_welcome_seen = true
	data.extras.thermal_introduction_version = 1
	if not guide_object.is_empty():
		_stage_lesson_guide(ZONES[0],1,"melting",guide_object)
	if save_profile(): return true
	data = previous
	return false

func unlock_device_mode(milestone_id: String, source) -> bool:
	if not _device_milestone_source(milestone_id, source): return false
	var milestone: Dictionary = DEVICE.MILESTONES[milestone_id]
	if not DEVICE.has_lesson(data, milestone) and not DEVICE.has_success(data, milestone_id, LEVEL_REGISTRY):
		last_error = "Device mode requires its introductory lesson."
		return false
	var state := device_state()
	state.unlocked_modes[milestone.mode] = true
	return _save_device_state(DEVICE.normalize(state))

func grant_device_milestone(milestone_id: String, source) -> bool:
	if not _device_milestone_source(milestone_id, source): return false
	if not DEVICE.has_success(data, milestone_id, LEVEL_REGISTRY):
		last_error = "Device capability requires a verified introductory success."
		return false
	return _save_device_state(device_state())

func _device_milestone_source(milestone_id: String, source) -> bool:
	last_error = ""
	if not DEVICE.MILESTONES.has(milestone_id):
		last_error = "Unknown device milestone."
		return false
	var milestone: Dictionary = DEVICE.MILESTONES[milestone_id]
	if not campaign_source(source, milestone.zone, milestone.level):
		last_error = "Device unlock requires the registered introductory attempt."
		return false
	return true

func _save_device_state(state: Dictionary) -> bool:
	if not DEVICE.supports_record(data.extras.get(DEVICE.SAVE_KEY)):
		last_error = "Device save version is unsupported."
		return false
	if data.extras.get(DEVICE.SAVE_KEY) == state: return true
	var previous: Dictionary = data.extras
	data.extras = previous.duplicate(true)
	data.extras[DEVICE.SAVE_KEY] = state.duplicate(true)
	if save_profile(): return true
	data.extras = previous
	return false

func _stage_device_evidence() -> void:
	if DEVICE.supports_record(data.extras.get(DEVICE.SAVE_KEY)):
		var raw: Variant = data.extras.get(DEVICE.SAVE_KEY)
		var state := device_state()
		if raw is Dictionary:
			for key in raw:
				if not state.has(key): state[key] = raw[key]
			for key in ["unlocked_modes", "learned_capabilities"]:
				if raw.get(key) is Dictionary:
					for entry in raw[key]:
						if not state[key].has(entry): state[key][entry] = raw[key][entry]
		data.extras[DEVICE.SAVE_KEY] = state

func _with_device_outcomes(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var records: Variant = data.active_run.get("state", {}).get("device_outcomes")
	if not next.has("device_outcomes") and records is Dictionary:
		next.device_outcomes = records.duplicate(true)
	return next

func commit_device_outcome(target, state: Dictionary, source, successes: Array = [], events: Array = []) -> bool:
	last_error = ""
	if not is_instance_valid(target) or not target is DEVICE_TARGET:
		last_error = "Device outcome requires an authored target."
		return false
	var outcome: Dictionary = target.verified_outcome(self, source)
	if outcome.is_empty():
		last_error = "Device outcome has not been verified in this attempt."
		return false
	var spec: Dictionary = target.definition()
	var committed: Variant = data.active_run.get("state", {}).get("device_outcomes", {})
	if committed is Dictionary and committed.get(outcome.id) == outcome:
		target.acknowledge_commit(self, source)
		return true
	if committed is Dictionary and committed.has(outcome.id):
		last_error = "Device target ID already belongs to another outcome."
		return false
	var previous := data.duplicate(true)
	var next := state.duplicate(true)
	# Retain earlier receipts even when an older level snapshot omits this field.
	var records: Dictionary = committed.duplicate(true) if committed is Dictionary else {}
	records[outcome.id] = outcome.duplicate(true)
	next.device_outcomes = records
	var learning: Array = successes.duplicate(true)
	learning.append({"puzzle":"device:" + outcome.id, "type":outcome.puzzle_type, "topic":outcome.capability, "object":outcome.id})
	if not _stage_manual_successes(next, spec.zone, spec.level, learning):
		data = previous
		return false
	var evidence: Dictionary = data.extras.get("independent_phase_evidence", {}).duplicate(true) if data.extras.get("independent_phase_evidence") is Dictionary else {}
	var key := instance_id(spec.zone, spec.level, outcome.id)
	if not evidence.has(key): evidence[key] = outcome.duplicate(true)
	data.extras.phase_evidence_version = 1
	data.extras.independent_phase_evidence = evidence
	if source.has_method("world_intro_receipt"):
		var introduction: String=source.world_intro_receipt(target)
		if not introduction.is_empty():
			if not DEVICE.WORLD_INTRO.stage(data.extras,introduction,outcome.process,key):
				data=previous;last_error="Unsupported world introduction evidence retained.";return false
			_stage_device_evidence()
	if not events.is_empty():
		var context := _achievement_context(source)
		if context.is_empty() or source.achievement_events.attempt_id != data.active_run.get("attempt_id", "") or not _stage_achievement_events(events, context, source):
			data = previous
			return false
	if not save_profile():
		data = previous
		return false
	target.acknowledge_commit(self, source)
	return true

# The owning level supplies stable IDs and authored anchors. Save position is
# deliberately separate from the checkpoint selected for the next death.
func normalize_checkpoint_progress(value: Variant, valid_ids: Array, legacy_ids: Array = []) -> Dictionary:
	var sequence: Array = ["C0"]
	var source: Array = legacy_ids
	if value is Dictionary and value.get("unlock_sequence") is Array:
		source = value.unlock_sequence
	for id: Variant in source:
		if id is String and valid_ids.has(id) and not sequence.has(id):
			sequence.append(id)
	return {"version":1, "unlock_sequence":sequence, "latest_unlocked_checkpoint_id":sequence.back()}

func unlock_checkpoint(progress: Dictionary, id: String, valid_ids: Array) -> Dictionary:
	var result := normalize_checkpoint_progress(progress, valid_ids)
	if valid_ids.has(id) and not result.unlock_sequence.has(id):
		result.unlock_sequence.append(id)
		result.latest_unlocked_checkpoint_id = id
	return result

func instance_id(zone: String, number: int, object_id: String) -> String:
	return "%s:%d:%s" % [zone, number, object_id]

func guide_records() -> Dictionary:
	var result := {}
	var records: Variant = data.extras.get("guides_unlocked", {})
	if records is Dictionary:
		for id: Variant in records:
			var entry: Variant = records[id]
			if id is String and entry is Dictionary and entry.get("zone", "") in ZONES and entry.get("level", 0) is int and entry.level in range(1, 7) and entry.get("object") is String and entry.get("topic") is String:
				result[instance_id(entry.zone, entry.level, entry.object) + ":" + entry.topic] = entry.duplicate()
	# Old discoveries originated in Zone 1. They establish reference access only.
	var legacy: Variant = data.extras.get("discovered_guides", {})
	if legacy is Dictionary:
		for topic: Variant in legacy:
			var entry: Variant = legacy[topic]
			if topic is String and entry is Dictionary and entry.get("level", 0) is int and entry.level in range(1, 7) and entry.get("object") is String:
				var id: String = instance_id(ZONES[0], entry.level, entry.object) + ":" + topic
				if not result.has(id):
					result[id] = {"zone": ZONES[0], "level": entry.level, "object": entry.object, "topic": topic}
	return result

func discovered_guides() -> Dictionary:
	var result := {}
	for entry: Dictionary in guide_records().values():
		if not result.has(entry.topic) or entry.has("puzzle_type") or not result[entry.topic].has("puzzle_type"):
			result[entry.topic] = entry
	return result

func discover_guide(topic: String, number: int, object_id: String, zone := "melting_and_freezing") -> bool:
	if topic.is_empty() or zone not in ZONES or number<1 or number>6:
		last_error = "Invalid guide discovery."
		return false
	var entries := _stored_guides()
	var id: String = instance_id(zone, number, object_id) + ":" + topic
	if entries.has(id): return true
	entries[id] = {"zone":zone, "level":number, "object":object_id, "topic":topic}
	var extras: Dictionary = data.extras.duplicate(true)
	extras.guides_unlocked = entries
	return _save_learning(extras)

func _stored_guides() -> Dictionary:
	var raw: Variant = data.extras.get("guides_unlocked",{})
	var records: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	records.merge(guide_records(),true)
	return records

func _save_learning(extras: Dictionary) -> bool:
	if data.extras.get("learning_version",1) != 1:
		last_error = "Learning records require a newer version."
		return false
	extras.learning_version = 1
	var previous: Dictionary = data.extras
	data.extras = extras
	_stage_device_evidence()
	if save_profile(): return true
	data.extras = previous
	return false

func lesson_seen(zone: String, number: int, topic: String) -> bool:
	var records: Variant = data.extras.get("lessons_seen", {})
	return records is Dictionary and records.get(instance_id(zone, number, topic), false) == true

func jump_tutorial_seen() -> bool:
	return data.extras.get("low_obstacle_jump_seen", false) == true

func mark_jump_tutorial_seen() -> bool:
	if jump_tutorial_seen(): return true
	var extras: Dictionary = data.extras.duplicate(true)
	extras.low_obstacle_jump_seen = true
	return _save_learning(extras)

func mark_lesson_seen(zone: String, number: int, topic: String) -> bool:
	var extras: Dictionary = data.extras.duplicate(true)
	var records: Dictionary = extras.get("lessons_seen", {}).duplicate() if extras.get("lessons_seen") is Dictionary else {}
	records[instance_id(zone, number, topic)] = true
	extras.lessons_seen = records
	return _save_learning(extras)

func _stage_lesson_guide(zone: String, number: int, topic: String, object_id: String) -> void:
	var id := instance_id(zone,number,object_id) + ":" + topic
	var guides := _stored_guides()
	if not guides.has(id):
		guides[id] = {"zone":zone,"level":number,"topic":topic,"object":object_id}
	data.extras.guides_unlocked = guides
	if data.extras.get("achievement_version",1) == 1:
		var badges := achievement_state()
		if ACHIEVEMENTS.valid_member(ACHIEVEMENTS.definition("field_notes"),topic,level_key(zone,number)):
			_apply_achievement_progress(badges,level_key(zone,number),"field_notes","lesson:"+topic,[topic])
			_stage_achievement_state(badges)

func commit_world_lesson(zone: String, number: int, topic: String, object_id: String, source) -> bool:
	if not campaign_source(source,zone,number) or data.extras.get("learning_version",1) != 1:
		return false
	var id := instance_id(zone,number,object_id) + ":" + topic
	if lesson_seen(zone,number,topic) and guide_records().has(id): return true
	var previous := data.duplicate(true)
	var raw: Variant = data.extras.get("lessons_seen",{})
	var lessons: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	lessons[instance_id(zone,number,topic)] = true
	data.extras.lessons_seen = lessons
	_stage_lesson_guide(zone,number,topic,object_id)
	_stage_device_evidence()
	if save_profile(): return true
	data = previous
	return false

func pending_explanations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var queue: Variant = data.extras.get("pending_explanations", [])
	var explained: Variant = data.extras.get("explained_puzzle_types", {})
	if not queue is Array: return result
	var types: Array = []
	for entry: Variant in queue:
		if entry is Dictionary and entry.get("type") is String and entry.get("instance_id") is String and not types.has(entry.type):
			if explained is Dictionary and explained.get(entry.type, false) == true: continue
			types.append(entry.type)
			result.append(entry.duplicate())
	return result

func acknowledge_explanation(type_id: String) -> bool:
	var extras: Dictionary = data.extras.duplicate(true)
	var explained: Dictionary = extras.get("explained_puzzle_types", {}).duplicate() if extras.get("explained_puzzle_types") is Dictionary else {}
	if explained.get(type_id, false) == true: return true
	if not pending_explanations().any(func(entry): return entry.type == type_id):
		last_error = "No pending explanation to acknowledge."
		return false
	explained[type_id] = true
	extras.explained_puzzle_types = explained
	var queue: Array = extras.get("pending_explanations",[])
	extras.pending_explanations = queue.filter(func(entry): return not entry is Dictionary or entry.get("type") != type_id)
	return _save_learning(extras)

func update_run_with_successes(state: Dictionary, zone: String, number: int, successes: Array) -> bool:
	var previous := data.duplicate(true)
	if not _stage_manual_successes(state,zone,number,successes): return false
	if save_profile(): return true
	data = previous
	return false

func _stage_manual_successes(state: Dictionary, zone: String, number: int, successes: Array) -> bool:
	if not session_active or data.active_run.get("zone", "") != zone or data.active_run.get("level", 0) != number:
		last_error = "Puzzle does not belong to the current attempt."
		return false
	for success: Variant in successes:
		if not success is Dictionary or not success.get("type") is String or success.type.is_empty() or not success.get("puzzle") is String or success.puzzle.is_empty():
			last_error = "Invalid manual puzzle success."
			return false
	var extras: Dictionary = data.extras.duplicate(true)
	extras.learning_version = 1
	var raw_queue: Variant = extras.get("pending_explanations",[])
	var queue: Array = raw_queue.duplicate(true) if raw_queue is Array else []
	var guides := _stored_guides()
	var explained: Variant = extras.get("explained_puzzle_types", {})
	for success: Dictionary in successes:
		var type_id: String = success.type
		var id: String = instance_id(zone, number, success.puzzle)
		for field in ["solved_puzzle_ids", "independent_puzzle_ids"]:
			var records: Dictionary = extras.get(field, {}).duplicate() if extras.get(field) is Dictionary else {}
			records[id] = type_id
			extras[field] = records
		if success.get("topic") is String and success.get("object") is String:
			var guide_id: String = instance_id(zone, number, success.object) + ":" + success.topic
			guides[guide_id] = {"zone":zone, "level":number, "object":success.object, "topic":success.topic, "puzzle_type":type_id}
		var acknowledged: bool = explained is Dictionary and explained.get(type_id, false) == true
		if not acknowledged and not queue.any(func(entry): return entry is Dictionary and entry.get("type") == type_id and entry.get("instance_id") is String):
			queue.append({"type":type_id, "instance_id":id})
	extras.pending_explanations = queue
	extras.guides_unlocked = guides
	data.extras = extras
	data.active_run.state = _with_device_outcomes(state)
	_stage_device_evidence()
	return true

func update_run_with_events(state: Dictionary, successes: Array, events: Array, source) -> bool:
	var context := _achievement_context(source)
	if context.is_empty(): return false
	if source.achievement_events.attempt_id != data.active_run.get("attempt_id", ""):
		last_error = "Achievement attempt changed."
		return false
	var previous := data.duplicate(true)
	if not successes.is_empty():
		if not _stage_manual_successes(state, source.SAVE_ZONE, source.SAVE_LEVEL, successes): return false
	else:
		data.active_run.state = _with_device_outcomes(state)
	if not _stage_achievement_events(events,context,source):
		data = previous
		return false
	if save_profile(): return true
	data = previous
	return false

func _ready() -> void:
	if campaign_staging_enabled():save_path="user://campaign-staging-profile.save"
	load_profile()
	_install_achievement_toast.call_deferred()

func _install_achievement_toast() -> void:
	var toast = load("res://UI/HUD/AchievementToast.tscn").instantiate()
	add_child(toast)

func achievement_state() -> Dictionary:
	var result := {"unlocks":{}, "progress":{}, "toasts":[]}
	var unlocks: Variant = data.extras.get("achievement_unlocks", {})
	var progress: Variant = data.extras.get("achievement_progress", {})
	for item: Dictionary in ACHIEVEMENTS.DEFINITIONS:
		if unlocks is Dictionary:
			var stamp: Variant = unlocks.get(item.id, {}).get("timestamp", 0) if unlocks.get(item.id) is Dictionary else 0
			if stamp is int and stamp > 0:
				result.unlocks[item.id] = {"timestamp":stamp}
		var record: Variant = progress.get(item.id, {}) if progress is Dictionary else {}
		var clean := {"events":{}, "values":{}}
		if record is Dictionary:
			for field in ["events", "values"]:
				var entries: Variant = record.get(field, {})
				if entries is Dictionary:
					for key: Variant in entries:
						if key is String and not key.is_empty() and entries[key] == true:
							clean[field][key] = true
		result.progress[item.id] = clean
	var queue: Variant = data.extras.get("achievement_toasts", [])
	if queue is Array:
		for id: Variant in queue:
			if id is String and result.unlocks.has(id) and not result.toasts.has(id):
				result.toasts.append(id)
	return result

func achievement_count(id: String) -> int:
	var item: Dictionary = ACHIEVEMENTS.definition(id)
	if item.is_empty(): return 0
	return ACHIEVEMENTS.progress_count(item, achievement_state())

func record_achievement_progress(id: String, event_id: String, members: Array, source) -> bool:
	last_error = ""
	if data.extras.get("achievement_version",1) != 1: return false
	var context := _achievement_context(source)
	if context.is_empty(): return false
	var state := achievement_state()
	if not _apply_achievement_progress(state,context,id,event_id,members): return false
	return _save_achievement_state(state)

func campaign_source(source, zone: String, number: int) -> bool:
	return is_instance_valid(source) and source.scene_file_path == WORLD_SAVE.REGISTRY.CAMPAIGN_SCENE and WORLD_SOURCE.matches(source, zone, number, self)

func _achievement_context(source) -> String:
	if not is_instance_valid(source) or source != get_tree().current_scene or not session_active or source.get("demonstration_mode") != false:
		last_error = "Achievements require the active player attempt."
		return ""
	if not campaign_source(source, str(source.SAVE_ZONE), int(source.SAVE_LEVEL)): return ""
	var context := level_key(str(source.SAVE_ZONE), int(source.SAVE_LEVEL))
	if data.active_run.get("zone", "") != source.SAVE_ZONE or data.active_run.get("level", 0) != source.SAVE_LEVEL:
		last_error = "Achievement evidence belongs to another attempt."
		return ""
	return context

func _apply_achievement_progress(state: Dictionary, context: String, id: String, event_id: String, members: Array) -> bool:
	var item: Dictionary = ACHIEVEMENTS.definition(id)
	if item.is_empty() or event_id.is_empty() or item.get("mode", "count") == "derived":
		last_error = "Invalid achievement evidence."
		return false
	var mode: String = item.get("mode", "count")
	if (mode == "set" and members.is_empty()) or (mode != "set" and not members.is_empty()):
		last_error = "Invalid achievement progress."
		return false
	for member: Variant in members:
		if not member is String or not ACHIEVEMENTS.valid_member(item, member, context):
			last_error = "Invalid achievement progress member."
			return false
	if state.unlocks.has(id): return true
	var event_key := context + ":" + event_id
	if state.progress[id].events.has(event_key): return true
	state.progress[id].events[event_key] = true
	for member: String in members:
		state.progress[id].values[member] = true
	var field := "values" if mode == "set" else "events"
	if state.progress[id][field].size() >= ACHIEVEMENTS.target(item):
		_award_achievement(state, id)
	for derived: Dictionary in ACHIEVEMENTS.DEFINITIONS:
		if derived.get("mode", "") == "derived" and derived.members.all(func(member): return state.unlocks.has(member)):
			_award_achievement(state, derived.id)
	return true

func _stage_achievement_events(events: Array, context: String, source) -> bool:
	if events.is_empty(): return true
	if data.extras.get("achievement_version",1) != 1: return true
	var state := achievement_state()
	var guides := _stored_guides()
	for event: Variant in events:
		if not event is Dictionary or not event.get("id") is String or not event.get("event") is String or not event.get("members") is Array:
			last_error = "Invalid achievement event."
			return false
		if not _apply_achievement_progress(state,context,event.id,event.event,event.members): return false
		if event.get("guide") is Dictionary:
			var guide: Dictionary = event.guide
			if not guide.get("topic") is String or not guide.get("object") is String: return false
			var id: String = instance_id(source.SAVE_ZONE,source.SAVE_LEVEL,guide.object) + ":" + guide.topic
			guides[id] = {"zone":source.SAVE_ZONE, "level":source.SAVE_LEVEL,"object":guide.object,"topic":guide.topic}
	_stage_achievement_state(state)
	data.extras.guides_unlocked = guides
	return true

func _award_achievement(state: Dictionary, id: String) -> void:
	if state.unlocks.has(id): return
	state.unlocks[id] = {"timestamp":int(Time.get_unix_time_from_system())}
	state.toasts.append(id)

func _save_achievement_state(state: Dictionary) -> bool:
	var previous: Dictionary = data.extras
	_stage_achievement_state(state)
	if save_profile(): return true
	data.extras = previous
	return false

func _stage_achievement_state(state: Dictionary) -> void:
	var extras: Dictionary = data.extras.duplicate(true)
	extras.achievement_version = 1
	for field in ["unlocks","progress"]:
		var key: String = "achievement_" + field
		var raw: Variant = extras.get(key,{})
		var records: Dictionary = raw if raw is Dictionary else {}
		records.merge(state[field],true)
		extras[key] = records
	var raw_queue: Variant = extras.get("achievement_toasts",[])
	var queue: Array = raw_queue.filter(func(id): return not id is String or ACHIEVEMENTS.definition(id).is_empty()) if raw_queue is Array else []
	queue.append_array(state.toasts)
	extras.achievement_toasts = queue
	data.extras = extras

func acknowledge_achievement_toast(id: String) -> bool:
	last_error = ""
	if data.extras.get("achievement_version",1) != 1: return false
	var state := achievement_state()
	if not state.toasts.has(id): return true
	state.toasts.erase(id)
	return _save_achievement_state(state)

func load_profile() -> void:
	last_error = ""
	read_only = false
	recovered_backup = false
	retained_document = null
	_loaded_path = ""
	_loaded_checksum = ""
	_disk_document = {}
	var source := save_path
	if campaign_staging_enabled() and save_path != STANDARD_SAVE and not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".bak"):
		source = STANDARD_SAVE
	for path in [source,source+".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null:
			continue
		# store_var prefixes payload length. Reject truncated/non-profile bytes
		# before invoking Variant decoding; objects remain disabled below.
		if file.get_length() < 12:
			file.close()
			continue
		var length := file.get_32()
		var kind := file.get_32() & 0xffff
		if length != file.get_length() - 4 or kind != TYPE_DICTIONARY:
			file.close()
			continue
		file.seek(0)
		var loaded: Variant = file.get_var(false)
		file.close()
		if loaded is Dictionary and loaded.has("version") and not WORLD_SAVE.version_one(loaded.version):
			retained_document = loaded
			read_only = true
			last_error = "Unknown profile version retained; writing disabled."
			restored.emit()
			return
		if not loaded is Dictionary or not WORLD_SAVE.version_one(loaded.get("version")):
			continue
		if not loaded.get("player_name",null) is String or not loaded.get("completed",null) is Dictionary:
			continue
		if not loaded.get("extras", {}) is Dictionary or not loaded.get("active_run", {}) is Dictionary: continue
		_loaded_path = path
		_loaded_checksum = FileAccess.get_sha256(path)
		_disk_document = loaded.duplicate(true)
		# Retain unknown root/completion/extras keys and exact legacy item receipts.
		data = loaded.duplicate(true)
		data.active_run = loaded.get("active_run", {}).duplicate(true)
		data.extras = loaded.get("extras", {}).duplicate(true)
		if not WORLD_SAVE.supported_campaign_profile(data):
			retained_document = loaded
			read_only = true
			last_error = "Unsupported campaign record retained; writing disabled."
			restored.emit()
			return
		data = WORLD_SAVE.migrate(data)
		recovered_backup = path == source+".bak"
		_stage_device_evidence()
		_stage_completion_badge()
		restored.emit()
		return
	if FileAccess.file_exists(source) or FileAccess.file_exists(source + ".bak"):
		read_only = true
		last_error = "Invalid profile retained; writing disabled."
	else:
		data = WORLD_SAVE.migrate({"version":1,"player_name":"","completed":{},"active_run":{},"extras":{DEVICE.SAVE_KEY:DEVICE.defaults()}})
	restored.emit()

func _archive_campaign_source() -> bool:
	if _loaded_path.is_empty() or _loaded_checksum.is_empty() or FileAccess.get_sha256(_loaded_path) != _loaded_checksum:
		last_error = "Source save changed. Relaunch before migrating."
		return false
	var archive := save_path+".before-campaign-"+_loaded_checksum+".save"
	if FileAccess.file_exists(archive):
		if FileAccess.get_sha256(archive) == _loaded_checksum:return true
		last_error = "Migration backup does not match the source save."
		return false
	var pending := archive+".pending"
	if DirAccess.copy_absolute(_loaded_path,pending) != OK or FileAccess.get_sha256(pending) != _loaded_checksum or DirAccess.rename_absolute(pending,archive) != OK:
		last_error = "Could not verify a recovery copy. Save retained."
		return false
	return true

func save_profile() -> bool:
	last_error = ""
	if read_only:
		last_error = "Profile retained; writing disabled."
		return false
	var next := WORLD_SAVE.migrate(data)
	if _loaded_path == save_path and not recovered_backup and next == _disk_document and FileAccess.get_sha256(save_path) == _loaded_checksum:
		data = next
		return true
	if not _campaign_rollback.is_empty():
		if _loaded_path.is_empty() or FileAccess.get_sha256(_loaded_path) != _loaded_checksum:
			last_error = "Source save changed. Relaunch before continuing."
			return false
		var previous_world: Variant = _disk_document.get("extras",{}).get(WORLD_SAVE.KEY,{})
		if (_loaded_path != save_path or not previous_world is Dictionary or not previous_world.has("campaign_layout_version")) and not _archive_campaign_source():return false
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write save. Please try again."
		return false
	file.store_var(next)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Save could not finish. Please try again."
		return false
	var backup := ""
	if FileAccess.file_exists(save_path):
		backup = save_path + (".corrupt" if recovered_backup else ".bak")
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup)) or DirAccess.copy_absolute(save_path,backup) != OK:
			last_error = "Cannot back up save. Please try again."
			return false
		if DirAccess.remove_absolute(save_path) != OK:
			last_error = "Cannot replace save. Please try again."
			return false
	if _commit_save_file(save_path+".tmp",save_path) != OK:
		if not backup.is_empty():DirAccess.copy_absolute(backup,save_path)
		last_error = "Cannot commit save. Previous backup retained."
		return false
	data = next
	_loaded_path = save_path
	_loaded_checksum = FileAccess.get_sha256(save_path)
	_disk_document = next.duplicate(true)
	recovered_backup = false
	changed.emit()
	return true

func _commit_save_file(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)

func world_record() -> Dictionary:
	var value: Variant = data.extras.get(WORLD_SAVE.KEY)
	return value.duplicate(true) if value is Dictionary else {}

func world_discovery_namespace() -> String:
	if read_only or not WORLD_SAVE.supported(data.extras.get(WORLD_SAVE.KEY)): return ""
	data = WORLD_SAVE.migrate(data)
	var record := world_record()
	var discovery: Variant = record.get("discovery")
	if not discovery is Dictionary or discovery.get("version") != 1: return ""
	var identity: Variant = discovery.get("namespace")
	return identity if identity is String and identity.length() == 32 and identity.is_valid_hex_number(false) else ""

func active_world_zone() -> String:
	var world := world_record()
	if WORLD_SAVE.supported(world) and world.get("active_zone", "") in ZONES: return world.active_zone
	return str(data.active_run.get("zone", "")) if data.active_run.get("zone", "") in ZONES else ""

func world_navigation_source(source, id: String) -> bool:
	if not is_instance_valid(source) or source.scene_file_path != WORLD_SAVE.REGISTRY.CAMPAIGN_SCENE:return false
	return WORLD_SOURCE.navigation_matches(source, id, self)

func enter_world_subregion(source, id: String) -> bool:
	if not world_navigation_source(source, id) or read_only or not WORLD_SAVE.supported(data.extras.get(WORLD_SAVE.KEY)): return false
	var previous := data.duplicate(true)
	data = WORLD_SAVE.migrate(data)
	var world := world_record()
	var row := WORLD_SAVE.REGISTRY.definition(id)
	var record: Variant = world.attempts.get(id, {})
	if record is Dictionary and record.get("attempt") is Dictionary:
		if WORLD_SAVE.region_for_run(record.attempt) != id or not record.attempt.get("state", {}) is Dictionary:
			data = previous
			last_error = "Invalid archived attempt retained; restoration requires a valid attempt."
			return false
		data.active_run = record.attempt.duplicate(true)
	else:
		data.active_run = {"zone":row.zone_id,"level":int(row.level),"state":{},"attempt_id":Crypto.new().generate_random_bytes(16).hex_encode(),"achievement_history_known":true}
	if _legacy_campaign_attempt and not _campaign_rollback.is_empty():
		var provider: Node = source.learning_provider()
		var converted: Dictionary = provider.campaign_legacy_snapshot() if provider and provider.has_method("campaign_legacy_snapshot") else {}
		if converted.is_empty():
			data = previous
			last_error = "Legacy attempt could not be restored. Save retained."
			return false
		data.active_run.state = converted
	world.campaign_layout_version = WORLD_SAVE.CAMPAIGN_LAYOUT_VERSION
	world.active_zone = row.zone_id
	world.active_subregion = id
	var location: Dictionary = world.get("location", {}).duplicate(true)
	location.merge({"version":1,"subregion":id,"position":source.player.safe_save_position(),"grounded":true}, true)
	world.location = location
	world.legacy_run = data.active_run.duplicate(true)
	data.extras[WORLD_SAVE.KEY] = world
	if save_profile():
		session_active = true
		return true
	data = previous
	return false

func save_world_location(source) -> bool:
	var id: String = source.active_subregion_id if is_instance_valid(source) else ""
	if not world_navigation_source(source, id) or read_only or not WORLD_SAVE.supported(data.extras.get(WORLD_SAVE.KEY)): return false
	if WORLD_SAVE.region_for_run(data.active_run) != id: return enter_world_subregion(source, id)
	var at: Vector2 = source.player.safe_save_position()
	if not source.valid_landing(at): return false
	var previous := data.duplicate(true)
	data = WORLD_SAVE.migrate(data)
	var world := world_record()
	var row := WORLD_SAVE.REGISTRY.definition(id)
	world.active_zone = row.zone_id
	world.active_subregion = id
	var location: Dictionary = world.get("location", {}).duplicate(true)
	location.merge({"version":1,"subregion":id,"position":at,"grounded":true}, true)
	world.location = location
	data.extras[WORLD_SAVE.KEY] = world
	if save_profile(): return true
	data = previous
	return false

func has_player_name() -> bool:
	return not str(data["player_name"]).strip_edges().is_empty()

func has_seen_melting_intro() -> bool:
	return lesson_seen(ZONES[0], 1, "melting") or data.extras.get("melting_gardens_welcome_seen", false) == true

func mark_melting_intro_seen() -> bool:
	return mark_lesson_seen(ZONES[0], 1, "melting")

func set_player_name(value: String) -> bool:
	var clean := value.strip_edges().replace("\n","").replace("\r","").replace("\t","").left(24)
	if clean.is_empty():
		last_error = "Enter your name first."
		return false
	var previous: String = data["player_name"]
	data["player_name"] = clean
	if save_profile():
		return true
	data["player_name"] = previous
	return false

func level_key(zone: String, level: int) -> String:
	return "%s:%d" % [zone,level]

func is_level_complete(zone: String, level: int) -> bool:
	return WORLD_SAVE.truth(data["completed"].get(level_key(zone,level),false))

func is_zone_unlocked(zone: String) -> bool:
	var index := ZONES.find(zone)
	if index < 0:
		return false
	if index == 0:
		return true
	for level in range(1,LEVELS_PER_ZONE+1):
		if not is_level_complete(ZONES[index-1],level):
			return false
	return is_zone_unlocked(ZONES[index-1])

func is_level_unlocked(zone: String, level: int) -> bool:
	if level < 1 or level > LEVELS_PER_ZONE or not is_zone_unlocked(zone):
		return false
	for previous in range(1,level):
		if not is_level_complete(zone,previous):
			return false
	return true

func scene_for_level(zone: String, level: int) -> String:
	return LEVEL_REGISTRY.scene_for_level(zone,level)

func begin_level(_zone: String, _level: int) -> bool:return false

func update_run(state: Dictionary) -> bool:
	if not session_active or data["active_run"].is_empty() or not campaign_source(get_tree().current_scene, str(data.active_run.get("zone", "")), int(data.active_run.get("level", 0))):
		return false
	var previous: Dictionary = data["active_run"].get("state",{}).duplicate(true)
	data["active_run"]["state"] = _with_device_outcomes(state)
	if save_profile():
		return true
	data["active_run"]["state"] = previous
	return false

func has_unfinished_run() -> bool:
	return not menu_resume().is_empty()

func request_continue() -> String:return request_world_continue()

func finish_level(zone: String, level: int, events: Array = [], source = null) -> bool:
	if not is_level_unlocked(zone,level) or not campaign_source(source, zone, level):
		last_error = "Completion requires the registered active level."
		return false
	if source.has_method("world_completion_allowed") and not source.world_completion_allowed():
		last_error="World completion requires its authored active provider predicate."
		return false
	var previous := data.duplicate(true)
	if not events.is_empty():
		var context := _achievement_context(source)
		if context.is_empty() or not _stage_achievement_events(events,context,source):
			data = previous
			return false
	# Completion is a set: replaying a level never awards another star.
	data["completed"][level_key(zone,level)] = true
	_stage_completion_badge()
	_stage_device_evidence()
	var run: Dictionary = data["active_run"]
	# Archive final committed state before the legacy active wrapper is cleared.
	data = WORLD_SAVE.migrate(data)
	if run.get("zone","") == zone and int(run.get("level",0)) == level:
		data["active_run"] = {}
	if not save_profile():
		data = previous
		return false
	session_active = false
	resume_requested = false
	return true

func _stage_completion_badge() -> void:
	if data.extras.get("achievement_version",1) != 1: return
	var state := achievement_state()
	if state.unlocks.has("phase_explorer"): return
	var members: Array = []
	for row in WORLD_SAVE.REGISTRY.definitions():
		if is_level_complete(row.zone_id,row.level): members.append(row.completion_key)
	if members.is_empty(): return
	if _apply_achievement_progress(state,"campaign","phase_explorer","districts:"+str(members.size()),members):
		_stage_achievement_state(state)

func total_stars() -> int:
	var count := 0
	for zone: String in ZONES:
		for number in range(1, LEVELS_PER_ZONE + 1):
			if is_level_complete(zone, number): count += 1
	return count

func rank_name() -> String:
	var stars := total_stars()
	return "Apprentice" if stars<=6 else ("Researcher" if stars<=12 else "Phase Master")

func stars_to_next_rank() -> int:
	var stars := total_stars()
	return 7-stars if stars<=6 else (13-stars if stars<=12 else 0)
