extends "res://touch_route.gd"

var region: String
var equipment: Array[Vector2] = []

func _supported(at: Vector2) -> bool:
	if world.access.region_at(at) != region:
		return false
	# Terrain geometry omits the independently mounted vessel colliders.
	for position in equipment:
		if at.distance_squared_to(position) < 3600:
			return world.valid_landing(at)
	return super._supported(at)
