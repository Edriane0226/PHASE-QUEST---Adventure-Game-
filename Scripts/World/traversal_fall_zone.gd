extends Polygon2D
## Add only to deliberately authored voids. Supporting surfaces override this void.
@export var active := true

func _ready() -> void:
	add_to_group("FallZones")
	visible = OS.has_feature("editor") and Engine.is_editor_hint()

func contains_point(world_position: Vector2) -> bool:
	return active and Geometry2D.is_point_in_polygon(to_local(world_position), polygon)
