class_name PlayerModel
extends CharacterBody2D

## 8-directional top-down player controller for the Phase Explorer sprite set.
## Sprite frames follow the naming: "idle_<direction>" / "run_<direction>"
## where <direction> is one of the 8 compass points (east, south_east, ...).

@export var move_speed: float = 120.0
@export var sprint_multiplier: float = 1.6
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Compass directions starting at east (0 deg) and going clockwise,
# matching Godot's 2D screen-space angle (y points down).
const DIRECTIONS: Array[String] = [
	"east", "south_east", "south", "south_west",
	"west", "north_west", "north", "north_east",
]

var _step_distance := 0.0
var _facing: String = "south"
var touch_movement: Vector2 = Vector2.ZERO
var touch_sprinting := false
var _movement_phase := 0.0

func set_touch_sprinting(value: bool) -> void:
	touch_sprinting = value

func movement_speed() -> float:
	return move_speed*(sprint_multiplier if touch_sprinting or Input.is_action_pressed("sprint") else 1.0)

func set_touch_movement(value: Vector2) -> void:
	touch_movement = value.limit_length(1.0)

func reset_touch_movement() -> void:
	touch_sprinting = false
	touch_movement = Vector2.ZERO
	velocity = Vector2.ZERO

func movement_input() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return touch_movement if touch_movement.length_squared()>keyboard.length_squared() else keyboard

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
		reset_touch_movement()


func _physics_process(delta: float) -> void:
	var input_dir := movement_input()

	if input_dir != Vector2.ZERO:
		_facing = _direction_from_vector(input_dir)
		velocity = velocity.move_toward(input_dir * movement_speed(), acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var before := position
	move_and_slide()
	_step_distance += position.distance_to(before)
	if _step_distance >= 32.0:
		_step_distance = fmod(_step_distance,32.0)
		var audio := get_node_or_null("/root/GameAudio")
		if audio != null:
			var level := get_tree().current_scene
			var surface := "snow"
			if level!=null and level.has_method("footstep_surface"):
				surface = level.footstep_surface(global_position)
			audio.play_footstep(surface)
	_update_animation(position.distance_to(before))


func _update_animation(travelled: float = 0.0) -> void:
	var moving := velocity.length() > 5.0
	var action := "idle"
	if moving:
		action = "run" if velocity.length()>move_speed*1.2 else "walk"
	var anim := action+"_"+_facing
	if not animated_sprite.sprite_frames.has_animation(anim):
		anim = "run_"+_facing if moving else "idle_"+_facing
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	if not moving:
		_movement_phase = 0.0
		return
	# Ground travel, rather than a free-running timer, drives movement poses.
	var cycle := 48.0 if action=="run" else 32.0
	_movement_phase = fposmod(_movement_phase+maxf(0,travelled)/cycle,1.0)
	animated_sprite.pause()
	var cursor := _movement_phase*animated_sprite.sprite_frames.get_frame_count(anim)
	animated_sprite.set_frame_and_progress(floori(cursor),fposmod(cursor,1.0))


func _authored_gait_distance(fallback: float) -> float:
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation,0)
	return maxf(1.0,float(texture.get_meta("gait_cycle_pixels",fallback / maxf(absf(animated_sprite.scale.x),0.001)))*absf(animated_sprite.scale.x))


func _direction_from_vector(v: Vector2) -> String:
	var index := int(round(rad_to_deg(v.angle()) / 45.0)) % 8
	return DIRECTIONS[index]
