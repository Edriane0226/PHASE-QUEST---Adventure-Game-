extends CharacterBody2D
## Saved homes/patrol markers constrain gentle wildlife to the authored world.
@export var species := "hare"
@export var speed := 34.0
@export var follow_seconds := 2.0
@export var hop_height := 5.0
@export var step_frequency := 9.0
var level: Node
var home := Vector2.ZERO
var target := Vector2.ZERO
var clock := 0.0
var decision := 0.0
var following := 0.0
var follow_cooldown := 0.0
var patrol_index := 0
var _facing := "south_east"
var _offscreen_clock := 0.0
var _visual_home := Vector2.ZERO


func _ready() -> void:
	level = get_parent().get_parent()
	home = position
	target = home
	_visual_home = $AnimatedSprite2D.position


func _physics_process(delta: float) -> void:
	if level.demonstration_mode or not is_instance_valid(level.player) or level.overview or level.dead or level.complete: return
	var distance: float = position.distance_to(level.player.position)
	if distance>1100:
		_offscreen_clock += delta
		if _offscreen_clock<0.25: return
		delta = _offscreen_clock
		_offscreen_clock = 0.0
	clock += delta
	decision -= delta
	following = maxf(0,following-delta)
	follow_cooldown = maxf(0,follow_cooldown-delta)
	var away: Vector2 = position-level.player.position
	if distance<85:
		velocity = away.normalized()*speed*1.4
		if follow_cooldown<=0 and species=="hare":
			following = follow_seconds
			follow_cooldown = 8.0
	elif species=="hare" and following>0 and distance<190 and position.distance_to(home)<210:
		velocity = -away.normalized()*speed*0.8
	else:
		if decision<=0 or position.distance_to(target)<12:
			decision = 2.3+float(get_index()%3)*0.4
			var markers := $Patrol.get_children()
			target = home+markers[patrol_index%markers.size()].position
			patrol_index += 1
		velocity = position.direction_to(target)*speed if position.distance_to(target)>12 else Vector2.ZERO
	var next := position+velocity*delta
	if not level.has_walkable_ground(next) or next.distance_to(home)>220:
		velocity = position.direction_to(home)*speed
	var before := position
	move_and_slide()
	if get_slide_collision_count()>0:
		decision = 0
		velocity = velocity.rotated(PI/2)
	# Use real travel, so a blocked animal does not run in place.
	var direction := (position-before)/maxf(delta,.001)
	if direction.length()>3:
		_facing = ("south_" if direction.y>=0 else "north_")+("east" if direction.x>=0 else "west")
	var action := "move" if direction.length()>3 else "idle"
	var animation := species+"_"+action+"_"+_facing
	if $AnimatedSprite2D.animation != animation: $AnimatedSprite2D.play(animation)
	# The saved poses contain the species-specific gait and hop arc.
	$AnimatedSprite2D.position = _visual_home
	$AnimatedSprite2D.speed_scale = clampf(direction.length()/speed,.65,1.4) if action=="move" else 1.0
