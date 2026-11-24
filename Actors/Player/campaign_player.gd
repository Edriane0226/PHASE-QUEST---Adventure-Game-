extends "res://Actors/Player/player_model.gd"
## Shared campaign locomotion and grounded action animation.
signal action_finished(action: String)
signal jumped
signal landed(origin: Vector2, destination: Vector2)
@export var jump_duration := 0.56
@export var jump_speed := 185.0
@export var jump_height := 48.0
@export var carry_speed_multiplier := 0.70
@export var facing_hysteresis_degrees := 8.0
@export var walk_cycle_distance := 32.0
@export var run_cycle_distance := 48.0
# Palm centers measured in the unchanged 192px carry frames. Each row follows
# the four authored poses, so the carried object moves with the hands.
const CARRY_HANDS := {
	"carry_idle": {
		"east": [Vector2(113,117),Vector2(112,118),Vector2(111,117),Vector2(110,117)],
		"south_east": [Vector2(111,116),Vector2(111,116),Vector2(110,117),Vector2(109,116)],
		"south": [Vector2(97,118),Vector2(97,119),Vector2(97,118),Vector2(97,117)],
		"south_west": [Vector2(80,116),Vector2(80,116),Vector2(81,117),Vector2(82,116)],
		"west": [Vector2(78,117),Vector2(79,118),Vector2(80,117),Vector2(81,117)],
		"north_west": [Vector2(70,114),Vector2(68,113),Vector2(69,113),Vector2(69,113)],
		"north": [Vector2(110,116),Vector2(109,115),Vector2(108,115),Vector2(109,116)],
		"north_east": [Vector2(121,114),Vector2(123,113),Vector2(122,113),Vector2(122,113)],
	},
	"carry_walk": {
		"east": [Vector2(114,106),Vector2(116,102),Vector2(112,106),Vector2(117,101)],
		"south_east": [Vector2(105,111),Vector2(105,108),Vector2(104,112),Vector2(105,108)],
		"south": [Vector2(96,104),Vector2(94,105),Vector2(95,104),Vector2(95,104)],
		"south_west": [Vector2(89,106),Vector2(90,105),Vector2(89,109),Vector2(89,105)],
		"west": [Vector2(77,107),Vector2(76,102),Vector2(77,108),Vector2(77,103)],
		"north_west": [Vector2(70,114),Vector2(68,113),Vector2(69,114),Vector2(69,113)],
		"north": [Vector2(96,103),Vector2(96,102),Vector2(96,103),Vector2(96,102)],
		"north_east": [Vector2(121,114),Vector2(123,113),Vector2(122,114),Vector2(122,113)],
	},
}
const PLACE_HANDS := {
	"east": [Vector2(104,111),Vector2(103,129),Vector2(109,151),Vector2(104,111)],
	"south_east": [Vector2(97,112),Vector2(99,128),Vector2(105,150),Vector2(97,112)],
	"south": [Vector2(95,110),Vector2(98,125),Vector2(101,151),Vector2(95,110)],
	"south_west": [Vector2(94,112),Vector2(92,128),Vector2(86,150),Vector2(94,112)],
	"west": [Vector2(87,111),Vector2(88,129),Vector2(82,151),Vector2(87,111)],
	"north_west": [Vector2(76,105),Vector2(76,126),Vector2(69,148),Vector2(76,105)],
	"north": [Vector2(96,107),Vector2(115,127),Vector2(120,148),Vector2(96,107)],
	"north_east": [Vector2(115,105),Vector2(115,126),Vector2(122,148),Vector2(115,105)],
}
const PLACE_FOOT_OFFSETS := {
	"east": [0,12,14,-2], "south_east": [0,9,14,-4],
	"south": [0,3,9,-1], "south_west": [0,-9,-14,4],
	"west": [0,-12,-14,2], "north_west": [0,-12,-15,-1],
	"north": [0,9,10,0], "north_east": [0,12,15,1],
}
const OPERATE_HANDS := {
	"east": [Vector2(114,104),Vector2(117,100),Vector2(117,103),Vector2(117,104)],
	"south_east": [Vector2(107,105),Vector2(116,100),Vector2(110,103),Vector2(112,103)],
	"south": [Vector2(97,108),Vector2(99,100),Vector2(98,109),Vector2(101,107)],
	"south_west": [Vector2(84,105),Vector2(75,100),Vector2(81,103),Vector2(79,103)],
	"west": [Vector2(77,104),Vector2(74,100),Vector2(74,103),Vector2(74,104)],
	"north_west": [Vector2(69,104),Vector2(72,98),Vector2(72,100),Vector2(66,99)],
	"north": [Vector2(96,106),Vector2(113,98),Vector2(119,100),Vector2(96,101)],
	"north_east": [Vector2(122,104),Vector2(119,98),Vector2(119,100),Vector2(124,99)],
}
const INTERACTION_FOOT_OFFSETS := {
	"touch": {
		"east":[0,16,18,1], "south_east":[0,15,18,1], "south":[0,8,5,0], "south_west":[0,-15,-18,-1],
		"west":[0,-16,-18,-1], "north_west":[0,-14,-15,3], "north":[0,10,11,0], "north_east":[0,14,15,-3],
	},
	"operate": {
		"east":[0,4,6,-2], "south_east":[0,2,5,-1], "south":[0,-2,-2,-4], "south_west":[0,-2,-5,1],
		"west":[0,-4,-6,2], "north_west":[0,-3,-8,-1], "north":[0,2,1,2], "north_east":[0,3,8,1],
	},
}
var _gait_phase := 0.0
var _gait_action := ""
var locomotion := "idle"
var carrying := false:
	set(value):
		carrying = value
		if is_node_ready() and is_instance_valid(device_rig):
			if value: device_rig.interrupt()
			device_rig.sync_pose()
