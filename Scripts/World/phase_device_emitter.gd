extends Node
## Shared input-to-contact lifecycle. Outcomes stay in target/level contracts;
## production effects consume snapshot()/signals without advancing simulation.
signal emission_changed(active: bool)
signal contact_changed(target: Node)
signal shot_started
signal shot_stopped(cause: String)
const TARGET = preload("res://Scripts/World/phase_device_target_2d.gd")
const CUE = preload("res://Scripts/World/phase_device_target_cue.gd")
const THERMAL = preload("res://Scripts/World/thermal_blast_effects.gd")
const CRYO = preload("res://Scripts/World/cryo_beam_effects.gd")
const PRESSURE = preload("res://Scripts/World/pressure_vice_effects.gd")
const VACUUM = preload("res://Scripts/World/vacuum_burst_effects.gd")
const RANGE := 100.0
const HALF_CONE := PI/6 # 60-degree full cone, measured from current muzzle.
const FACINGS := {"east":Vector2.RIGHT,"south_east":Vector2(1,1),"south":Vector2.DOWN,"south_west":Vector2(-1,1),"west":Vector2.LEFT,"north_west":Vector2(-1,-1),"north":Vector2.UP,"north_east":Vector2(1,-1)}
var player: Node2D
var store: Node
var source: Node
var permission: Callable
var held := false
var requires_release := false
var selected: Node2D
var reason := ""
var facing := Vector2.DOWN
var _cue: Node2D
var _attempt := ""
var _mode := ""
var _had_target := false
var _emitting := false
var _focused := true
var _suspended := false
var _generation := 0
var _scene_ready := false
var _was_dead := false
var _shot_started := false
var thermal_effects: Node2D
var cryo_effects: Node2D
var pressure_effects: Node2D
var vacuum_effects: Node2D

