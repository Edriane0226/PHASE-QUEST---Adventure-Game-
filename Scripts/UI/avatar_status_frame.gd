@tool
extends PanelContainer
## Diamond portrait and beveled status rails shared by campaign HUDs.
var _rects: Dictionary = {}
func _ready() -> void:
	for child: Control in $Profile.get_children():
		_rects[child] = Rect2(child.position,child.size)
	resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	var factor := size/Vector2(352,128)
	for child: Control in _rects:
		var rect: Rect2 = _rects[child]
		child.position = rect.position*factor
		child.size = rect.size*factor
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(352,128))
	var outline := Color("#101e2c")
	var steel := Color("#6e8794")
	var gold := Color("#b8a477")
	var portrait := PackedVector2Array([Vector2(52,4),Vector2(100,52),Vector2(52,124),Vector2(4,52)])
	draw_colored_polygon(portrait,outline)
	var inner := PackedVector2Array([Vector2(52,10),Vector2(94,53),Vector2(52,116),Vector2(10,53)])
	draw_colored_polygon(inner,steel)
	draw_colored_polygon(PackedVector2Array([Vector2(52,15),Vector2(88,54),Vector2(52,109),Vector2(16,54)]),Color("#253e4c"))
	var face := preload("res://assets/characters/cast/explorer/portraits/explorer_face.tres")
	var clip := PackedVector2Array([Vector2(52,19),Vector2(85,54),Vector2(52,105),Vector2(19,54)])
	# Sample a face rectangle at a uniform scale, clipped by the inner frame.
	var uv := PackedVector2Array()
	var portrait_rect := Rect2(19,24,66,62)
	for point in clip:
		uv.append((point-portrait_rect.position)/portrait_rect.size)
	draw_polygon(clip,PackedColorArray([Color.WHITE]),uv,face)
	draw_polyline(PackedVector2Array([Vector2(6,53),Vector2(52,122),Vector2(98,53)]),gold,2,true)
	for index in range(2):
		var y := 43.0 if index==0 else 77.0
		var end := 350.0 if index==0 else 288.0
		var height := 30.0 if index==0 else 22.0
		var rail := PackedVector2Array([Vector2(93,y),Vector2(end-13,y),Vector2(end,y+height),Vector2(84,y+height)])
		draw_colored_polygon(rail,outline)
		draw_polyline(PackedVector2Array([Vector2(94,y+2),Vector2(end-14,y+2),Vector2(end-3,y+height-2),Vector2(86,y+height-2)]),steel,2,true)
	draw_line(Vector2(90,109),Vector2(270,109),Color("#4a7189"),2,true)



