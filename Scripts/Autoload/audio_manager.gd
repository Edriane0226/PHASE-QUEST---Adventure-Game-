extends Node
## Persistent, bounded audio playback. Original synthesized score and effects.
const RATE := 22050
const WET_STEPS := [
	preload("res://assets/audio/Footsteps/original_v1/wet_step_0.wav"),
	preload("res://assets/audio/Footsteps/original_v1/wet_step_1.wav"),
	preload("res://assets/audio/Footsteps/original_v1/wet_step_2.wav"),
]
var music_enabled := true
var sfx_enabled := true
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var tracks: Dictionary = {}
var context := ""
var last_played: Dictionary = {}
var suspended := false
var loading := false
var scan_elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load("user://audio.cfg") == OK:
		music_enabled = bool(config.get_value("audio","music",true))
		sfx_enabled = bool(config.get_value("audio","sfx",true))
	music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	music.volume_db = -16.0
	add_child(music)
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		voice.name = "SoundEffect%d"%i
		voice.volume_db = -17.0
		add_child(voice)
		voices.append(voice)
	for entry in [["hover",[880.0],0.045],["click",[660.0,880.0],0.06], ["interact",[330.0,440.0],0.09], ["collect",[659.25,830.61,987.77],0.13], ["melt",[440.0,587.33,783.99],0.22], ["ignite",[130.81,196.0,261.63],0.14], ["rotate",[220.0,293.66],0.08], ["page",[523.25,659.25],0.08], ["waypoint",[392.0,523.25,783.99],0.18], ["warning",[220.0,196.0],0.20], ["fail",[392.0,293.66,196.0],0.26], ["win",[523.25,659.25,783.99,1046.5],0.22], ["step",[95.0],0.055]]:
		clips[entry[0]] = _sequence(entry[1],float(entry[2]))
	for bell in [["bell_low",261.63], ["bell_middle",329.63], ["bell_high",392.0]]:
		clips[bell[0]] = _bell(bell[1])
	for cue in ["thaw","melting","heater","vent"]:
		clips[cue] = _texture_sound(cue)
	clips["melt"] = _texture_sound("melt_finish")
	for surface in ["snow","cement"]:
		for variant in range(3):
			clips["step_%s%d"%[surface,variant]] = _footstep_sound(surface,variant)
	for variant in range(WET_STEPS.size()):
		clips["step_water%d"%variant] = WET_STEPS[variant]
	tracks["menu"] = _score(false)
	tracks["world"] = _score(true)
	get_tree().node_added.connect(_node_added)
	_wire_tree(get_tree().root)

func _sequence(notes: Array, beat: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(notes.size()*beat*RATE)*2)
	for i in range(data.size()/2):
		var t := float(i)/RATE
		var local := fmod(t,beat)
		var frequency := float(notes[mini(int(t/beat),notes.size()-1)])
		var envelope := minf(local/0.008,1.0)*pow(1.0-local/beat,2)
		var sample := (sin(TAU*frequency*t)+0.18*sin(TAU*frequency*2*t))*envelope*0.55
		data.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	return _wav(data,false)

func _bell(frequency: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(0.72 * RATE) * 2)
	for i in range(data.size() / 2):
		var t := float(i) / RATE
		var phase := TAU * frequency * t
		var partials := sin(phase) * exp(-6.0*t) + 0.38*sin(phase*2.41)*exp(-11.0*t)
		var envelope := minf(t/0.004, 1.0) * minf((0.72-t)/0.035, 1.0)
		data.encode_s16(i*2, int(partials * envelope * 18000.0))
	return _wav(data, false)

func _score(world: bool) -> AudioStreamWAV:
	var source: AudioStreamWAV = preload("res://assets/audio/Music/zone1_snowy.wav") if world else preload("res://assets/audio/Music/adventure_theme.wav")
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Retained scores import as QOA: encoded byte count is not PCM frame count.
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)-1
	return stream

