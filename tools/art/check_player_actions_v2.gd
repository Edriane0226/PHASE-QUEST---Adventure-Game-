extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://Actors/Player/Player.tscn")
	var player := scene.instantiate()
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	player.set("animated_sprite",sprite)
	var saved_scale := sprite.scale
	var saved_home := sprite.position
	player.set("_saved_visual_scale",saved_scale)
	player.set("_saved_visual_home",saved_home)
	player.set("_visual_home",saved_home)
	var clips := sprite.sprite_frames
	var actions := 0
	var checked := 0
	for name in clips.get_animation_names():
		if str(name).begins_with("idle_") or str(name).begins_with("walk_"): continue
		actions += 1
		var count := clips.get_frame_count(name)
		assert(count==(8 if str(name).begins_with("run_") else 6))
		var direction := ""
		for d: String in player.DIRECTIONS:
			if str(name).ends_with("_"+d) and d.length()>direction.length():direction=d
		player.set("_facing",direction)
		sprite.animation = name
		for frame in range(count):
			sprite.frame = frame
			player.call("_normalize_pose")
			assert(sprite.scale==saved_scale,"Action changes player scale: "+str(name))
			assert(sprite.offset==Vector2.ZERO,"Legacy offset moves registered action: "+str(name))
			assert(sprite.position.is_equal_approx(saved_home),"Action causes home drift: "+str(name))
			var tex := clips.get_frame_texture(name,frame)
			assert(tex.get_size()==Vector2(192,192))
			assert(tex.get_image()!=null)
			assert(tex.get_meta("preview_registered",false))
			assert(tex.has_meta("hand_anchor"))
			checked += 1
	assert(actions==64)
	player.free()
	print("PASS: ",actions," action clips, ",checked," frames; original display scale/home retained; no legacy foot offsets.")
	quit()
