extends SceneTree
## Pack only the registered chamber state cells, preserving source artwork.
func _initialize() -> void:
	var source := Image.load_from_file("res://tools/art/chamber_v1/source-chamber.png")
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(256,256,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var resource := "[gd_resource type=\"SpriteFrames\" load_steps=6 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/effects/chamber/v1/atlas.png\" id=\"atlas\"]\n"
	var frames: Array[String] = []
	for i in 4:
		var low := Vector2i(roundi(source.get_width()*(i%2)/2.0),roundi(source.get_height()*(i/2)/2.0))
		var high := Vector2i(roundi(source.get_width()*((i%2)+1)/2.0),roundi(source.get_height()*((i/2)+1)/2.0))
		var image := source.get_region(Rect2i(low,high-low))
		image.resize(128,128,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(image,Rect2i(0,0,128,128),Vector2i(i%2*128,i/2*128))
		resource += "\n[sub_resource type=\"AtlasTexture\" id=\"s%d\"]\natlas = ExtResource(\"atlas\")\nregion = Rect2(%d, %d, 128, 128)\nfilter_clip = true\n" % [i,i%2*128,i/2*128]
		frames.append('{"duration":1.0,"texture":SubResource("s%d")}' % i)
	assert(atlas.save_png("res://assets/effects/chamber/v1/atlas.png") == OK)
	var file := FileAccess.open("res://assets/effects/chamber/v1/sprite_frames.tres",FileAccess.WRITE)
	file.store_string(resource+'\n[resource]\nanimations = [{"frames":['+",".join(frames)+'],"loop":false,"name":&"sample","speed":1.0}]\n')
	print("CHAMBER V1 BUILT / 4 sealed state sprites / immutable source")
	quit()
