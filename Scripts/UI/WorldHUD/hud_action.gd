extends Button
## Presentation/hit shape only. Parent emits intents; authoritative input/save binding is R3 015.
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const CIRCLE=preload("res://assets/ui/hud/r3_v1/circle_frame.svg")
const HEX=preload("res://assets/ui/hud/r3_v1/hex_frame.svg")
const LOCK=preload("res://assets/ui/hud/r3_v1/lock.svg")
var caption:=""
var glyph: Texture2D
var tint:=Color("536a45")
var shape:="circle"
var locked:=false
var selected:=false
var reduced:=false
var visual_override:=""
var label_size:=14

func _ready() -> void:
	for key in ["normal","hover","pressed","disabled","focus"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
	focus_mode=Control.FOCUS_ALL
	for event in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]:event.connect(queue_redraw)
	resized.connect(queue_redraw)

func state_name() -> String:
	if not visual_override.is_empty():return visual_override
	if disabled:return "disabled"
	if locked:return "locked"
	if is_pressed():return "pressed"
	if has_focus():return "focus"
	if is_hovered():return "hovered"
	return "selected" if selected else "idle"

func _has_point(at: Vector2) -> bool:
	var p:=(at-size/2)/(size/2)
	if shape=="circle":return p.length_squared()<=1
	if shape=="hex":return absf(p.x)<=.88 and absf(p.y)<=1 and absf(p.y)+absf(p.x)*.57<=1.0
	return Rect2(Vector2.ZERO,size).has_point(at)

func _draw() -> void:
	var state:=state_name();var center:=size/2
	var rad:=minf(size.x,size.y)/2-3
	var fill:=Color(tint,.83)
	if state=="pressed":fill=fill.darkened(.28)
	if state in ["locked","disabled"]:fill=Color("3f4b43")
	if shape=="hex":
		var points:=PackedVector2Array()
		for i in 6:points.append(center+Vector2(0,-rad).rotated(i*TAU/6))
		draw_colored_polygon(points,fill);draw_texture_rect(HEX,Rect2(Vector2.ZERO,size),false)
	elif shape=="square":
		var panel:=StyleBoxFlat.new();panel.bg_color=fill;panel.border_color=Color("d6dec8");panel.set_border_width_all(2);panel.set_corner_radius_all(12);panel.shadow_color=Color(0,0,0,.3);panel.shadow_size=3
		draw_style_box(panel,Rect2(Vector2.ONE*2,size-Vector2.ONE*4))
	else:draw_circle(center,rad,fill);draw_texture_rect(CIRCLE,Rect2(Vector2.ZERO,size),false)
	if selected or state in ["selected","hovered","focus","pressed"]:
		var color:=Color("f1d78e") if selected else Color("fff9df")
		if shape=="circle":draw_arc(center,rad,0,TAU,64,color,2,true)
		elif shape=="hex":
			var rim:=PackedVector2Array()
			for i in 7:rim.append(center+Vector2(0,-rad).rotated(i*TAU/6))
			draw_polyline(rim,color,2,true)
		else:draw_rect(Rect2(Vector2.ONE*4,size-Vector2.ONE*8),color,false,2)
	var side:=minf(size.x,size.y)*(.46 if not caption.is_empty() else .60)
	var at:=Vector2(center.x-side/2,center.y-side/2-(label_size*.38 if not caption.is_empty() else 0))
	if state=="pressed":at.y+=2
	var icon: Texture2D=LOCK if locked or state=="locked" else glyph
	if icon:draw_texture_rect(icon,Rect2(at,Vector2.ONE*side),false,Color(1,1,1,.5 if state=="disabled" else 1))
	if not caption.is_empty():
		var font_px:=label_size;var width:=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_px).x
		var baseline:=size.y-7
		draw_string_outline(FONT,Vector2(center.x-width/2,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_px,3,Color("203027"))
		draw_string(FONT,Vector2(center.x-width/2,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_px,Color("fff8e0"))
	if selected:
		draw_circle(Vector2(size.x*.78,size.y*.18),5,Color("f6d788"))
		draw_polyline(PackedVector2Array([Vector2(size.x*.78-3,size.y*.18),Vector2(size.x*.78-1,size.y*.18+2),Vector2(size.x*.78+3,size.y*.18-3)]),Color("243329"),1.5,true)