@onready var device_rig = $PhaseDeviceRig
var context_action := ""
var context_progress := -1.0
var context_target := Vector2.ZERO
var jump_elapsed := -1.0
var action_elapsed := -1.0
var action_duration := 0.45
var action_name := ""
var _action_commit := Callable()
var _action_committed := false
var _jump_origin := Vector2.ZERO
var _travel_direction := Vector2.ZERO
var _visual_home := Vector2.ZERO
var _visual_scale := Vector2.ONE
var _saved_visual_scale := Vector2.ONE
var _saved_visual_home := Vector2.ZERO
var _shadow_scale := Vector2.ONE
var _shadow_home := Vector2.ZERO
var _floor_height := 0.0
var _display_floor := 0.0
var _jump_floor := 0.0
var _jump_target_floor := 0.0
var _landing_recovery := false
var _landing_target := Vector2.ZERO
var _support_body: StaticBody2D
var _clock := 0.0
var _pickup_source: Sprite2D
var _pickup_held: Sprite2D
var _pickup_transform := Transform2D.IDENTITY
var _pickup_z := 0
var _pickup_processing := false
var _grip_offsets := {}
var _place_item: Sprite2D
var _place_start := Vector2.ZERO
var _place_target := Vector2.ZERO
var _warming_grip := Vector2.ZERO


func _ready() -> void:
	_visual_home = animated_sprite.position
	_visual_scale = animated_sprite.scale
	_saved_visual_scale = _visual_scale
	_saved_visual_home = _visual_home
	_fit_carried_objects()
	_fit_warming_tool()
	animated_sprite.frame_changed.connect(_normalize_pose)
	animated_sprite.animation_changed.connect(_normalize_pose)
	_shadow_scale = $GroundShadow.scale
	_shadow_home = $GroundShadow.position
	_jump_origin = position
	_sync_ground_support()
	_jump_floor = _floor_height
	_play("idle")


func level() -> Node:
	return get_parent().get_parent()


func controls_allowed() -> bool:
	return is_inside_tree() and not get_tree().paused and level().player_controls_allowed()


func movement_speed() -> float:
	return super.movement_speed() * (carry_speed_multiplier if carrying else 1.0)

func set_device_aim(direction: Vector2, enabled := true) -> bool:
	return device_rig.aim(direction,enabled)

