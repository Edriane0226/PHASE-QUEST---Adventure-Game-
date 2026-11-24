extends Node2D
## Gentle motion around a saved home; all artwork and positions are scene-owned.
@export var orbit_radius := 12.0
@export var orbit_speed := 0.8
@export var phase := 0.0
var home := Vector2.ZERO
var clock := 0.0
var level: Node
func _ready() -> void:
	home=position
	level=get_parent().get_parent()
func _process(delta: float) -> void:
	if not is_instance_valid(level.player) or position.distance_squared_to(level.player.position)>1200000: return
	if level.demonstration_mode: return
	clock+=delta*orbit_speed*(0.5 if level.reduced_effects else 1.0)
	var offset:=Vector2(sin(clock+phase),cos(clock*0.73+phase)*0.45)*orbit_radius
	if level.has_walkable_ground(home+offset): position=home+offset
