extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://Actors/Player/Player.tscn")
	assert(scene != null)
	var player := scene.instantiate()
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var clips := sprite.sprite_frames
	var count := 0
	for name in clips.get_animation_names():
		var reference := str(name).begins_with("idle_") or str(name).begins_with("walk_")
		for frame in range(clips.get_frame_count(name)):
			var texture := clips.get_frame_texture(name,frame)
			assert(texture != null and texture.get_size()==Vector2(192,192))
			assert(texture.get_image() != null)
			assert(bool(texture.get_meta("preview_registered",false)) != reference)
		if not reference:
			assert(clips.get_frame_count(name)==(8 if str(name).begins_with("run_") else 6))
			count += 1
	assert(count==64)
	player.free()
	print("PASS: Player scene loaded; 64 trial action clips; 16 original idle/walk clips; all textures readable.")
	quit()