func _wav(data: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = data.size()/2-1
	return stream

func play(cue: String) -> void:
	if not sfx_enabled or suspended or not clips.has(cue):
		return
	var now := Time.get_ticks_msec()
	if now-int(last_played.get(cue,-1000)) < (110 if cue=="hover" else 45):
		return
	last_played[cue] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = clips[cue]
			voice.volume_db = -32.0 if cue.begins_with("step") else -17.0
			voice.pitch_scale = randf_range(0.93,1.07) if cue.begins_with("step") else 1.0
			voice.play()
			return

func play_footstep(surface: String) -> void:
	if surface not in ["snow","cement","water"]:
		surface = "snow"
	play("step_%s%d"%[surface,randi_range(0,2)])

func _footstep_sound(surface: String, variant: int) -> AudioStreamWAV:
	var duration := 0.24 if surface=="snow" else 0.10
	var data := PackedByteArray()
	data.resize(int(duration*RATE)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1607+variant*379
	var low := 0.0
	var soft := 0.0
	var grain := 0.0
	var grain_remaining := 0
	for i in range(data.size()/2):
		var t := float(i)/RATE
		var noise := rng.randf_range(-1.0,1.0)
		low = lerpf(low,noise,0.16)
		soft = lerpf(soft,noise,0.045)
		var attack := minf(t/(0.003 if surface=="cement" else 0.012),1.0)
		var sample := 0.0
		match surface:
			"snow":
				# Irregular compressed-snow grains, without pitched or periodic tones.
				if grain_remaining<=0:
					grain = rng.randf_range(0.18,1.0)
					grain_remaining = rng.randi_range(90,360)
				grain_remaining -= 1
				var crunch := (noise-low)*0.16+low*0.8
				sample = crunch*grain*exp(-t*15.0)+soft*1.1*exp(-t*32.0)
			"cement":
				# Short, firm heel tap with a little grit.
				sample = sin(TAU*145.0*t)*exp(-t*65.0)*0.55+noise*exp(-t*100.0)*0.38
		var fade := minf((duration-t)/0.02,1.0)
		data.encode_s16(i*2,int(clampf(sample*attack*fade,-1,1)*32767))
	return _wav(data,false)

func set_enabled(kind: String, enabled: bool) -> void:
	if kind=="music":
		music_enabled = enabled
		music.stream_paused = not enabled or suspended or loading
	else:
		sfx_enabled = enabled
		if not enabled:
			for voice in voices:
				voice.stop()
	var config := ConfigFile.new()
	config.set_value("audio","music",music_enabled)
	config.set_value("audio","sfx",sfx_enabled)
	config.save("user://audio.cfg")

func set_loading(value: bool) -> void:
	loading = value
	music.stream_paused = not music_enabled or suspended or loading

func _node_added(node: Node) -> void:
	_wire_instance.call_deferred(node.get_instance_id())

func _wire_instance(id: int) -> void:
	var node := instance_from_id(id) as Node
	if is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion(): _wire(node)

func _wire_tree(node: Node) -> void:
	_wire(node)
	for child in node.get_children():
		_wire_tree(child)

func _wire(node: Node) -> void:
	if not is_instance_valid(node) or node.has_meta("audio_wired"):
		return
	node.set_meta("audio_wired",true)
	if node is BaseButton:
		node.pressed.connect(func(): play("click"))
		node.mouse_entered.connect(func():
			if not node.disabled and node.is_visible_in_tree(): play("hover")
		)
		node.focus_entered.connect(func(): play("hover"))
		if node is CheckButton and node.get_parent()!=null and node.get_parent().name in ["MusicLabel","SfxLabel"]:
			var kind := "music" if node.get_parent().name=="MusicLabel" else "sfx"
			node.set_pressed_no_signal(music_enabled if kind=="music" else sfx_enabled)
			node.toggled.connect(func(enabled: bool): set_enabled(kind,enabled))
	if node is LineEdit:
		node.text_changed.connect(func(_value: String): play("hover"))

func _process(delta: float) -> void:
	scan_elapsed += delta
	if scan_elapsed<0.2: return
	scan_elapsed = 0.0
	var scene := get_tree().current_scene
	var next := "world" if scene != null and scene.has_method("_interact") else "menu"
	if next!=context:
		context = next
		music.stream = tracks[context]
		music.play()
		music.stream_paused = not music_enabled or suspended or loading
	music.volume_db = -23.0 if get_tree().paused else -16.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false
	else:
		return
	if is_instance_valid(music): music.stream_paused = suspended or not music_enabled or loading
	for voice in voices:
		if suspended: voice.stop()

func _texture_sound(cue: String) -> AudioStreamWAV:
	var duration := 2.0 if cue in ["thaw","melting"] else 0.65
	var data := PackedByteArray()
	data.resize(int(duration*RATE)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8427
	var filtered := 0.0
	var crackle := 0.0
	var drip := 0.0
	for i in range(data.size()/2):
		var t := float(i)/RATE
		var noise := rng.randf_range(-1.0,1.0)
		filtered = lerpf(filtered,noise,0.12)
		var edge := minf(t/0.04,1.0)*minf((duration-t)/0.08,1.0)
		var sample := 0.0
		match cue:
			"thaw":
				var sparkle := pow(maxf(0.0,sin(TAU*4.0*t)),12.0)
				sample = filtered*0.35+sin(TAU*1320.0*t)*sparkle*0.13+noise*0.07
			"melting", "melt_finish":
				# Irregular ice fractures and soft wet drips, without pitched sweeps.
				if rng.randf()<0.00016:
					crackle = rng.randf_range(0.15,0.45)
				if rng.randf()<0.00012:
					drip = rng.randf_range(0.25,0.65)
				crackle *= 0.98
				drip *= 0.997
				sample = filtered*0.14+(noise-filtered)*crackle+filtered*drip*1.6
				if cue=="melt_finish":
					sample *= exp(-t*4.0)
			"heater":
				sample = (filtered*1.5+noise*0.18)*sin(PI*t/duration)+sin(TAU*75.0*t)*exp(-t*8.0)*0.25
			"vent":
				sample = filtered*sin(PI*t/duration)*0.9+sin(TAU*180.0*t)*exp(-fmod(t,0.12)*65.0)*0.17
		data.encode_s16(i*2,int(clampf(sample*edge,-1.0,1.0)*32767))
	return _wav(data,cue in ["thaw","melting"])
