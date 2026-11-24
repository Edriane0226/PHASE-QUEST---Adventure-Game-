extends SceneTree
## Deterministic packing of the preserved imagegen atlas. No player edits.
const SOURCE := "res://tools/art/phase_device_v1/source-clean-alpha.png"
const DEST := "res://assets/devices/phase_device/v1/"
const DIRS := ["east","south_east","south","south_west","west","north_west","north","north_east"]
const HELD_GRIPS := [Vector2(22.5,39),Vector2(22.5,36.5),Vector2(27.5,32),Vector2(37.5,36.5),Vector2(38.5,40.5),Vector2(32.5,41),Vector2(28.5,44.5),Vector2(30,41)]
const HELD_MUZZLES := [Vector2(45.6,30),Vector2(39.8,38),Vector2(28.5,40),Vector2(18,37.8),Vector2(18.1,30),Vector2(23.5,19.5),Vector2(28.5,16),Vector2(37.6,20.6)]
const HOLSTER_GRIPS := [Vector2(22,20.8),Vector2(22,19.2),Vector2(24,20),Vector2(33,19.2),Vector2(39.4,19),Vector2(38.6,19),Vector2(30.8,26.8),Vector2(25,22)]
const BELT_ANCHORS := [Vector2(27,31),Vector2(28,31),Vector2(29,31),Vector2(35,31),Vector2(36,31),Vector2(35,31),Vector2(30,32),Vector2(27,31)]
const SCALE := 0.34

func pair(value: Vector2) -> Array:
	return [value.x,value.y]

func visible_bounds(image: Image) -> Rect2i:
	var low := image.get_size()
	var high := Vector2i(-1,-1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a > 0.9:
				low = low.min(Vector2i(x,y))
				high = high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE)

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(source != null and source.get_width() == source.get_height())
	source.convert(Image.FORMAT_RGBA8)
	var source_cell := float(source.get_width())/4.0
	var atlas := Image.create(256,256,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var metadata := {"version":1,"atlas":"res://assets/devices/phase_device/v1/atlas.png", "cell_size":[64,64],
		"sprite_origin":"top_left", "world_scale":SCALE, "direction_order":DIRS,
		"holstered_emission":false, "source_atlas":SOURCE,"views":{},
		"player_baseline_hashes":{}, "attachment_integration":"pending_R2_004",
		"recommended_shader":"res://assets/shaders/world/level1_flat_cutout.gdshader",
		"visible_bounds_alpha_threshold":0.9}
	for path: String in ["res://Actors/Player/Player.tscn","res://assets/characters/cast/explorer/frames.tres","res://Actors/Player/campaign_player.gd"]:
		metadata.player_baseline_hashes[path] = FileAccess.get_sha256(path)
	var resource := "[gd_resource type=\"SpriteFrames\" load_steps=18 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/devices/phase_device/v1/atlas.png\" id=\"1_atlas\"]\n"
	var animations: Array[String] = []
	for stance: String in ["held","holstered"]:
		for index in 8:
			var row: int = index/4 + (0 if stance == "held" else 2)
			var column := index % 4
			var start := Vector2i(roundi(column*source_cell),roundi(row*source_cell))
			var end := Vector2i(roundi((column+1)*source_cell),roundi((row+1)*source_cell))
			var image := source.get_region(Rect2i(start,end-start))
			image.resize(64,64,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(image,Rect2i(0,0,64,64),Vector2i(column*64,row*64))
			var id: String = stance + "_" + DIRS[index]
			var grip: Vector2 = HELD_GRIPS[index] if stance == "held" else HOLSTER_GRIPS[index]
			var muzzle: Vector2 = HELD_MUZZLES[index] if stance == "held" else Vector2(31,43)
			var direction := Vector2.RIGHT.rotated(index*PI/4)
			var bounds := visible_bounds(image)
			metadata.views[id] = {"region":[column*64,row*64,64,64],"grip_px":pair(grip),"muzzle_px":pair(muzzle),
				"belt_px":pair(BELT_ANCHORS[index]),"aim_direction":pair(direction),"can_emit":stance == "held",
				"muzzle_occluded_by_holster":stance == "holstered", "body_layer":-1 if stance == "holstered" and index in [3,4,5] else 1,
				"visible_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]}
			resource += "\n[sub_resource type=\"AtlasTexture\" id=\""+id+"\"]\natlas = ExtResource(\"1_atlas\")\nregion = Rect2(%d, %d, 64, 64)\nfilter_clip = true\n" % [column*64,row*64]
			resource += "metadata/grip_px = Vector2(%s, %s)\nmetadata/muzzle_px = Vector2(%s, %s)\nmetadata/aim_direction = Vector2(%s, %s)\nmetadata/can_emit = %s\nmetadata/world_scale = %s\n" % [grip.x,grip.y,muzzle.x,muzzle.y,direction.x,direction.y,"true" if stance == "held" else "false",SCALE]
			resource += "metadata/belt_px = Vector2(%s, %s)\nmetadata/body_layer = %d\nmetadata/muzzle_occluded_by_holster = %s\n" % [BELT_ANCHORS[index].x,BELT_ANCHORS[index].y,metadata.views[id].body_layer,"true" if stance == "holstered" else "false"]
			animations.append('{"frames":[{"duration":1.0,"texture":SubResource("%s")}],"loop":false,"name":&"%s","speed":1.0}' % [id,id])
			print(id," source=",source.get_size()," bounds=",image.get_used_rect()," grip alpha=",image.get_pixelv(Vector2i(grip)).a," muzzle alpha=",image.get_pixelv(Vector2i(muzzle)).a)
	assert(atlas.save_png(DEST+"atlas.png") == OK)
	var json := FileAccess.open(DEST+"sockets.json",FileAccess.WRITE)
	json.store_string(JSON.stringify(metadata,"\t"))
	json.close()
	var frames := FileAccess.open(DEST+"sprite_frames.tres",FileAccess.WRITE)
	frames.store_string(resource+"\n[resource]\nanimations = ["+",\n".join(animations)+"]\n")
	frames.close()
	print("PHASE DEVICE ATLAS PACKED: 16 views, original alpha preserved; player unchanged")
	quit()
