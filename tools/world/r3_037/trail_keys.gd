extends Node

var owner_tree: SceneTree

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_F8:
		return
	var world := get_parent()
	if not world.player_controls_allowed() or world.player.carrying or owner_tree.trail.is_empty():
		return
	var xy: Array = owner_tree.trail[0]
	world.activate(world.active_subregion_id,Vector2(xy[0],xy[1]))
	print("Walk the marked trail in order ",owner_tree.trail)
	get_viewport().set_input_as_handled()
