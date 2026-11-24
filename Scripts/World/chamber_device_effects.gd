extends "res://Scripts/World/device_effect_presentation.gd"
## Directional chamber control: only qualified, sealed sample contacts get rings.
func ring_radius(time: float) -> float:
	var cycle := fposmod(time,0.72)/0.72
	return lerpf(23,11,cycle) if mode_id() == "pressure" else lerpf(9,23,cycle)

func particle_point(age: float, life: float, seed_value: int) -> Vector2:
	var progress := clampf(age/life,0,1)
	var radius := lerpf(15,4,progress) if mode_id() == "pressure" else lerpf(3,15,progress)
	return Vector2(cos(seed_value*2.4)*radius,sin(seed_value*2.4)*radius*0.65)

func _draw() -> void:
	if frame.is_empty(): return
	var axis: Vector2 = frame.point-frame.origin
	var length := axis.length()
	if length <= 0.01: return
	var tint := Color(0.89,0.78,1,0.72) if mode_id() == "pressure" else Color(0.66,1,0.89,0.76)
	var small: bool = frame.reduced
	draw_set_transform(frame.origin,axis.angle())
	if frame.stage == "start":
		var index := mini(floori(frame.elapsed*24),3)
		var anchor := Vector2(_anchors[index][0],_anchors[index][1])
		_texture(0,index,Rect2(-anchor*0.085,Vector2.ONE*128*0.085),tint)
	elif frame.stage == "sustain":
		# Spaced, illustrated control pulses: impact vocabulary stays at chamber.
		for i in mini(ceili(length/14),TILE_LIMIT):
			var start := i*14.0
			var width := minf(18,length-start)
			var height := 10.0 if small else 15.0
			_texture(1,floori(frame.clock*12)+i,Rect2(start,-height/2,width,height),Color(tint,0.45),width/18)
	elif frame.stage == "release":
		_texture(3,mini(floori(frame.elapsed*24),3),Rect2(-3,-6,14,12),Color(tint,(1-frame.elapsed/RELEASE_DURATION)*0.65))
	draw_set_transform(Vector2.ZERO)
	if frame.stage == "sustain" and frame.target and frame.get("chamber_qualified",false):
		var center: Vector2 = frame.get("sample_point",frame.point)
		# Two local rings at most, radius <=23; no global transform or prop effect.
		for i in (1 if small else 2):
			var radius := ring_radius(frame.clock+i*0.36)
			_texture(2,floori((frame.clock+i*0.36)*5.5),Rect2(center-Vector2(radius,radius*0.8),Vector2(radius*2,radius*1.6)),Color(tint,0.60 if not small else 0.48))
		for mote: Dictionary in frame.motes:
			var at: Vector2 = center+particle_point(mote.age,mote.life,mote.seed)
			_texture(3,3,Rect2(at-Vector2.ONE*1.6,Vector2.ONE*3.2),Color(tint,(1-mote.age/mote.life)*0.6))
