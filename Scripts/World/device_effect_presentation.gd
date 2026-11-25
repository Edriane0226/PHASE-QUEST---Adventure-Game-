extends Node2D
## Read-only presentation of an authorized emitter shot. No target/world writes.
const SHIMMER = preload("res://assets/shaders/world/thermal_local_shimmer.gdshader")
const PARTICLE_LIMIT := 18
const TILE_LIMIT := 8
const RELEASE_DURATION := 0.17
var emitter: Node
var state := "idle"
var clock := 0.0
var elapsed := 0.0
var reduced := false
var particles: Array[Dictionary] = []
var _particle_pool: Array[Dictionary] = []
var frame: Dictionary = {}
var _model: Dictionary = {}
var _before_stop: Dictionary = {}
var _frozen := false
var _spawn := 0.0
var _serial := 0
var _anchors: Array = []
var _shimmers: Array[Sprite2D] = []
var sound: AudioStreamPlayer
var loop_stream: AudioStreamWAV
var last_update_usec := 0
var _release_audio_pending := false

func mode_id() -> String: return ""
func art_frames() -> SpriteFrames: return null
func atlas_texture() -> Texture2D: return null
func audio_clip(_phase: String) -> AudioStreamWAV: return null
func has_shimmer() -> bool: return false

func bind(owner_emitter: Node) -> void:
	emitter = owner_emitter
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 200
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_index = 1 # Explorer's head and grip occluders remain above the muzzle fan.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anchors = art_frames().get_meta("start_origins")
	sound = AudioStreamPlayer.new()
	sound.name = mode_id().capitalize()+"Voice"
	sound.max_polyphony = 1
	add_child(sound)
	loop_stream = audio_clip("loop").duplicate()
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = loop_stream.data.size()/2
	for i in PARTICLE_LIMIT:
		_particle_pool.append({"active":false,"age":0.0,"life":0.0,"fraction":0.0,"side":0.0,"seed":0})
	var pixel := Image.create(1,1,false,Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(pixel)
	for i in (2 if has_shimmer() else 0):
		var patch := Sprite2D.new()
		patch.texture = white
		var material := ShaderMaterial.new()
		material.shader = SHIMMER
		patch.material = material
		patch.visible = false
		add_child(patch)
		_shimmers.append(patch)
	emitter.shot_started.connect(_begin)
	emitter.shot_stopped.connect(_stop)
	visible = false

func _audio_allowed() -> bool:
	var audio := get_node_or_null("/root/GameAudio")
	return audio != null and audio.sfx_enabled and not audio.suspended and not audio.loading

func _paused() -> bool:
	return get_tree().paused or (is_instance_valid(emitter.source) and emitter.source.get("preview_paused") == true)

func _play(clip: AudioStream, gain: float) -> void:
	sound.stop()
	if not _audio_allowed(): return
	sound.stream = clip
	sound.volume_db = gain
	sound.play()

func _begin() -> void:
	var sample: Dictionary = emitter.snapshot()
	if sample.is_empty() or sample.mode != mode_id() or not sample.shot: return
	state = "start"
	clock = 0
	elapsed = 0
	_spawn = 0
	_clear_particles()
	_before_stop.clear()
	_frozen = false
	_release_audio_pending = false
	_model = sample
	_play(audio_clip("start"),-24)
	_refresh_frame()

func _stop(cause: String) -> void:
	if state == "idle" and frame.is_empty(): return
	if _before_stop.is_empty(): _before_stop = frame.duplicate(true)
	_clear_particles()
	_spawn = 0
	sound.stop()
	_release_audio_pending = false
	var sample: Dictionary = emitter.snapshot() if emitter.is_inside_tree() else {}
	if cause in ["release","verified","saved"] and not sample.is_empty() and sample.mode == mode_id():
		state = "release"
		elapsed = 0
		_model = sample
		# The level may save immediately before opening Pause. Defer only the
		# outro until the next gated presentation tick; stop the loop now.
		sound.stream = audio_clip("release")
		_release_audio_pending = true
		_refresh_frame()
	else:
		state = "idle"
		frame.clear()
		_present()

func clear() -> void:
	state = "idle"
	_clear_particles()
	frame.clear()
	_before_stop.clear()
	_frozen = false
	_release_audio_pending = false
	if sound != null: sound.stop()
	_present()

func _refresh_frame() -> void:
	frame = _model.duplicate()
	frame["stage"] = state
	frame["clock"] = clock
	frame["elapsed"] = elapsed
	frame["reduced"] = reduced
	frame["motes"] = particles.duplicate(true)
	_present()

func _present() -> void:
	visible = not frame.is_empty()
	for patch in _shimmers: patch.hide()
	if not frame.is_empty() and frame.stage == "sustain" and not frame.reduced:
		var axis: Vector2 = frame.point-frame.origin
		for i in _shimmers.size():
			var patch := _shimmers[i]
			patch.position = frame.origin+axis*(0.55 if i == 0 else 0.94)
			patch.scale = Vector2(18,10) if i == 0 else Vector2(12,12)
			patch.material.set_shader_parameter("effect_time",frame.clock)
			patch.show()
	queue_redraw()

func _process(delta: float) -> void:
	var begin := Time.get_ticks_usec()
	_tick_effects(delta)
	last_update_usec = Time.get_ticks_usec()-begin

func _tick_effects(delta: float) -> void:
	if not is_instance_valid(emitter) or not emitter.is_inside_tree(): clear(); return
	if _paused():
		if not _frozen:
			if not _before_stop.is_empty(): frame = _before_stop.duplicate(true)
			_frozen = true
			_clear_particles()
			sound.stop()
			_present()
		return # Explicit clock and shader uniform freeze; shader never uses TIME.
	if _frozen:
		clear() # Pause cleared input; never replay the frozen shot on resume.
		return
	_before_stop.clear()
	if _release_audio_pending:
		_release_audio_pending = false
		if state == "release": _play(audio_clip("release"),-27)
	if not _audio_allowed(): sound.stop()
	var next_reduced: bool = emitter.store.data.get("extras",{}).get("level1_reduced_effects",false)
	if next_reduced != reduced:
		reduced = next_reduced
		if reduced: _clear_particles()
	if state == "idle": return
	var sample: Dictionary = emitter.snapshot()
	if sample.is_empty() or sample.mode != mode_id(): clear(); return
	_model = sample
	var step := clampf(delta,0,0.05)
	clock += step
	elapsed += step
	if state in ["start","sustain"]:
		if not sample.shot: clear(); return
		if sample.active and state != "sustain":
			state = "sustain"
			elapsed = 0
			_play(loop_stream,-55)
		if state == "sustain":
			if sound.stream == loop_stream: sound.volume_db = lerpf(-55,-22,minf(elapsed/0.04,1))
			_update_particles(step)
	elif state == "release" and elapsed >= RELEASE_DURATION:
		clear()
		return
	_refresh_frame()

func _clear_particles() -> void:
	for mote in _particle_pool: mote.active = false
	particles.clear()

func _update_particles(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		particles[i].age += delta
		if particles[i].age >= particles[i].life:
			particles[i].active = false
			particles.remove_at(i)
	if reduced: return
	_spawn += delta*28
	var count := mini(floori(_spawn),4)
	_spawn -= count
	for i in count:
		if particles.size() >= PARTICLE_LIMIT: break
		_serial += 1
		for mote in _particle_pool:
			if mote.active: continue
			mote.active = true
			mote.age = 0.0
			mote.life = 0.24+(_serial%5)*0.035
			mote.fraction = 0.18+(_serial%7)*0.09
			mote.side = -1.0 if _serial%2 else 1.0
			mote.seed = _serial
			particles.append(mote)
			break

func _texture(row: int, index: int, rectangle: Rect2, tint := Color.WHITE, fraction := 1.0) -> void:
	draw_texture_rect_region(atlas_texture(),rectangle,Rect2(index%4*128,row*128,128*fraction,128),tint)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]:
		if is_instance_valid(sound): sound.stop()
		state = "idle"
		_clear_particles()
		frame.clear()
		_before_stop.clear()
		_frozen = false
		_release_audio_pending = false
		if is_inside_tree(): _present()
