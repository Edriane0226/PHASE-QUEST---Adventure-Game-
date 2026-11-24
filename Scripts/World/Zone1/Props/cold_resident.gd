@tool
extends Node2D
## Saved NPC presentation; scene owns artwork, footprint and placement.
@export var active := false
@export var warmed := false:
	set(value):
		warmed = value
		if is_node_ready(): _sync_pose()
var clock:=0.0
var sprite_home:=Vector2.ZERO
var breath_home:=Vector2.ZERO
func _ready() -> void:
	sprite_home=$AnimatedSprite2D.position
	if has_node("Breath"):breath_home=$Breath.position
	set_process(not Engine.is_editor_hint())
	_sync_pose()
func _sync_pose() -> void:
	$AnimatedSprite2D.play("warm" if warmed else "cold")
	if has_node("Breath"):$Breath.visible=not warmed
func _process(delta: float) -> void:
	clock+=delta
	$AnimatedSprite2D.position=sprite_home+Vector2(0 if warmed else sin(clock*29)*.3,0)
	if warmed or not has_node("Breath"):return
	var phase:=fmod(clock,2.3)/2.3
	$Breath.modulate.a=sin(phase*PI)*.6
	$Breath.position=breath_home+Vector2(phase*7,-phase*3)