func set_device_firing(pressed: bool) -> bool:
	return device_rig.fire(pressed)

func device_muzzle() -> Marker2D:
	return device_rig.muzzle()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not controls_allowed(): return
	if event.physical_keycode == KEY_SPACE:
		request_jump()
		get_viewport().set_input_as_handled()


func request_jump() -> bool:
	if not controls_allowed() or carrying or context_progress >= 0 or jump_elapsed >= 0 or action_elapsed >= 0:
		return false
	_landing_recovery = false
	device_rig.interrupt()
	_jump_origin = position
	_sync_ground_support()
	_jump_floor = _floor_height
	_travel_direction = movement_input().normalized()
	var destination: Dictionary = level().raised_surface(position+_travel_direction*jump_speed*jump_duration)
	_jump_target_floor = float(destination.get("height",0))
	jump_elapsed = 0.0
	locomotion = "jump"
	set_collision_mask_value(2,false)
	jumped.emit()
	device_rig.sync_pose()
	return true


func perform_action(action: String, commit: Callable, duration := 0.45) -> bool:
	if not controls_allowed() or context_progress >= 0 or action_elapsed >= 0 or jump_elapsed >= 0:
		return false
	velocity = Vector2.ZERO
	action_name = action
	action_duration = duration
	action_elapsed = 0.0
	_action_commit = commit
	_action_committed = false
	device_rig.interrupt()
	device_rig.sync_pose()
	return true


func cancel_motion() -> void:
	device_rig.interrupt()
	_restore_pickup_visual()
	_place_item = null
	if jump_elapsed >= 0:
		position = _jump_origin
		reset_physics_interpolation()
	jump_elapsed = -1.0
	_landing_recovery = false
	action_elapsed = -1.0
	action_name = ""
	_action_commit = Callable()
	set_collision_mask_value(2,true)
	velocity = Vector2.ZERO
	if is_instance_valid(animated_sprite):
		_sync_ground_support()
		_display_floor = _floor_height
		animated_sprite.position = _visual_home-Vector2(0,_floor_height)
		$GroundShadow.position = _shadow_home-Vector2(0,_floor_height)
		animated_sprite.scale = _visual_scale
		$GroundShadow.scale = _shadow_scale
		if context_progress >= 0:
			sync_operation(context_progress,context_target)
		else:
			_play("carry_idle" if carrying else "idle")


func reset_touch_movement() -> void:
	super.reset_touch_movement()
	if is_node_ready(): cancel_motion()


func safe_save_position() -> Vector2:
	return _jump_origin if jump_elapsed >= 0 else position


