extends SceneTree
const RATE := 22050
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio/Footsteps/original_v1")
	DirAccess.make_dir_recursive_absolute("res://assets/ui/menu_accents/original_v1")
	for variant in range(3):
		var rng := RandomNumberGenerator.new();rng.seed=13051+variant*719
		var data := PackedByteArray();data.resize(int(RATE*0.48)*2)
		var low := 0.0
		for i in range(data.size()/2):
			var t := float(i)/RATE
			var noise := rng.randf_range(-1,1)
			low = lerpf(low,noise,0.11)
			var envelope := minf(t/0.006,1)*exp(-t*13)*minf((0.48-t)/0.07,1)
			var splash := low*0.8+noise*0.11+sin(TAU*(190+variant*21)*t+sin(TAU*33*t))*exp(-t*28)*0.18
			data.encode_s16(i*2,roundi(splash*envelope*0.65*32767))
		var wav := AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=RATE;wav.data=data
		assert(wav.save_to_wav("res://assets/audio/Footsteps/original_v1/wet_step_%d.wav"%variant)==OK)
	for variant in range(2):
		var img := Image.create(24,24,false,Image.FORMAT_RGBA8)
		for y in range(24):
			for x in range(24):
				var d := Vector2(x+0.5-12,y+0.5-12).length()
				var alpha := clampf((6.2+variant*0.7-d)/1.2,0,1)
				img.set_pixel(x,y,Color(1,0.98,0.9,alpha))
		assert(img.save_png("res://assets/ui/menu_accents/original_v1/dot_%d.png"%variant)==OK)
	print("R3 013 ORIGINAL REPLACEMENTS BUILD PASS / 3 wet steps / 2 menu dots")
	quit()