func bind(actor: Node2D, profile: Node, gate: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	player = actor
	store = profile
	permission = gate
	if not is_instance_valid(player): return
	source = player.level()
	if source.is_node_ready(): _scene_ready = true
	else: source.ready.connect(func(): _scene_ready = true,CONNECT_ONE_SHOT)
	_mode = store.selected_device_mode()
	_attempt = str(store.data.active_run.get("attempt_id",""))
	store.changed.connect(_profile_changed)
	store.restored.connect(_profile_restored)
	if player.is_node_ready(): _ready_player()
	else: player.ready.connect(_ready_player,CONNECT_ONE_SHOT)

func _ready_player() -> void:
	facing = FACINGS.get(player._facing,Vector2.DOWN).normalized()
	_cue = CUE.new()
	_cue.name = "PhaseTargetCue"
	var hud := source.get_node_or_null("GameplayHUD")
	if hud != null: _cue.caption_layout = Callable(hud,"device_caption_position")
	player.add_child(_cue)
	_cue.top_level = true
	_cue.global_transform = Transform2D.IDENTITY
	_cue.z_index = 4095
	thermal_effects = THERMAL.new()
	thermal_effects.name = "ThermalBlastEffects"
	player.add_child(thermal_effects)
	thermal_effects.bind(self)
	cryo_effects = CRYO.new()
	cryo_effects.name = "CryoBeamEffects"
	player.add_child(cryo_effects)
	cryo_effects.bind(self)
	pressure_effects = PRESSURE.new()
	pressure_effects.name = "PressureViceEffects"
	player.add_child(pressure_effects)
	pressure_effects.bind(self)
	vacuum_effects = VACUUM.new()
	vacuum_effects.name = "VacuumBurstEffects"
	player.add_child(vacuum_effects)
	vacuum_effects.bind(self)

func available() -> bool:
	if not is_inside_tree(): return false
	if not _scene_ready or not is_instance_valid(player) or not player.is_node_ready() or not is_instance_valid(source) or not source.is_node_ready(): return false
	if source.is_queued_for_deletion() or source != get_tree().current_scene or source.get("demonstration_mode") == true: return false
	if not _focused or _suspended or get_tree().paused or not permission.is_valid() or not permission.call(): return false
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and transition.get("busy") == true: return false
	if not store.campaign_source(source,source.SAVE_ZONE,source.SAVE_LEVEL): return false
	return player.device_rig.available() and not player.device_rig.blocked()

func _profile_changed() -> void:
	_mode = store.selected_device_mode()
	_attempt = str(store.data.active_run.get("attempt_id",""))
	interrupt("saved")

func _reset_targets() -> void:
	if not is_inside_tree(): return
	for target in get_tree().get_nodes_in_group(TARGET.TARGET_GROUP):
		if target is TARGET: target.reset_after_restore(source,store)

func _profile_restored() -> void:
	_profile_changed()
	_reset_targets()

func _valid(target: Node2D) -> String:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree(): return "target_lost"
	if not target is TARGET or target.get_viewport() != player.get_viewport(): return "foreign_target"
	var eligibility: String = target.targeting_reason(source,store)
	if not eligibility.is_empty(): return eligibility
	if source.has_method("world_target_contact_allowed"):
		if not source.world_target_contact_allowed(target):return "locked_border"
	elif source.has_method("world_contact_allowed") and not source.world_contact_allowed(player.global_position,target.global_position): return "locked_border"
	var muzzle: Node2D = player.device_muzzle()
	var offset: Vector2 = target.global_position-muzzle.global_position
	if offset.length() > minf(RANGE,float(target.definition().max_range)): return "out_of_range"
	if offset.is_zero_approx() or absf(facing.angle_to(offset)) > HALF_CONE: return "outside_cone"
	return target.geometry_reason(muzzle)

func _pick() -> Node2D:
	var best: Node2D
	var best_angle := INF
	var best_distance := INF
	var best_key := ""
	var closest_rejected := INF
	reason = "no_target"
	for candidate in get_tree().get_nodes_in_group(TARGET.TARGET_GROUP):
		if not candidate is TARGET or candidate.get_viewport() != player.get_viewport() or not candidate.belongs_to(source,store): continue
		var offset: Vector2 = candidate.global_position-player.device_muzzle().global_position
		var angle := absf(facing.angle_to(offset))
		var distance := offset.length_squared()
		var invalid := _valid(candidate)
		if not invalid.is_empty():
			if angle <= HALF_CONE and distance < closest_rejected and invalid not in ["committed","awaiting_commit"]:
				closest_rejected = distance
				reason = invalid
			continue
		var key: String = str(candidate.definition().id)+str(candidate.get_path())
		if angle < best_angle and not is_equal_approx(angle,best_angle) or (is_equal_approx(angle,best_angle) and (distance < best_distance or (is_equal_approx(distance,best_distance) and key < best_key))):
			best = candidate
			best_angle = angle
			best_distance = distance
			best_key = key
	return best

func _set_target(target: Node2D) -> void:
	if selected == target: return
	selected = target
	contact_changed.emit(target)

func _aim() -> bool:
	var movement: Vector2 = player.movement_input()
	if not movement.is_zero_approx(): facing = movement.normalized()
	player.device_rig.sync_pose()
	if is_instance_valid(selected):
		var invalid := _valid(selected)
		if not invalid.is_empty():
			reason = invalid
			if held and _had_target: interrupt(invalid); return false
			_set_target(null)
	elif held and _had_target:
		interrupt("target_lost")
		return false
	if not is_instance_valid(selected): _set_target(_pick())
	if is_instance_valid(selected):
		player.set_device_aim(selected.global_position-player.device_muzzle().global_position)
		# Aiming swaps directional frames and muzzle sockets. Recheck the actual
		# new muzzle, never a cached player center or predicted barrel location.
		var invalid := _valid(selected)
		if not invalid.is_empty():
			if held: interrupt(invalid); return false
			_set_target(null)
		else:
			if held: _had_target = true
			return true
	player._facing = player._direction_from_vector(facing)
	player._play(player.locomotion)
	player.set_device_aim(facing,false)
	player.device_rig.sync_pose()
	return true

func press() -> bool:
	if held: return false
	held = true
	_shot_started = false
	if requires_release or not available():
		requires_release = true
		return false
	if not _aim(): return false
	_had_target = is_instance_valid(selected)
	_shot_started = player.set_device_firing(true)
	if not _shot_started: requires_release = true
	else: shot_started.emit()
	return _shot_started

func release() -> void:
	var was_started := _shot_started or _emitting
	held = false
	_shot_started = false
	requires_release = false
	_had_target = false
	if _scene_ready and is_instance_valid(player) and player.is_node_ready(): player.set_device_firing(false)
	_emit(false)
	if was_started: shot_stopped.emit("release")
	if not available(): interrupt("inactive_gameplay")

func interrupt(cause := "interrupted") -> void:
	var was_started := _shot_started or _emitting
	_generation += 1
	reason = cause
	requires_release = requires_release or held
	_shot_started = false
	if _scene_ready and is_instance_valid(player) and player.is_node_ready():
		player.device_rig.interrupt()
		player.set_device_aim(facing,false)
	_set_target(null)
	_emit(false)
	if was_started: shot_stopped.emit(cause)
	if is_instance_valid(_cue): _cue.present({})

func _emit(value: bool) -> void:
	if value == _emitting: return
	_emitting = value
	emission_changed.emit(value)

func snapshot() -> Dictionary:
	if not available(): return {}
	var muzzle: Node2D = player.device_muzzle()
	if not muzzle.global_position.is_finite(): return {}
	var active: bool = held and _shot_started and not requires_release and player.device_rig.emission_active()
	if held and _had_target and not is_instance_valid(selected): active = false
	if is_instance_valid(selected) and not _valid(selected).is_empty(): active = false
	var endpoint := muzzle.global_position+facing*RANGE
	if is_instance_valid(selected): endpoint = selected.global_position
	if source.has_method("world_emission_endpoint"): endpoint = source.world_emission_endpoint(player.global_position,muzzle.global_position,endpoint)
	# Presentation terminates at the surface of an authorized endpoint collider,
	# or the first blocker on a miss; it never draws through to a sample's center.
	var ray := PhysicsRayQueryParameters2D.create(muzzle.global_position,endpoint,TARGET.BLOCKER_MASK,[player.get_rid()])
	var projected_offset:=Vector2.ZERO
	if source.has_method("world_device_ray"):
		var grounded: Dictionary=source.world_device_ray(muzzle.global_position,endpoint,selected)
		if not grounded.is_empty():ray.from=grounded.from;ray.to=grounded.to;ray.exclude=grounded.exclude;projected_offset=grounded.offset
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	var hit := player.get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): endpoint = hit.position-projected_offset
	var reach: float = minf(RANGE,float(selected.definition().max_range)) if is_instance_valid(selected) else RANGE
	return {
		"chamber_qualified":is_instance_valid(selected) and store.selected_device_mode() in ["pressure","vacuum"] and _valid(selected).is_empty(),
		"origin":muzzle.global_position,"actor":player.global_position,"point":endpoint,"facing":facing,"range":reach,
		"sample_point":selected.global_position if is_instance_valid(selected) else endpoint,
		"mode":store.selected_device_mode(),"target":is_instance_valid(selected),"active":active,
		"shot":held and _shot_started and not requires_release,"phase":player.device_rig.phase,
		"radius":clampf(selected.cue_radius,6,48) if is_instance_valid(selected) else 0.0,
		"progress":selected.exposure()/float(selected.definition().required_exposure) if is_instance_valid(selected) else 0.0,
		"status":_status()
	}

