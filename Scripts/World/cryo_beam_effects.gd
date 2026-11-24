extends "res://Scripts/World/device_effect_presentation.gd"
## Cryo visualization: heat-removal motes and frost follow qualified contact only.
const ATLAS = preload("res://assets/effects/cryo/v1/atlas.png")
const ART = preload("res://assets/effects/cryo/v1/sprite_frames.tres")
const START = preload("res://assets/audio/Device/cryo_start.wav")
const LOOP = preload("res://assets/audio/Device/cryo_loop.wav")
const RELEASE = preload("res://assets/audio/Device/cryo_release.wav")
func mode_id() -> String: return "cryo"
func art_frames() -> SpriteFrames: return ART
func atlas_texture() -> Texture2D: return ATLAS
func audio_clip(phase: String) -> AudioStreamWAV: return {"start":START,"loop":LOOP,"release":RELEASE}[phase]

func _draw() -> void:
	if frame.is_empty(): return
	var axis: Vector2 = frame.point-frame.origin
	var length := axis.length()
	if length <= 0.01: return
	var small: bool = frame.reduced
	draw_set_transform(frame.origin,axis.angle())
	var tint := Color(0.84,0.95,1,0.76)
	if frame.stage == "start":
		var index := mini(floori(frame.elapsed*24),3)
		var anchor := Vector2(_anchors[index][0],_anchors[index][1])
		var scale := 0.075 if small else 0.10
		_texture(0,index,Rect2(-anchor*scale,Vector2.ONE*128*scale),tint)
	elif frame.stage == "sustain":
		for i in mini(ceili(length/14),TILE_LIMIT):
			var start := i*14.0
			var width := minf(20,length-start)
			var height := 12.0 if small else 22.0
			_texture(1,floori(frame.clock*16)+i,Rect2(start,-height/2,width,height),tint,width/20)
		if frame.target:
			for mote: Dictionary in frame.motes:
				var progress: float = mote.age/mote.life
				# Heat leaves the sample, opposite the outgoing instrument beam.
				var distance := clampf(length*(1-mote.fraction)-mote.age*22,0,length)
				var at := Vector2(distance,mote.side*sin(progress*PI)*3)
				_texture(3,3,Rect2(at-Vector2.ONE*2,Vector2.ONE*4),Color(0.8,0.94,1,(1-progress)*0.65))
	elif frame.stage == "release":
		var index := mini(floori(frame.elapsed*24),3)
		_texture(3,index,Rect2(-2,-5,14,10),Color(0.8,0.95,1,(1-frame.elapsed/RELEASE_DURATION)*0.7))
	draw_set_transform(Vector2.ZERO)
	if frame.stage == "sustain" and frame.target:
		var progress: float = clampf(frame.progress,0,1)
		var index := mini(floori(progress*4),3)
		var center: Vector2 = frame.get("sample_point",frame.point)
		var radius := clampf(float(frame.radius)*0.65,6,17)
		var opacity := (0.28+progress*0.32) if not small else 0.34
		_texture(2,index,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),Color(0.9,0.98,1,opacity))
