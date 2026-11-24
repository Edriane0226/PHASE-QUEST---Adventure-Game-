@tool
extends "res://Scripts/World/Zone1/Props/melting_prop.gd"
## Eight complete native atlas views keep the reflected ray tied to the visible face.
const VIEWS = [preload("res://assets/zones/zone_1/flat_v1/props/mirror_0.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_1.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_2.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_3.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_4.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_5.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_6.tres"),preload("res://assets/zones/zone_1/flat_v1/props/mirror_7.tres")]

func _set_mirror_frame(value: float) -> void:
	mirror_frame = value
	if is_instance_valid(rotor):
		rotor.texture = VIEWS[posmod(roundi(value),8)]

func beam_direction() -> Vector2:
	var angle := float(posmod(roundi(mirror_frame),8))*PI/4.0
	return Vector2(sin(angle),cos(angle)*0.5).normalized()
