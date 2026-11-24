extends Node2D
## Static world-space UI cue, not a beam/effect or simulation authority.
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
const COLORS := {"thermal":Color("e6a34a"),"cryo":Color("80cce8"),"pressure":Color("b8a0dc"),"vacuum":Color("72c5b9")}
var model: Dictionary = {}
var caption_layout: Callable
var caption_rect := Rect2()
var caption_exclusions: Array[Rect2] = []

func present(value: Dictionary) -> void:
	model = value
	queue_redraw()

func _caption(value: String, at: Vector2, color: Color) -> void:
	if value.is_empty(): return
	var extent := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,10)
	var baseline := at-Vector2(extent.x/2,0)
	if caption_layout.is_valid():
		var canvas := get_global_transform_with_canvas()
		var scale := canvas.get_scale().abs()
		# Keep text clear of the explorer and selected sample as well as HUD.
		caption_exclusions = [Rect2(canvas*model.actor-Vector2(14,35)*scale,Vector2(28,40)*scale)]
		if model.get("target",false):
			var radius: float = model.radius+5
			caption_exclusions.append(Rect2(canvas*model.point-Vector2.ONE*radius*scale,Vector2.ONE*radius*2*scale))
		var position: Vector2 = caption_layout.call(canvas*at,extent*scale,caption_exclusions)
		caption_rect = Rect2(position,extent*scale)
		baseline = canvas.affine_inverse()*(position+Vector2(0,FONT.get_ascent(10)*scale.y))
	draw_string_outline(FONT,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("172b3b"))
	draw_string(FONT,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)

func _draw() -> void:
	caption_rect = Rect2()
	if model.is_empty(): return
	var origin: Vector2 = model.origin
	var facing: Vector2 = model.facing
	var reach: float = model.range
	var angle := facing.angle()
	var tint: Color = COLORS.get(model.mode,Color("e6cf99"))
	var sector := PackedVector2Array([origin])
	for step in 17: sector.append(origin+Vector2.from_angle(angle-deg_to_rad(30)+step*deg_to_rad(60)/16)*reach)
	draw_colored_polygon(sector,Color(tint,0.045))
	draw_arc(origin,reach,angle-deg_to_rad(30),angle+deg_to_rad(30),32,Color(tint,0.65),1,true)
	for edge in [-1,1]:
		var direction := facing.rotated(edge*deg_to_rad(30))
		draw_line(origin+direction*(reach-7),origin+direction*reach,tint,1.5,true)
	if model.get("target",false):
		var at: Vector2 = model.point
		var radius: float = model.radius
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var vertex := at+corner*radius
			for segment: Vector2 in [Vector2(-corner.x*6,0),Vector2(0,-corner.y*6)]:
				draw_line(vertex,vertex+segment,Color("172b3b"),4,true)
				draw_line(vertex,vertex+segment,Color("fff0c7"),2,true)
		var progress: float = clampf(model.get("progress",0.0),0,1)
		if progress > 0: draw_arc(at,radius+3,-PI/2,-PI/2+TAU*progress,32,tint,2,true)
		_caption(("HIT" if model.active else "READY")+" · %d/%d" % [ceili(origin.distance_to(at)),ceili(reach)],at+Vector2(0,-radius-8),tint)
	else:
		_caption(model.get("status","NO TARGET"),origin+Vector2(0,52),Color("fff0c7"))
