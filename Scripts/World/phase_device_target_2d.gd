extends Node2D
## Explicit opt-in target adapter. No art/input or automatic world mutation.
signal outcome_ready(outcome: Dictionary)
const EXPOSURE = preload("res://Scripts/World/phase_device_exposure.gd")
const DEVICE = preload("res://Scripts/Content/phase_device_progress.gd")
const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
const TARGET_GROUP := "phase_device_targets"
# Same solid/low-obstacle/barrier layers as the shared player's ground mask.
const BLOCKER_MASK := 1 | 2 | 8
var hit_collider: CollisionObject2D
var _simulation = EXPOSURE.new()
var _source: Node
var _store: Node
var _attempt_id := ""
var _committed := false
var _sample_provider: Callable
var _flags_provider: Callable
@export var cue_radius := 14.0
var _preview_only := false

func configure_preview(spec: Dictionary, source: Node) -> bool:
	# A disposable adapter never has a store, attempt, live group or commit path.
	# Refuse to convert an already bound live target into a demonstration.
	if _store != null or is_in_group(TARGET_GROUP) or not is_instance_valid(source) or source.get("demonstration_mode") != true: return false
	if not source.is_ancestor_of(self): return false
	if not _simulation.configure(spec): return false
	_source = source
	_preview_only = true
	_committed = false
	_attempt_id = ""
	return true

func apply_preview_exposure(delta: float, muzzle: Node2D, mode: String, device: Dictionary, sample: Dictionary, flags: Dictionary, firing: bool) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion(): return {"reason":"inactive_preview","new_outcome":false}
	if not _preview_only or _store != null or not is_instance_valid(_source) or _source.get("demonstration_mode") != true or not _source.is_ancestor_of(self): return {"reason":"not_preview","new_outcome":false}
	if get_tree().paused or _source.get("preview_paused") == true or not firing: return {"reason":"inactive_preview","new_outcome":false}
	var reason := geometry_reason(muzzle)
	if not reason.is_empty(): return {"reason":reason,"new_outcome":false}
	# Same pure rules/exposure kernel; deliberately never emit outcome_ready.
	return _simulation.advance(delta,mode,device,sample,flags)

func preview_outcome() -> Dictionary:
	return _simulation.outcome() if _preview_only and _store == null else {}

func configure(spec: Dictionary, source: Node, store: Node) -> bool:
	_preview_only = false
	_source = source
	_store = store
	_attempt_id = ""
	_committed = false
	if not _simulation.configure(spec): return false
	if not _live_source(): return false
	_attempt_id = str(_store.data.active_run.get("attempt_id", ""))
	if _attempt_id.is_empty(): return false
	var records: Variant = _store.data.active_run.get("state", {}).get("device_outcomes", {})
	if records is Dictionary:
		_committed = _simulation.restore_completed(records.get(spec.id))
	return true

func definition() -> Dictionary:
	return _simulation.definition()

func exposure() -> float:
	return _simulation.exposure()

func is_committed() -> bool:
	return _committed

func bind_live_context(sample_provider: Callable, flags_provider: Callable) -> bool:
	# Only explicitly configured targets participate in runtime aiming. Providers
	# read apparatus/sample state; presentation never supplies science conditions.
	_sample_provider = sample_provider
	_flags_provider = flags_provider
	if not _same_attempt() or not sample_provider.is_valid() or not flags_provider.is_valid(): return false
	add_to_group(TARGET_GROUP)
	return true

func belongs_to(source: Node, store: Node) -> bool:
	return source == _source and store == _store and _same_attempt()

func reset_after_restore(source: Node, store: Node) -> void:
	if source != _source or store != _store: return
	var spec := definition()
	if spec.is_empty(): return
	_simulation.configure(spec)
	_committed = false
	if not _same_attempt(): return # New attempts require explicit level binding.
	var records: Variant = _store.data.active_run.get("state",{}).get("device_outcomes",{})
	if records is Dictionary: _committed = _simulation.restore_completed(records.get(spec.id))

func targeting_reason(source: Node, store: Node) -> String:
	if not belongs_to(source,store): return "inactive_attempt"
	if _committed: return "committed"
	if not _simulation.outcome().is_empty(): return "awaiting_commit"
	if not _sample_provider.is_valid() or not _flags_provider.is_valid(): return "missing_context"
	var sample: Variant = _sample_provider.call()
	var flags: Variant = _flags_provider.call()
	if not sample is Dictionary or not flags is Dictionary: return "missing_context"
	return RULES.eligibility(definition(),_store.selected_device_mode(),_store.device_state(),sample,flags,_introduction_authorized())

