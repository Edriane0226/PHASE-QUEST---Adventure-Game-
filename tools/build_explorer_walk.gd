extends SceneTree
const DIRS = ["east","south_east","south","south_west","west","north_west","north","north_east"]
func _initialize():
	var frames: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	for dir in DIRS:
		var atlas: Texture2D = load("res://assets/characters/cast/explorer/walk_sprint_model/"+dir+".png")
		var cell = atlas.get_size()/Vector2(4,1)
		var poses = []
		var boxes = []
		for i in 4:
			var pose = AtlasTexture.new()
			pose.atlas = atlas
			pose.region = Rect2(Vector2(cell.x*i,0),cell)
			pose.filter_clip = true
			poses.append(pose)
			var img = pose.get_image()
			var lo = Vector2i(img.get_width(),img.get_height())
			var hi = Vector2i.ZERO
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x,y).a>0.97:
						lo=lo.min(Vector2i(x,y))
						hi=hi.max(Vector2i(x,y))
			boxes.append(Rect2i(lo,hi-lo+Vector2i.ONE))
		var scale_factor = 0.32
		var clip = "walk_"+dir
		frames.clear(clip)
		for i in 4:
			poses[i].set_meta("pose_scale",scale_factor/0.2923077)
			poses[i].set_meta("pose_home",Vector2(1,4.2-(boxes[i].end.y-1-cell.y/2)*scale_factor))
			poses[i].set_meta("mirror_walk",false)
			frames.add_frame(clip,poses[i])
	for clip in frames.get_animation_names():
		for i in frames.get_frame_count(clip):
			assert(frames.get_frame_texture(clip,i)!=null)
	print("Checked ",frames.get_animation_names().size()," clips")
	quit(ResourceSaver.save(frames,"res://assets/characters/cast/explorer/frames.tres"))
