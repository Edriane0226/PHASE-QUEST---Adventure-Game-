extends Node2D
## The editable Visuals child is offset independently from the sort anchor.
@export var elevation := 0.0:
	set(value):
		if not is_finite(value):return
		elevation = value
		if is_instance_valid(visuals):visuals.position.y = -elevation

@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	visuals.position.y = -elevation
