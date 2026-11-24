extends SceneTree
const DIRS := ["east","south_east","south","south_west","west","north_west","north","north_east"]
func _initialize() -> void:
	var frames: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	var sheet := Image.create(1536,576,false,Image.FORMAT_RGBA8)
	for row in 3:
		var action: String = ["idle","walk","operate"][row]
		for col in 8:
			var texture := frames.get_frame_texture(action+"_"+DIRS[col],0 if row < 2 else 1)
			var image := texture.get_image()
			if texture.get_meta("mirror_walk",false): image.flip_x()
			sheet.blit_rect(image,Rect2i(0,0,192,192),Vector2i(col*192,row*192))
			print(action," ",DIRS[col]," size=",image.get_size()," palm=",texture.get_meta("hand_anchor",Vector2.ZERO)," home=",texture.get_meta("pose_home",Vector2.ZERO)," scale=",texture.get_meta("pose_scale",1.0))
	sheet.save_png("res://tools/art/phase_player_v1/current-reference.png")
	quit()
