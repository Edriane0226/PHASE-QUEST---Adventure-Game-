extends Node2D
## Sort/collision anchor stays at ground position; artwork alone receives height offset.
const SNAP=preload("res://Scripts/World/Runtime/pixel_snap.gd")
var visuals: Node2D
@export var elevation:=0.0:
	set(value):
		if not is_finite(value):return
		elevation=value
		if is_instance_valid(visuals):visuals.position=Vector2(0,-elevation);SNAP.draw_whole(visuals)
func _init() -> void:
	visuals=Node2D.new();visuals.name="Visuals";add_child(visuals)
	set_notify_transform(true)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_READY,NOTIFICATION_TRANSFORM_CHANGED] and is_instance_valid(visuals):SNAP.draw_whole(visuals)
