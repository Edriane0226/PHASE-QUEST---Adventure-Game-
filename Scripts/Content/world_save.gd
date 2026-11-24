extends RefCounted
## Additive world envelope. Legacy originals remain available to the campaign providers.
## No scene, position, discovery cell or checkpoint is proof of earned progress.
const KEY := "world_state"
const CAMPAIGN_LAYOUT_VERSION := 1
const REGISTRY = preload("res://Scripts/Content/world_subregions.gd")
const LEGACY_GARDEN_MILL_SCENES := {
	"res://Zone_1/Levels/wrld_lvl_1.tscn": 1,
	"res://Zone_1/Levels/wrld_lvl_2.tscn": 2
}

static func version_one(value: Variant) -> bool:
	return (value is int or value is float) and value == 1

static func truth(value: Variant) -> bool:
	return value is bool and value

static func supported(value: Variant) -> bool:
	if value == null: return true
	if not value is Dictionary or not version_one(value.get("version")): return false
	if value.has("campaign_layout_version") and not version_one(value.campaign_layout_version):return false
	for key in ["attempts", "discovery", "location"]:
		if value.has(key) and not value[key] is Dictionary: return false
		if value.has(key) and key != "attempts" and value[key].has("version") and not version_one(value[key].version): return false
	if value.has("attempts"):
		for id in value.attempts:
			if REGISTRY.definition(str(id)).is_empty(): continue
			var record: Variant = value.attempts[id]
			if not record is Dictionary: return false
			var cp: Variant = record.get("checkpoint_progress", {})
			if not cp is Dictionary or not version_one(cp.get("version", 1)): return false
	return true

static func resolve_legacy_scene(run: Dictionary) -> bool:
	if not run.has("scene_path"):return true
	var zone := "melting_and_freezing"
	var level: int = LEGACY_GARDEN_MILL_SCENES.get(run.scene_path,0)
	if level == 0 or run.get("zone",zone) != zone or run.get("level",level) != level:return false
	run.zone = zone
	run.level = level
	return true

static func supported_campaign_profile(profile: Dictionary) -> bool:
	var world: Variant = profile.extras.get(KEY)
	if not supported(world) or not resolve_legacy_scene(profile.active_run) or not supported_campaign_run(profile.active_run):
		return false
	if world == null:return true
	for id in world.get("attempts",{}):
		if REGISTRY.definition(str(id)).is_empty():continue
		var record: Dictionary = world.attempts[id]
		if not record.has("attempt"):continue
		var run: Variant = record.attempt
		if not run is Dictionary or not resolve_legacy_scene(run) or region_for_run(run) != id or not supported_campaign_run(run):return false
	return true

static func supported_campaign_run(run: Dictionary) -> bool:
	var state: Variant = run.get("state",{})
	if not state is Dictionary:return false
	var checkpoint: Variant = state.get("checkpoint_progress",{})
	if not checkpoint is Dictionary or not version_one(checkpoint.get("version",1)):return false
	if state.has("modular_puzzles"):
		var adapter: Variant = state.modular_puzzles
		if not adapter is Dictionary or not version_one(adapter.get("version")) or adapter.get("subregion") != region_for_run(run):return false
	match region_for_run(run):
		"Z1L1":
			var garden: Variant = state.get("current",state.get("checkpoint",{}))
			return version_one(state.get("garden_thermal_world",1)) and garden is Dictionary and version_one(garden.get("device_retrofit_version",1)) and garden.get("expedition_version",2) in [1,2]
		"Z1L2":
			return version_one(state.get("mill_thermal_world",1)) and version_one(state.get("workshop_version",1)) and state.get("route_version",2) in [0,1,2]
	return true

static func region_for_run(run: Dictionary) -> String:
	if not run.get("zone") is String or not (run.get("level") is int or run.get("level") is float): return ""
	for row in REGISTRY.definitions():
		if row.zone_id == run.get("zone") and row.level == run.get("level"):
			return row.id
	return ""

static func point(value: Variant) -> Vector2:
	if value is Vector2 and value.is_finite(): return value
	return Vector2(INF, INF)

static func anchor(id: String, checkpoint: String) -> Vector2:
	var row := REGISTRY.definition(id)
	if row.is_empty(): return Vector2(INF, INF)
	var xy: Array = row.checkpoint_anchors.get(checkpoint, row.checkpoint_anchors.C0)
	return Vector2(xy[0], xy[1])