func apply_live_exposure(delta: float, muzzle: Node2D, source: Node, store: Node) -> Dictionary:
	var reason := targeting_reason(source,store)
	if not reason.is_empty(): return {"reason":reason,"new_outcome":false}
	# Read again at the simulation boundary so a condition changed during an
	# aiming callback cannot become stale authorisation.
	var sample: Variant = _sample_provider.call()
	var flags: Variant = _flags_provider.call()
	if not sample is Dictionary or not flags is Dictionary: return {"reason":"missing_context","new_outcome":false}
	return apply_exposure(delta,muzzle,sample,flags,true)

func _live_source() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_source) or not is_instance_valid(_store): return false
	if not _source.is_inside_tree() or not _store.is_inside_tree() or not _store.has_method("campaign_source"): return false
	var spec := definition()
	if _source.has_method("world_target_allowed") and not _source.world_target_allowed(self):return false
	return not spec.is_empty() and _source.is_ancestor_of(self) and _store.campaign_source(_source, spec.zone, spec.level)

func _same_attempt() -> bool:
	return _live_source() and not _attempt_id.is_empty() and _store.data.active_run.get("attempt_id", "") == _attempt_id

func _introduction_authorized() -> bool:
	var spec := definition()
	var id: String = spec.get("introductory_milestone", "")
	if id.is_empty() or not DEVICE.MILESTONES.has(id): return false
	if not DEVICE.has_lesson(_store.data, DEVICE.MILESTONES[id]): return false
	if _source.has_method("world_introduction_authorized"):return _source.world_introduction_authorized(self,id)
	# A guided target may teach its capability only in the authored introduction.
	# Its puzzle receipt is still staged by the level's verified task callback.
	var contracts: Dictionary = _store.LEVEL_REGISTRY.definition(spec.zone, spec.level).get("device_milestone_successes", {})
	return contracts.has(id)

func geometry_reason(muzzle: Node2D) -> String:
	if not is_instance_valid(muzzle) or not muzzle.is_inside_tree() or muzzle.is_queued_for_deletion(): return "missing_muzzle"
	var player: Variant = _source.get("player") if is_instance_valid(_source) else null
	if not is_instance_valid(player) or not player is Node2D or (muzzle != player and not player.is_ancestor_of(muzzle)): return "foreign_muzzle"
	if not muzzle.global_position.is_finite() or not global_position.is_finite(): return "invalid_geometry"
	if _source.has_method("world_target_contact_allowed"):
		if not _source.world_target_contact_allowed(self):return "locked_border"
	elif is_instance_valid(player) and _source.has_method("world_contact_allowed") and not _source.world_contact_allowed(player.global_position,global_position): return "locked_border"
	if muzzle.global_position.distance_to(global_position) > float(definition().get("max_range", 0)): return "out_of_range"
	var query := PhysicsRayQueryParameters2D.create(muzzle.global_position, global_position, BLOCKER_MASK)
	if _source.has_method("world_device_ray"):
		var grounded: Dictionary=_source.world_device_ray(muzzle.global_position,global_position,self)
		if not grounded.is_empty():query.from=grounded.from;query.to=grounded.to;query.exclude=grounded.exclude
	query.collide_with_areas = true
	query.hit_from_inside = true
	if player is CollisionObject2D:
		var exclusions: Array[RID]=query.exclude
		if not exclusions.has(player.get_rid()):exclusions.append(player.get_rid())
		query.exclude=exclusions
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var own_endpoint := is_instance_valid(hit_collider) and (is_ancestor_of(hit_collider) or hit_collider.is_ancestor_of(self))
	if not hit.is_empty() and (not own_endpoint or hit.collider != hit_collider): return "occluded"
	return ""

func apply_exposure(delta: float, muzzle: Node2D, sample: Dictionary, flags: Dictionary, firing: bool) -> Dictionary:
	if not _same_attempt(): return {"reason":"inactive_attempt", "new_outcome":false}
	if _committed: return {"reason":"committed", "new_outcome":false}
	if get_tree().paused or _source.get("dead") == true: return {"reason":"inactive_gameplay", "new_outcome":false}
	if not firing: return {"reason":"not_firing", "new_outcome":false}
	var reason := geometry_reason(muzzle)
	if not reason.is_empty(): return {"reason":reason, "new_outcome":false}
	var result: Dictionary = _simulation.advance(delta, _store.selected_device_mode(), _store.device_state(), sample, flags, _introduction_authorized())
	if result.new_outcome: outcome_ready.emit(_simulation.outcome())
	return result

func verified_outcome(store: Node, source: Node) -> Dictionary:
	if store != _store or source != _source or not _same_attempt() or get_tree().paused or _source.get("dead") == true: return {}
	return _simulation.outcome()

func acknowledge_commit(store: Node, source: Node) -> void:
	if not verified_outcome(store, source).is_empty(): _committed = true