func _physics_process(delta: float) -> void:
	_clock += delta
	if not controls_allowed():
		velocity = Vector2.ZERO
		return
	animated_sprite.position = _visual_home
	if jump_elapsed<0: _sync_ground_support()
	var visual_elevation := _floor_height
	var input := movement_input()
	if context_progress >= 0:
		if not input.is_zero_approx():
			level().cancel_thaw_operation()
		else:
			velocity = Vector2.ZERO
			var aim := context_target-global_position
			if not aim.is_zero_approx(): _facing = _direction_from_vector(aim)
	if input.length_squared()>0.0025 and action_elapsed < 0 and context_progress < 0: _update_movement_facing(input)
	if device_rig.aiming and not device_rig.blocked(): _facing = device_rig.aim_facing()
	if action_elapsed >= 0:
		action_elapsed += delta
		velocity = Vector2.ZERO
		_play_timed(action_name,action_elapsed,action_duration)
		_sync_carry_socket()
		var contact := 0.68 if action_name == "place" else (1.0 if action_name == "operate" else 0.55)
		if action_elapsed >= action_duration*contact and not _action_committed:
			_action_committed = true
			var commit := _action_commit
			_action_commit = Callable()
			if commit.is_valid(): commit.call()
		if action_elapsed >= action_duration:
			var completed := action_name
			_restore_pickup_visual()
			_place_item = null
			action_elapsed = -1.0
			action_name = ""
			action_finished.emit(completed)
	elif jump_elapsed >= 0:
		jump_elapsed += delta
		velocity = _travel_direction*jump_speed
		if _landing_recovery:
			if not level().valid_landing(_landing_target): _landing_target = _nearest_safe_landing()
			velocity = (_landing_target-position).limit_length(jump_speed*delta)/maxf(delta,0.001)
		move_and_slide()
		var phase := clampf(jump_elapsed/jump_duration,0,1)
		_play_timed("jump",jump_elapsed,jump_duration)
		var destination: Dictionary = level().raised_surface(position)
		var target_height := float(destination.get("height",0))
		visual_elevation = lerpf(_jump_floor,_jump_target_floor,phase)+sin(phase*PI)*jump_height
		$GroundShadow.scale = _shadow_scale*(1.0-0.28*sin(phase*PI))
		if jump_elapsed >= jump_duration:
			if level().unsupported_fall(position):
				level().traversal_fall()
				return
			if target_height>_jump_floor+jump_height or not level().valid_landing(position):
				if not _landing_recovery or position.distance_to(_landing_target)<1:
					_landing_target = _nearest_safe_landing()
				_landing_recovery = true
			else:
				set_collision_mask_value(2,true)
				jump_elapsed = -1.0
				_landing_recovery = false
				velocity = Vector2.ZERO
				_sync_ground_support()
				_display_floor = _floor_height
				visual_elevation = _floor_height
				$GroundShadow.scale = _shadow_scale
				landed.emit(_jump_origin, position)
	else:
		var speed := movement_speed()
		if carrying: speed = move_speed*carry_speed_multiplier
		velocity = velocity.move_toward(input*speed,(acceleration if not input.is_zero_approx() else friction)*delta)
		var before := position
		move_and_slide()
		if level().unsupported_fall(position):
			level().traversal_fall()
			return
		_sync_ground_support()
		visual_elevation = _floor_height
		var travelled := position.distance_to(before)
		var actual_speed := travelled/maxf(delta,0.001)
		var was_running := locomotion=="run"
		var run_threshold := move_speed*(0.60 if was_running and movement_speed()>move_speed else 1.28)
		locomotion = "idle" if actual_speed<3 else ("run" if actual_speed>run_threshold and not carrying else "walk")
		var visual_action := ("carry_idle" if locomotion=="idle" else "carry_walk") if carrying else (
			context_action if locomotion=="idle" and not context_action.is_empty() else locomotion
		)
		if context_progress >= 0:
			_play_timed("operate",context_progress,1.0)
		else:
			_play(visual_action)
			_advance_grounded_gait(visual_action,travelled)
		animated_sprite.position = _visual_home
		animated_sprite.scale = _visual_scale
	if jump_elapsed<0:
		_display_floor = move_toward(_display_floor,_floor_height,320*delta)
		visual_elevation = _display_floor
	animated_sprite.position = _visual_home-Vector2(0,visual_elevation)
	$GroundShadow.position = _shadow_home-Vector2(0,_floor_height)
	_sync_carry_socket()
	_sync_pickup_visual()
	device_rig.sync_pose()

func _update_movement_facing(direction: Vector2) -> void:
	var current := Vector2.RIGHT.rotated(DIRECTIONS.find(_facing)*PI/4)
	var angle := absf(rad_to_deg(current.angle_to(direction)))
	if angle>22.5+facing_hysteresis_degrees:
		_facing = _direction_from_vector(direction)

func _nearest_safe_landing() -> Vector2:
	# Resolve a clipped prop edge or moving animal locally, without teleporting
	# to takeoff. Hard walls and frozen gates remain in the active collision mask.
	for radius in range(4,129,4):
		for direction in range(16):
			var offset := Vector2.RIGHT.rotated(_travel_direction.angle()+direction*TAU/16)*radius
			var candidate := position+offset
			if not level().valid_landing(candidate): continue
			var surface: Dictionary = level().raised_surface(candidate)
			if float(surface.get("height",0))>_jump_floor+jump_height: continue
			if not test_move(global_transform,offset): return candidate
	return position


