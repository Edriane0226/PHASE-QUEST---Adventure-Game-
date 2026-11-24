extends "res://Scripts/UI/mechanism_status.gd"
## Keep progress at its world object, with the saved crystal bar as needed.
func _process(delta: float) -> void:
	if not is_instance_valid(level): return
	clock += delta
	var live: bool = not level.overview and not level.complete and not level.dead and not get_tree().paused
	warning.visible = live and level.warmth<25
	warning.material.set_shader_parameter("strength",clampf((25-level.warmth)/15,.4,1))
	warning.material.set_shader_parameter("beat",pow(maxf(0,sin(clock*5)),3))
	tasks = collect_tasks() if live else []
	world_bars.queue_redraw()
	card.hide()
