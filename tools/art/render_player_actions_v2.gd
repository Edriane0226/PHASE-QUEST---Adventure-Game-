extends SceneTree

func _initialize() -> void:
	call_deferred("render_frames")

func render_frames() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size = Vector2i(1440,1200)
	var board := Node2D.new()
	root.add_child(board)
	var background := ColorRect.new()
	background.size=Vector2(1440,1200)
	background.color=Color("2b3037")
	board.add_child(background)
	var clips: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	var actions := ["idle","walk","run","carry_idle","carry_walk","jump","lift","place","touch","operate"]
	var directions := ["east","south_east","south","south_west","west","north_west","north","north_east"]
	for row in range(actions.size()):
		for col in range(directions.size()):
			var label := Label.new()
			label.text=actions[row]+" "+directions[col]
			label.add_theme_font_size_override("font_size",12)
			label.position=Vector2(col*180+5,row*120)
			board.add_child(label)
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames=clips
			sprite.animation=actions[row]+"_"+directions[col]
			sprite.frame=3 if row>1 else 0
			sprite.position=Vector2(col*180+90,row*120+68)
			sprite.scale=Vector2(.75,.75)
			var texture := clips.get_frame_texture(sprite.animation,sprite.frame)
			sprite.flip_h=texture.get_meta("mirror_walk",false)
			board.add_child(sprite)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := "res://output/player-actions-v2/godot-direction-review.png"
	if "--generated-colors" in OS.get_cmdline_user_args():
		destination="res://output/player-black-hair-sprites/godot-generated-sprite-review.png"
	if "--palette-fix" in OS.get_cmdline_user_args():
		destination="res://output/player-palette-size-fix/godot-direction-review.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var result := root.get_texture().get_image().save_png(destination)
	assert(result==OK)
	print("Saved Godot-rendered directional review.")
	quit()
