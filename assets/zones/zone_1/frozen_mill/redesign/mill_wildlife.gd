extends Node2D

@export var flying := false
var elapsed := 0.0

func _ready() -> void:
	elapsed = fposmod(position.x + position.y, 12.0)

func _process(delta: float) -> void:
	var level = get_tree().current_scene
	var halted: bool = get_tree().paused or bool(level.get("preview_paused"))
	for child in get_children():
		if child is AnimatedSprite2D:
			child.speed_scale = 0.0 if halted else 1.0
	if halted: return
	elapsed += delta
	if flying:
		for index in get_child_count():
			var phase := elapsed * 1.65 + index * 2.1
			get_child(index).position = Vector2(index * 12 + cos(phase) * 8, sin(phase * 1.6) * 6 - index * 4)
	else:
		var hare := get_child(0) as AnimatedSprite2D
		var cycle := fmod(elapsed, 8.0)
		var leg := fmod(cycle, 4.0)
		var progress := clampf(leg / 1.2, 0.0, 1.0)
		hare.flip_h = cycle >= 4.0
		hare.position = Vector2(lerpf(13.0, -13.0, progress) if hare.flip_h else lerpf(-13.0, 13.0, progress), -absf(sin(progress * TAU)) * 5.0)
		hare.speed_scale = 1.0 if leg < 1.2 else 0.0
		if leg >= 1.2:
			hare.frame = 0
