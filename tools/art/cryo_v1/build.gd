extends SceneTree
## Reproducible packing of original imagegen artwork plus original periodic DSP.
const DEST := "res://assets/effects/cryo/v1/"
const AUDIO := "res://assets/audio/Device/"
const RATE := 22050

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)

func tone(t: float, phases: PackedFloat64Array) -> float:
	var value := 0.0
	for i in phases.size():
		var frequency := 180.0+i*13.5 # Integer cycles over the two-second loop.
		value += sin(TAU*frequency*t+phases[i])*0.025*exp(-frequency/1200.0)
	return value+sin(TAU*330*t)*0.06+sin(TAU*495*t)*0.025

func make_audio() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9010
	var phases := PackedFloat64Array()
	for i in 100: phases.append(rng.randf()*TAU)
	for kind in ["start","loop","release"]:
		var duration: float = {"start":0.14,"loop":2.0,"release":0.12}[kind]
		var count := roundi(duration*RATE)
		var data := PackedByteArray()
		data.resize(count*2)
		for i in count:
			var t := float(i)/RATE
			var sample := tone(t,phases)
			if kind != "loop":
				var edge := minf(t/0.012,1)*minf((duration-t)/0.025,1)
				sample *= edge*(sin(PI*t/duration) if kind == "start" else exp(-t*18))
			data.encode_s16(i*2,roundi(clampf(sample,-0.65,0.65)*32767))
		if kind == "loop":
			# Rotate a periodic waveform to a smooth adjacent-sample boundary.
			# No duplicated endpoint, gap, crossfade dip or accumulating drift.
			var seam := 0
			var difference := INF
			for i in range(1,count):
				var distance := absf(data.decode_s16(i*2)-data.decode_s16((i-1)*2))
				if distance < difference:
					difference = distance
					seam = i
			data = data.slice(seam*2)+data.slice(0,seam*2)
		var clip := AudioStreamWAV.new()
		clip.format = AudioStreamWAV.FORMAT_16_BITS
		clip.mix_rate = RATE
		clip.data = data
		assert(clip.save_to_wav(AUDIO+"cryo_"+kind+".wav") == OK)
		var config := ConfigFile.new()
		var path: String = AUDIO+"cryo_"+kind+".wav.import"
		if config.load(path) != OK:
			config.set_value("remap","importer","wav")
			config.set_value("remap","type","AudioStreamWAV")
			config.set_value("deps","source_file",AUDIO+"cryo_"+kind+".wav")
		config.set_value("params","compress/mode",0)
		assert(config.save(path) == OK)

func make_sample() -> void:
	var source := Image.load_from_file("res://tools/art/cryo_v1/source-sample.png")
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(256,256,false,Image.FORMAT_RGBA8)
	var resource := "[gd_resource type=\"SpriteFrames\" load_steps=6 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/effects/cryo/v1/sample_atlas.png\" id=\"atlas\"]\n"
	var frames: Array[String] = []
	for i in 4:
		var low := Vector2i(roundi(source.get_width()*(i%2)/2.0),roundi(source.get_height()*(i/2)/2.0))
		var high := Vector2i(roundi(source.get_width()*((i%2)+1)/2.0),roundi(source.get_height()*((i/2)+1)/2.0))
		var image := source.get_region(Rect2i(low,high-low))
		image.resize(128,128,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(image,Rect2i(0,0,128,128),Vector2i(i%2*128,i/2*128))
		resource += "\n[sub_resource type=\"AtlasTexture\" id=\"s%d\"]\natlas = ExtResource(\"atlas\")\nregion = Rect2(%d, %d, 128, 128)\nfilter_clip = true\n" % [i,i%2*128,i/2*128]
		frames.append('{"duration":1.0,"texture":SubResource("s%d")}' % i)
	assert(atlas.save_png(DEST+"sample_atlas.png") == OK)
	write_text(DEST+"sample_frames.tres",resource+'\n[resource]\nanimations = [{"frames":['+",".join(frames)+'],"loop":false,"name":&"sample","speed":1.0}]\n')

func _initialize() -> void:
	var source := Image.load_from_file("res://tools/art/cryo_v1/source-atlas.png")
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(512,512,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var manifest := {"version":1,"source_size":[source.get_width(),source.get_height()],"cell":128,"rows":["start","stream","impact","release"],"fps":[24,16,16,24],"start_origins":[]}
	var source_origins := [Vector2(120,180),Vector2(413,180),Vector2(708,180),Vector2(1007,180)]
	for row in 4:
		for column in 4:
			var low := Vector2i(roundi(source.get_width()*column/4.0),roundi(source.get_height()*row/4.0))
			var high := Vector2i(roundi(source.get_width()*(column+1)/4.0),roundi(source.get_height()*(row+1)/4.0))
			var image := source.get_region(Rect2i(low,high-low))
			image.resize(128,128,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(image,Rect2i(0,0,128,128),Vector2i(column*128,row*128))
			if row == 0:
				var anchor: Vector2 = (source_origins[column]-Vector2(low))/Vector2(high-low)*128
				manifest.start_origins.append([anchor.x,anchor.y])
	assert(atlas.save_png(DEST+"atlas.png") == OK)
	write_text(DEST+"manifest.json",JSON.stringify(manifest,"\t")+"\n")
	var resource := "[gd_resource type=\"SpriteFrames\" load_steps=18 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/effects/cryo/v1/atlas.png\" id=\"atlas\"]\n"
	var animations: Array[String] = []
	for row in 4:
		var frames: Array[String] = []
		for index in 4:
			var id := "f%d_%d" % [row,index]
			resource += "\n[sub_resource type=\"AtlasTexture\" id=\"%s\"]\natlas = ExtResource(\"atlas\")\nregion = Rect2(%d, %d, 128, 128)\nfilter_clip = true\n" % [id,index*128,row*128]
			frames.append('{"duration":1.0,"texture":SubResource("%s")}' % id)
		animations.append('{"frames":[%s],"loop":%s,"name":&"%s","speed":%d}' % [",".join(frames),"true" if row in [1,2] else "false",manifest.rows[row],manifest.fps[row]])
	resource += "\n[resource]\nanimations = [%s]\nmetadata/start_origins = %s\n" % [",\n".join(animations),JSON.stringify(manifest.start_origins)]
	write_text(DEST+"sprite_frames.tres",resource)
	make_audio()
	make_sample()
	print("CRYO V1 BUILT / 16 alpha-preserved sprites / 3 original PCM clips / exact 2s periodic loop")
	quit()