func _status() -> String:
	if requires_release and held: return "RELEASE FIRE"
	if not held and reason == "no_target": return ""
	return {"occluded":"PATH BLOCKED","out_of_range":"OUT OF RANGE","unsupported_mode":"WRONG MODE","locked_capability":"LEARN CAPABILITY FIRST","prerequisite_missing":"PREPARE TARGET FIRST","unsuitable_conditions":"CHECK SAMPLE CONDITIONS","wrong_state":"CHECK SAMPLE STATE","no_target":"NO TARGET"}.get(reason,"NO CLEAR TARGET")

func _physics_process(delta: float) -> void:
	if is_instance_valid(source):
		var dead: bool = source.get("dead") == true
		if dead and not _was_dead: _reset_targets()
		_was_dead = dead
	if not available():
		if held or is_instance_valid(selected) or _emitting: interrupt("inactive_gameplay")
		return
	if store.selected_device_mode() != _mode or str(store.data.active_run.get("attempt_id","")) != _attempt:
		_profile_changed()
		return
	if requires_release and held:
		if is_instance_valid(_cue): _cue.present(snapshot())
		return
	if not _aim(): return
	var active: bool = held and _shot_started and player.device_rig.emission_active()
	_emit(active)
	if active and is_instance_valid(selected):
		var target: Node2D = selected
		var generation := _generation
		var result: Dictionary = target.apply_live_exposure(delta,player.device_muzzle(),source,store)
		if generation != _generation: return # A durable outcome can save/re-enter.
		if result.new_outcome or result.reason in ["complete","committed","awaiting_commit"]: interrupt("verified")
		elif result.reason != "exposing": interrupt(result.reason)
	if is_instance_valid(_cue): _cue.present(snapshot())

func _process(_delta: float) -> void:
	# Hard invalidations clear contact between physics ticks too.
	if not available() and (held or is_instance_valid(selected) or _emitting): interrupt("inactive_gameplay")
	elif held and _had_target:
		if not is_instance_valid(selected): interrupt("target_lost")
		else:
			var invalid := _valid(selected)
			if not invalid.is_empty(): interrupt(invalid)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _focused = false; interrupt("background")
	elif what == NOTIFICATION_APPLICATION_PAUSED: _suspended = true; interrupt("background")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _focused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _suspended = false
	elif what == NOTIFICATION_EXIT_TREE:
		interrupt("scene_change")
		if is_instance_valid(_cue): _cue.queue_free()
		if is_instance_valid(thermal_effects): thermal_effects.queue_free()
		if is_instance_valid(cryo_effects): cryo_effects.queue_free()
		if is_instance_valid(pressure_effects): pressure_effects.queue_free()
		if is_instance_valid(vacuum_effects): vacuum_effects.queue_free()
