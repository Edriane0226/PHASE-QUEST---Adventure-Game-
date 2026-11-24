extends Node2D
## Sort/collision anchor stays at ground position; artwork alone receives height offset.
var visuals: Node2D
@export var elevation:=0.0:
	set(value):
		if not is_finite(value):return
		elevation=value
		if is_instance_valid(visuals):visuals.position=Vector2(0,-elevation)
func _init() -> void:
	visuals=Node2D.new();visuals.name="Visuals";add_child(visuals)
