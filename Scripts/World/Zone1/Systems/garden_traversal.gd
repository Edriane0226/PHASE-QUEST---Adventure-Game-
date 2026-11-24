extends Node2D
## Authored L1 low obstacles. No science completion, fall, or reward logic here.
var level: Node
var completed: Dictionary = {}
var _instruction_shown := false
var _save_retry := 0.0
var _run_dirty := false

func bind(owner_level: Node) -> void:
	level = owner_level
	level.player.landed.connect(_landed)
	# Restore may have run inside the parent's ready before this binding.
	restore(completed)

func restore(records: Dictionary) -> void:
	completed = records.duplicate()

func _inside(marker: Node2D, at: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(marker.to_local(level.to_global(at)), marker.polygon)

func _landed(origin: Vector2, destination: Vector2) -> void:
	if level.demonstration_mode or level.player.carrying: return
	for route in get_children():
		var id: String = route.get_meta("obstacle_id")
		if completed.has(id): continue
		if id == "z1_l1_j2" and level.melted[2] < 1.0: continue
		if not _inside(route.get_node("Takeoff"), origin) or not _inside(route.get_node("Landing"), destination): continue
		if not level.valid_landing(destination): continue
		completed[id] = true
		if id == "z1_l1_j1":
			level.jump_practiced = true
			_acknowledge_jump()
		_save_retry = 2.0
		_run_dirty = not level._persist_run()
		if _run_dirty: level._message(get_node("/root/PlayerSave").last_error)

func _acknowledge_jump() -> void:
	var store := get_node("/root/PlayerSave")
	if store.jump_tutorial_seen(): return
	if store.mark_jump_tutorial_seen():
		level._message("Nice jump!")
	else:
		level._message(store.last_error)

func _process(delta: float) -> void:
	if not is_instance_valid(level) or level.demonstration_mode: return
	var show_jump_hint: bool = not get_node("/root/PlayerSave").jump_tutorial_seen()
	$J1/TakeoffMark.visible = show_jump_hint
	$J1/LandingMark.visible = show_jump_hint
	_save_retry = maxf(0.0, _save_retry - delta)
	if _save_retry <= 0:
		_save_retry = 2.0
		if completed.has("z1_l1_j1"): _acknowledge_jump()
		if _run_dirty: _run_dirty = not level._persist_run()
	if not level.player_controls_allowed() or get_tree().paused: return
	if _instruction_shown or get_node("/root/PlayerSave").jump_tutorial_seen(): return
	if level.player.position.distance_to($J1/Takeoff.global_position) < 120:
		_instruction_shown = true
		level._message("Move toward the gold landing marker and tap Jump to cross the low log.")
