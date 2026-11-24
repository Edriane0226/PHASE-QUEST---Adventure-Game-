extends Button
## Quiet native title-menu action. Standard Button focus/touch states; no navigation authority.
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
var visual_override:=""
func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_theme_font_override("font",FONT)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:add_theme_color_override(state,Color("fff6e2"))
	add_theme_color_override("font_disabled_color",Color("a5aca8"));add_theme_color_override("font_outline_color",Color("132226"));add_theme_constant_override("outline_size",3)
	for event in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up]:event.connect(queue_redraw)
	resized.connect(queue_redraw)
func _draw() -> void:
	var state:=visual_override
	if state.is_empty():state="disabled" if disabled else "pressed" if is_pressed() else "focus" if has_focus() else "hovered" if is_hovered() else "idle"
	if state not in ["pressed","focus","hovered"]:return
	var y:=size.y/2;var span:=minf(size.x*.23,56)
	var tint:=Color("e9d5a4") if state=="pressed" else Color("d5e9dc")
	draw_line(Vector2(8,y),Vector2(span,y),tint,1.5,true);draw_line(Vector2(size.x-span,y),Vector2(size.x-8,y),tint,1.5,true)
	draw_circle(Vector2(span+7,y),1.8,tint);draw_circle(Vector2(size.x-span-7,y),1.8,tint)
