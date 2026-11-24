extends Control
## Original vector medallions. Hidden discoveries use a neutral question mark.
var kind := "hidden"
var earned := false
var ink := Color("493b45")

func _ready() -> void:
	custom_minimum_size = Vector2(60,60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 64.0
	draw_set_transform(size * 0.5, 0, Vector2.ONE * scale_factor)
	ink = Color("493b45") if earned else Color("687b83")
	draw_circle(Vector2.ZERO, 29, Color("efc66c") if earned else Color("d9e0d9"))
	draw_arc(Vector2.ZERO, 28, 0, TAU, 48, ink, 1.5, true)
	match kind:
		"ice", "cartridge", "module":
			draw_style_box(preload("res://Scripts/UI/quest_ui.gd").frame(Color("9bd3de"),false), Rect2(-15,-15,30,30))
			_line(Vector2(-10,8),Vector2(10,-8))
		"fan":
			for i in range(3):
				var angle := TAU * i / 3.0
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(19,0).rotated(angle), Vector2(7,13).rotated(angle)]),ink)
			draw_circle(Vector2.ZERO,4,Color("fff0cb"))
		"light", "sun_seal":
			draw_circle(Vector2.ZERO,9,ink)
			for i in range(8):
				var direction := Vector2.RIGHT.rotated(TAU*i/8.0)
				_line(direction*13,direction*21)
		"steps":
			_line(Vector2(-20,16),Vector2(-5,16))
			_line(Vector2(-5,16),Vector2(-5,0))
			_line(Vector2(-5,0),Vector2(10,0))
			_line(Vector2(10,0),Vector2(10,-16))
			_line(Vector2(10,-16),Vector2(23,-16))
		"arrows", "loop", "transfer", "retry":
			draw_arc(Vector2.ZERO,16,-PI*0.9,PI*0.6,24,ink,3,true)
			_arrow(Vector2(-12,-10),Vector2(8,-10))
			_arrow(Vector2(12,10),Vector2(-8,10))
		"drop", "tray", "boiler", "dual":
			if kind != "drop":
				_line(Vector2(-18,0),Vector2(-14,15))
				_line(Vector2(-14,15),Vector2(14,15))
				_line(Vector2(14,15),Vector2(18,0))
			if kind in ["boiler","dual"]:
				for point in [Vector2(-8,5),Vector2(7,9),Vector2(0,-4)]:
					draw_arc(point,3,0,TAU,16,ink,2,true)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(-7,-6),Vector2(7,-6)]),ink)
				draw_circle(Vector2(0,-5),7,ink)
		"frost", "snow_seal", "six":
			for i in range(6):
				var direction := Vector2.RIGHT.rotated(TAU*i/6.0)
				_line(direction*3,direction*20)
				_line(direction*13,direction*14+direction.orthogonal()*5)
		"gas":
			for point in [Vector2(-13,-10),Vector2(12,-12),Vector2(0,13)]:
				draw_arc(point,6,0,TAU,20,ink,2,true)
		"fire":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-21),Vector2(15,6),Vector2(8,18),Vector2(-10,18),Vector2(-16,6),Vector2(-7,-5)]),Color("c8753c"))
		"flag", "pins":
			for x in ([-14,0,14] if kind=="pins" else [0]):
				_line(Vector2(x,18),Vector2(x,-16))
				draw_colored_polygon(PackedVector2Array([Vector2(x,-16),Vector2(x+11,-10),Vector2(x,-4)]),ink)
		"crystals":
			for x in [-13,0,13]:
				draw_colored_polygon(PackedVector2Array([Vector2(x,-16),Vector2(x+6,0),Vector2(x,16),Vector2(x-6,0)]),ink)
		"book", "speech":
			draw_rect(Rect2(-18,-14,36,28),ink,false,2)
			_line(Vector2(-12,-5),Vector2(12,-5))
			_line(Vector2(-12,3),Vector2(9,3))
			if kind=="book": _line(Vector2(0,-14),Vector2(0,14))
			else: _line(Vector2(-12,14),Vector2(-17,20))
		"mitten":
			draw_arc(Vector2(0,-7),12,PI,TAU,24,ink,3,true)
			draw_polyline(PackedVector2Array([Vector2(-12,-7),Vector2(-12,5),Vector2(-20,0),Vector2(-23,5),Vector2(-12,15),Vector2(-10,20),Vector2(11,20),Vector2(12,-7)]),ink,3,true)
			_line(Vector2(-10,14),Vector2(11,14))
		"boots":
			draw_polyline(PackedVector2Array([Vector2(-9,-17),Vector2(9,-17),Vector2(9,3),Vector2(19,9),Vector2(19,18),Vector2(-9,18),Vector2(-9,-17)]),ink,3,true)
		"boat":
			draw_colored_polygon(PackedVector2Array([Vector2(-23,9),Vector2(22,9),Vector2(12,20),Vector2(-14,20)]),ink)
			_line(Vector2(0,8),Vector2(0,-22))
			draw_colored_polygon(PackedVector2Array([Vector2(3,-20),Vector2(19,4),Vector2(3,4)]),ink)
		"engine", "lab_seal":
			draw_rect(Rect2(-15,-10,30,25),ink,false,3)
			for x in [-10,0,10]: _line(Vector2(x,-10),Vector2(x,-20))
			_line(Vector2(-22,20),Vector2(22,20))
		"crest":
			draw_polyline(PackedVector2Array([Vector2(-18,-18),Vector2(18,-18),Vector2(15,10),Vector2(0,24),Vector2(-15,10),Vector2(-18,-18)]),ink,3,true)
			_arrow(Vector2(-9,1),Vector2(10,-8))
		_:
			draw_arc(Vector2(0,-8),7,-PI,PI*0.5,20,ink,3,true)
			_line(Vector2(0,-1),Vector2(0,7))
			draw_circle(Vector2(0,15),2,ink)

func _line(from: Vector2, to: Vector2) -> void:
	draw_line(from,to,ink,2.5,true)

func _arrow(from: Vector2, to: Vector2) -> void:
	_line(from,to)
	var direction := (to-from).normalized()
	_line(to,to-direction*7+direction.orthogonal()*5)
	_line(to,to-direction*7-direction.orthogonal()*5)
