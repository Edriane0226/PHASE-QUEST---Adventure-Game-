extends SceneTree
const BASE_SCALE := 0.2923077
func bounds(texture: Texture2D) -> Rect2:
	var image := texture.get_image()
	var lo := Vector2i(image.get_width(),image.get_height())
	var hi := Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a > 0.97:
				lo = lo.min(Vector2i(x,y))
				hi = hi.max(Vector2i(x,y))
	return Rect2(Vector2(lo),Vector2(hi-lo+Vector2i.ONE))
func _initialize():
	var frames: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	var sheets := {
		"locomotion_north_south.png": ["walk_south","walk_north","run_south","run_north"],
		"locomotion_south_diagonal.png": ["walk_south_east","walk_south_west","run_south_east","run_south_west"],
		"locomotion_north_diagonal.png": ["walk_north_east","walk_north_west","run_north_east","run_north_west"],
		"walk_side_corrected.png": ["walk_east"],
		"run_side_corrected.png": ["run_east"],
	}
	for file in sheets:
		var atlas: Texture2D = load("res://assets/characters/cast/explorer/"+file)
		var clips: Array = sheets[file]
		var cell := atlas.get_size()/Vector2(4,clips.size())
		for row in clips.size():
			# Walk is maintained independently by build_explorer_walk.gd.
			if str(clips[row]).begins_with("walk_"): continue
			var textures: Array[AtlasTexture] = []
			var sizes: Array[Rect2] = []
			var heights: Array[float] = []
			for column in 4:
				var texture := AtlasTexture.new()
				texture.atlas = atlas
				texture.region = Rect2(Vector2(column,row)*cell,cell)
				texture.filter_clip = true
				textures.append(texture)
				var rect := bounds(texture)
				sizes.append(rect)
				heights.append(rect.size.y)
			heights.sort()
			# Fixed scale across each cycle preserves anatomy; register each planted boot.
			var scale := 40.0/((heights[1]+heights[2])*0.5)
			frames.clear(clips[row])
			for i in 4:
				textures[i].set_meta("pose_scale",scale/BASE_SCALE)
				textures[i].set_meta("pose_home",Vector2(1.0-(sizes[i].get_center().x-cell.x/2)*scale,4.2-(sizes[i].end.y-1-cell.y/2)*scale))
				frames.add_frame(clips[row],textures[i])
			print(clips[row]," heights ",heights," scale ",scale)
	for action in ["run"]:
		frames.clear(action+"_west")
		for i in 4: frames.add_frame(action+"_west",frames.get_frame_texture(action+"_east",i))
	var result := ResourceSaver.save(frames,"res://assets/characters/cast/explorer/frames.tres")
	print("INSTALL LOCOMOTION ",result)
	quit(result)