func _sync_ground_support() -> void:
	var surface: Dictionary = level().raised_surface(position)
	_floor_height = float(surface.get("height",0))
	var body: StaticBody2D = surface.get("body",null)
	# Retain the leaving shelf exception until the complete foot shape clears its edge.
	if body==null and is_instance_valid(_support_body):
		var nearby: Dictionary = level().raised_surface(position,14)
		if nearby.get("body",null)==_support_body: body = _support_body
	if body==_support_body: return
	if is_instance_valid(_support_body): remove_collision_exception_with(_support_body)
	_support_body = body
	if is_instance_valid(_support_body): add_collision_exception_with(_support_body)


func _advance_grounded_gait(action: String, travelled: float) -> void:
	if action not in ["walk","run","carry_walk"]:
		_gait_action = ""
		return
	if _gait_action.is_empty(): _gait_phase = 0.0
	_gait_action = action
	var cycle := run_cycle_distance if action=="run" else walk_cycle_distance
	var advanced := _gait_phase+maxf(0,travelled)/maxf(1,cycle)
	if floori(advanced*2)!=floori(_gait_phase*2):
		get_node("/root/GameAudio").play_footstep(level().footstep_surface(global_position))
	_gait_phase = fposmod(advanced,1.0)
	# Gait follows actual ground travel, so blocking, acceleration and turns cannot skate.
	animated_sprite.pause()
	var cursor := _gait_phase*animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	animated_sprite.set_frame_and_progress(floori(cursor),fposmod(cursor,1.0))


func _play(action: String) -> void:
	animated_sprite.flip_h = false
	var key := action+"_"+_facing
	if not animated_sprite.sprite_frames.has_animation(key): key = "idle_"+_facing
	if animated_sprite.animation != key: animated_sprite.play(key)
	elif not animated_sprite.is_playing() and animated_sprite.sprite_frames.get_animation_loop(key): animated_sprite.play(key)
	_normalize_pose()


func _play_timed(action: String, elapsed: float, duration: float) -> void:
	# Fit the complete authored pose sequence to the existing physics/action clock.
	_play(action)
	animated_sprite.pause()
	var frames := animated_sprite.sprite_frames
	var clip := animated_sprite.animation
	var total := 0.0
	for i in range(frames.get_frame_count(clip)): total += frames.get_frame_duration(clip,i)
	var cursor := clampf(elapsed/maxf(duration,0.001),0,1)*total
	var selected := frames.get_frame_count(clip)-1
	for i in range(frames.get_frame_count(clip)):
		cursor -= frames.get_frame_duration(clip,i)
		if cursor < 0:
			selected = i
			break
	animated_sprite.frame = selected
	_normalize_pose()


func _normalize_pose() -> void:
	var breathing: AnimationPlayer = $IdleBreathing
	if str(animated_sprite.animation).begins_with("idle_"):
		if breathing.current_animation != "breathe": breathing.play("breathe")
	else:
		breathing.stop()
		animated_sprite.material.set_shader_parameter("breath",0.0)
	# Direct play() calls (pause, defeat, restore) also reset mirrored side art.
	animated_sprite.flip_h = false
	# Keep the planted boots registered while the torso leans to set down.
	animated_sprite.offset = Vector2(PLACE_FOOT_OFFSETS[_facing][clampi(animated_sprite.frame,0,3)],0) if str(animated_sprite.animation)=="place_"+_facing else Vector2.ZERO
	for action: String in INTERACTION_FOOT_OFFSETS:
		if str(animated_sprite.animation)==action+"_"+_facing:
			animated_sprite.offset.x = INTERACTION_FOOT_OFFSETS[action][_facing][clampi(animated_sprite.frame,0,3)]
			break
	var lift := animated_sprite.position-_visual_home
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation,animated_sprite.frame)
	if texture.get_meta("preview_registered",false):
		animated_sprite.offset = Vector2.ZERO
	if str(animated_sprite.animation).begins_with("walk_") or str(animated_sprite.animation).begins_with("idle_"):
		animated_sprite.flip_h = bool(texture.get_meta("mirror_walk",animated_sprite.flip_h))
	var factor := float(texture.get_meta("pose_scale",1.0))
	_visual_scale = _saved_visual_scale*factor
	_visual_home = _saved_visual_home*factor
	var anchor: Vector2 = texture.get_meta("ground_anchor",Vector2(256,480))
	_visual_home += (Vector2(256,480)-anchor)*_visual_scale
	if texture.has_meta("pose_home"):
		_visual_home = texture.get_meta("pose_home")
		if animated_sprite.flip_h and _facing not in ["north","south"]: _visual_home.x = -_visual_home.x
	animated_sprite.scale = _visual_scale
	animated_sprite.position = _visual_home+lift
	if is_node_ready() and carrying:
		_sync_carry_socket()
	if is_node_ready() and is_instance_valid(device_rig): device_rig.sync_pose()


