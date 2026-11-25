extends Node2D
## The editable Visuals child is offset independently from the sort anchor.
const SNAP = preload("res://Scripts/World/Runtime/pixel_snap.gd")
@export var elevation := 0.0:
	set(value):
		if not is_finite(value):return
		elevation = value
		if is_instance_valid(visuals):
			visuals.position.y = -elevation
			SNAP.draw_whole(visuals)

@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	visuals.position.y = -elevation
	set_notify_transform(true)
	SNAP.draw_whole(visuals)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_instance_valid(visuals):
		SNAP.draw_whole(visuals)
