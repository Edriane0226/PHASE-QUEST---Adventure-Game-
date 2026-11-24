extends "res://Scripts/World/device_effect_presentation.gd"
## Thermal artwork/rendering; shared lifecycle contains no science progression.
const ATLAS = preload("res://assets/effects/thermal/v1/atlas.png")
const ART = preload("res://assets/effects/thermal/v1/sprite_frames.tres")
const START = preload("res://assets/audio/Device/thermal_start.wav")
const LOOP = preload("res://assets/audio/Device/thermal_loop.wav")
const RELEASE = preload("res://assets/audio/Device/thermal_release.wav")
func mode_id() -> String: return "thermal"
func art_frames() -> SpriteFrames: return ART
func atlas_texture() -> Texture2D: return ATLAS
func audio_clip(phase: String) -> AudioStreamWAV: return {"start":START,"loop":LOOP,"release":RELEASE}[phase]
func has_shimmer() -> bool: return true

func _draw() -> void:
	if frame.is_empty(): return
	var axis: Vector2 = frame.point-frame.origin
	var length := axis.length()
	if length <= 0.01: return
	var angle := axis.angle()
	var small: bool = frame.reduced
	var tint := Color(1,0.92,0.74,0.88 if not small else 0.74)
	draw_set_transform(frame.origin,angle)
	if frame.stage == "start":
		var index := mini(floori(frame.elapsed*24),3)
		var anchor := Vector2(_anchors[index][0],_anchors[index][1])
		var size := 0.10 if small else 0.12
		_texture(0,index,Rect2(-anchor*size,Vector2.ONE*128*size),tint)
	elif frame.stage == "sustain":
		var tile_count := mini(ceili(length/14),TILE_LIMIT)
		for i in tile_count:
			var start := i*14.0
			var width := minf(20,length-start)
			var height := 16.0 if small else 28.0
			_texture(1,floori(frame.clock*16)+i,Rect2(start,-height/2,width,height),tint,width/20)
		var anchor := Vector2(_anchors[2][0],_anchors[2][1])
		_texture(0,2,Rect2(-anchor*0.065,Vector2.ONE*128*0.065),tint)
		if frame.target:
			var size := 16.0 if small else 26.0
			_texture(2,floori(frame.clock*16),Rect2(Vector2(length,0)-Vector2.ONE*size/2,Vector2.ONE*size),Color(1,1,1,0.65))
		for mote: Dictionary in frame.motes:
			var progress: float = mote.age/mote.life
			var distance := minf(length-1,length*mote.fraction+mote.age*22)
			var at := Vector2(maxf(0,distance),mote.side*sin(progress*PI)*2.4)
			_texture(3,3,Rect2(at-Vector2(1.5,1.5),Vector2(3,3)),Color(1,0.88,0.55,1-progress))
	elif frame.stage == "release":
		var index := mini(floori(frame.elapsed*24),3)
		var alpha: float = 1.0-frame.elapsed/RELEASE_DURATION
		_texture(3,index,Rect2(-2,-6,16,12),Color(1,1,1,alpha*0.7))
	draw_set_transform(Vector2.ZERO)