func _sync_carry_socket() -> void:
	var socket: Marker2D = get_node("CarrySockets/"+_facing)
	$CarriedModule.visible = carrying
	$CarriedModule.position = socket.position+Vector2(0,animated_sprite.position.y-_visual_home.y)
	for visual: Sprite2D in $CarriedModule.get_children():
		if visual.visible or visual == _pickup_held:
			$CarriedModule.position = _carry_hand_position()-_held_grip_offset(visual)
			break
	if is_instance_valid(_place_item) and action_name == "place" and not _action_committed:
		var progress := smoothstep(0.15,0.65,action_elapsed/action_duration)
		var preferred := _place_start.lerp(_place_target,progress)
		var hand := to_global(_carry_hand_position())
		# The fixture guides the contact, but cannot pull the object away from
		# the drawn hands. The close-range gate supplies the remaining reach.
		var grip := hand+(preferred-hand).limit_length(1.0)
		$CarriedModule.position = to_local(grip)-_held_grip_offset(_place_item)
	# Diagonal rear poses expose their forward hand at the silhouette edge;
	# draw the object over that hand instead of hiding it behind the whole body.
	$CarriedModule.z_index = -1 if _facing == "north" else 1
	var tool: Sprite2D = $WarmingTool
	tool.position = _operate_hand_position()-_warming_grip*tool.scale
	$WarmingTool.z_index = $CarriedModule.z_index


func sync_operation(progress: float, target := Vector2.ZERO) -> void:
	if progress >= 0: device_rig.interrupt()
	var was_active := context_progress >= 0
	context_progress = clampf(progress,0,1) if progress >= 0 else -1.0
	context_target = target
	context_action = "operate" if context_progress >= 0 else ""
	$WarmingTool.visible = context_progress >= 0
	if context_progress >= 0:
		velocity = Vector2.ZERO
		var aim := target-global_position
		if not aim.is_zero_approx(): _facing = _direction_from_vector(aim)
		_play_timed("operate",context_progress,1.0)
		_sync_carry_socket()
	elif was_active and action_elapsed < 0:
		_play("carry_idle" if carrying else "idle")
	device_rig.sync_pose()


func _operate_hand_position() -> Vector2:
	var poses: Array = OPERATE_HANDS[_facing]
	var palm: Vector2 = poses[clampi(animated_sprite.frame,0,3)]
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation,animated_sprite.frame)
	palm = texture.get_meta("hand_anchor",palm)
	return animated_sprite.transform*(palm-Vector2(96,96)+animated_sprite.offset)


func _fit_warming_tool() -> void:
	var tool: Sprite2D = $WarmingTool
	var size := Vector2(tool.texture.get_image().get_used_rect().size)*tool.scale.abs()
	var maximum := Vector2(30,24)*animated_sprite.scale.abs()
	tool.scale *= minf(1.0,minf(maximum.x/maxf(size.x,0.001),maximum.y/maxf(size.y,0.001)))
	_warming_grip = _sprite_grip(tool)


func perform_lift(commit: Callable, source: Sprite2D, item: String, duration := 0.65) -> bool:
	if not perform_action("lift",commit,duration): return false
	_pickup_source = source
	_pickup_transform = source.global_transform
	_pickup_z = source.z_index
	_pickup_processing = source.get_parent().is_processing()
	source.get_parent().set_process(false)
	for visual: Sprite2D in $CarriedModule.get_children():
		if visual.get_meta("carry_id","") == item:
			_pickup_held = visual
			break
	return true