static func checkpoint_progress(id: String, state: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var row := REGISTRY.definition(id)
	if row.is_empty(): return {}
	var ids: Array = row.checkpoint_anchors.keys()
	var sequence: Array = ["C0"]
	var context: String = row.completion_key
	var value: Variant = state.get("checkpoint_progress", {})
	var legacy: Array = []
	if not state.get("checkpoint_context", context) is String or state.get("checkpoint_context", context) != context:
		value = {}
	elif id == "Z1L1":
		var current: Variant = state.get("current", {})
		if current is Dictionary:
			var melted: Variant = current.get("melted", [])
			var waypoints: Variant = current.get("waypoints", [])
			for i in range(3):
				if melted is Array and melted.size() > i and (melted[i] is float or melted[i] is int) and melted[i] >= 1.0:
					legacy.append("C%d" % (i + 1))
				elif i < 2 and waypoints is Array and waypoints.size() > i + 1 and truth(waypoints[i + 1]):
					legacy.append("C%d" % (i + 1))
	elif id == "Z1L2":
		if truth(state.get("clear")): legacy.append("C1")
		if truth(state.get("clear")) and truth(state.get("gear_thawed")) and truth(state.get("latch_thawed")): legacy.append("C2")
	# Existing order wins. Revisits/snapshots may add first unlocks, never reorder.
	for source in [previous.get("unlock_sequence", []), value.get("unlock_sequence", []) if value is Dictionary else [], legacy if not (value is Dictionary and value.get("unlock_sequence") is Array) else []]:
		if source is Array:
			for cp in source:
				if cp is String and ids.has(cp) and not sequence.has(cp): sequence.append(cp)
	var result: Dictionary = value.duplicate(true) if value is Dictionary else {}
	result.merge(previous, true)
	result.version = 1
	result.unlock_sequence = sequence
	result.latest_unlocked_checkpoint_id = sequence.back()
	return result

static func migrate(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	var extras: Dictionary = result.extras
	var raw: Variant = extras.get(KEY)
	if not supported(raw): return result
	var world: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	world.version = 1
	if not world.get("profile_id") is String or world.profile_id.length() != 32 or not world.profile_id.is_valid_hex_number(false):
		world.profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if not world.get("discovery") is Dictionary:
		world.discovery = {"version":1, "namespace":world.profile_id}
	if not world.get("attempts") is Dictionary: world.attempts = {}
	var run: Dictionary = result.active_run
	var id := region_for_run(run)
	if not id.is_empty() and run.get("state", {}) is Dictionary:
		var old: Variant = world.attempts.get(id, {})
		var record: Dictionary = old.duplicate(true) if old is Dictionary else {}
		# Explicit replay starts a new attempt; ordinary return retains its ID.
		var prior: Dictionary = record.get("attempt", {}) if record.get("attempt") is Dictionary else {}
		var same: bool = prior.get("attempt_id", "") is String and run.get("attempt_id", "") is String and prior.get("attempt_id", "") == run.get("attempt_id", "")
		record.checkpoint_progress = checkpoint_progress(id, run.get("state", {}), record.get("checkpoint_progress", {}) if same and record.get("checkpoint_progress") is Dictionary else {})
		record.attempt = run.duplicate(true)
		world.attempts[id] = record
		# Legacy scenes use local ground coordinates, never projected sprite Y.
		if not world.get("location") is Dictionary or not world.get("legacy_run") is Dictionary or world.get("legacy_run") != run:
			var row := REGISTRY.definition(id)
			var state: Dictionary = run.get("state", {})
			var current: Dictionary = state.get("current", {}) if state.get("current") is Dictionary else state
			var at := point(current.get("position"))
			var route: Variant = current.get("circular_route_version")
			var compatible: bool = id != "Z1L1" or ((route is int or route is float) and route == 2)
			var grounded: bool = at.is_finite() and compatible and not truth(state.get("death_pending")) and not truth(current.get("jumping"))
			var location: Dictionary = world.get("location", {}).duplicate(true)
			location.merge({"version":1, "subregion":id, "position":REGISTRY.local_to_ground(id, at) if grounded else anchor(id, record.checkpoint_progress.latest_unlocked_checkpoint_id), "grounded":true}, true)
			world.location = location
			world.active_zone = row.zone_id
			world.active_subregion = id
			world.legacy_run = run.duplicate(true)
	if not world.has("active_zone"): world.active_zone = ""
	if not world.has("active_subregion"): world.active_subregion = ""
	if not world.has("location"): world.location = {}
	extras[KEY] = world
	return result

static func recovery(world: Dictionary, policy: RefCounted, landing: Callable, mounted: Callable, anchor_for: Callable=Callable()) -> Dictionary:
	if not supported(world): return {}
	var location: Variant = world.get("location", {})
	var id: String = location.get("subregion", "") if location is Dictionary and location.get("subregion") is String else ""
	if REGISTRY.definition(id).is_empty(): id = str(world.get("active_subregion", ""))
	var candidates: Array = [id]
	for row in REGISTRY.definitions():
		if row.id != id: candidates.append(row.id)
	for candidate: String in candidates:
		if not policy.allowed(candidate) or not mounted.call(candidate): continue
		var positions: Array = []
		if candidate == id and location is Dictionary and version_one(location.get("version", 1)) and truth(location.get("grounded")):
			positions.append(point(location.get("position")))
		var attempts: Variant = world.get("attempts", {})
		var record: Variant = attempts.get(candidate, {}) if attempts is Dictionary else {}
		var progress: Dictionary = checkpoint_progress(candidate, {}, record.get("checkpoint_progress", {}) if record is Dictionary and record.get("checkpoint_progress") is Dictionary else {})
		var sequence: Array = progress.get("unlock_sequence", ["C0"]).duplicate()
		sequence.reverse()
		for cp: String in sequence:
			positions.append(anchor_for.call(candidate, cp) if anchor_for.is_valid() else anchor(candidate, cp))
		for at: Vector2 in positions:
			if at.is_finite() and policy.region_at(at) == candidate and landing.call(at):
				return {"subregion":candidate, "position":at}
	return {}