func perform_place(commit: Callable, destination: Vector2, duration := 0.72) -> bool:
	if not carrying: return false
	var held: Sprite2D
	for visual: Sprite2D in $CarriedModule.get_children():
		if visual.visible:
			held = visual
			break
	if held == null: return false
	_sync_carry_socket()
	var start := held.to_global(_sprite_grip(held))
	if not perform_action("place",commit,duration): return false
	_place_item = held
	_place_start = start
	_place_target = destination
	return true


func _carry_hand_position() -> Vector2:
	# Authored palm positions in the reworked 192px frames, in compass order.
	var palms := [Vector2(126,110),Vector2(120,114),Vector2(106,115),Vector2(72,114),Vector2(66,110),Vector2(76,108),Vector2(96,108),Vector2(116,108)]
	var palm: Vector2 = palms[DIRECTIONS.find(_facing)]
	if str(animated_sprite.animation) == "place_"+_facing:
		palm = PLACE_HANDS[_facing][clampi(animated_sprite.frame,0,3)]
	for action: String in CARRY_HANDS:
		if str(animated_sprite.animation) == action+"_"+_facing:
			var poses: Array = CARRY_HANDS[action][_facing]
			palm = poses[clampi(animated_sprite.frame,0,poses.size()-1)]
			break
	if action_name == "lift" and action_elapsed >= 0:
		var rise := smoothstep(0.35,0.85,action_elapsed/action_duration)
		palm.y = lerpf(154,palm.y,rise)
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation,animated_sprite.frame)
	palm = texture.get_meta("hand_anchor",palm)
	return animated_sprite.transform*(palm-Vector2(96,96)+animated_sprite.offset)


func _sprite_grip(visual: Sprite2D) -> Vector2:
	var used := visual.texture.get_image().get_used_rect()
	# AtlasTexture.get_image() omits the transparent margin that is present
	# when the texture is drawn. Restore it before converting to sprite space.
	var margin := Vector2.ZERO
	if visual.texture is AtlasTexture:
		margin = (visual.texture as AtlasTexture).margin.position
	return Vector2(used.position.x+used.size.x*0.5,used.end.y)+margin+visual.offset-visual.texture.get_size()*0.5


func _fit_carried_objects() -> void:
	# Ground props retain their authored size. Only the held instance is fitted
	# to the space above the palms, leaving the explorer's face visible.
	var maximum := Vector2(48,24)*animated_sprite.scale.abs()
	for visual: Sprite2D in $CarriedModule.get_children():
		var size := Vector2(visual.texture.get_image().get_used_rect().size)*visual.scale.abs()
		var factor := minf(1.0,minf(maximum.x/maxf(size.x,0.001),maximum.y/maxf(size.y,0.001)))
		visual.scale *= factor


func _held_grip_offset(visual: Sprite2D) -> Vector2:
	var key := visual.get_instance_id()
	if not _grip_offsets.has(key):
		_grip_offsets[key] = visual.position+_sprite_grip(visual)*visual.scale
	return _grip_offsets[key]


func _sync_pickup_visual() -> void:
	if not is_instance_valid(_pickup_source) or not is_instance_valid(_pickup_held) or _action_committed: return
	var phase := action_elapsed/action_duration
	# Wait until the crouched hands reach the object, then lift into the grip.
	var progress := smoothstep(0.25,0.55,phase)
	var target := _pickup_held.global_transform
	target.origin = to_global(_carry_hand_position())-target.basis_xform(_sprite_grip(_pickup_source))
	_pickup_source.global_transform = _pickup_transform.interpolate_with(target,progress)
	if progress > 0:
		_pickup_source.z_index = 2


func _restore_pickup_visual() -> void:
	if is_instance_valid(_pickup_source):
		_pickup_source.global_transform = _pickup_transform
		_pickup_source.z_index = _pickup_z
		_pickup_source.get_parent().set_process(_pickup_processing)
	_pickup_source = null
	_pickup_held = null
