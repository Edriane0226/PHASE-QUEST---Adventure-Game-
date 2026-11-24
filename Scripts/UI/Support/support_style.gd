extends RefCounted
## Shared native panel styling; no content, input or persistence authority.
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const FRAME=preload("res://Scripts/UI/quest_frame.gd")
const INK=Color("26382f")
const PAPER=Color("f5edda")
const MUTED=Color("546255")
static func theme_for(large:=false,contrast:=false) -> Theme:
	var theme:=Theme.new();theme.default_font=FONT;theme.default_font_size=19 if large else 16
	for type in ["Label","Button","CheckButton","LineEdit"]:
		theme.set_color("font_color",type,Color("17251d") if contrast else INK)
		for state in ["font_pressed_color","font_hover_color","font_hover_pressed_color","font_focus_color"]:theme.set_color(state,type,Color("17251d") if contrast else INK)
		theme.set_color("font_disabled_color",type,Color("5c6359"))
	theme.set_color("font_placeholder_color","LineEdit",INK if contrast else MUTED)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("e4d4aa") if state=="pressed" else Color("fff8e8")
		style.border_color=Color("273f2e") if contrast or state=="focus" else Color("9b9477");style.set_border_width_all(3 if state=="focus" else 2);style.set_corner_radius_all(8)
		style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8
		if state=="disabled":style.bg_color=Color("dedccf")
		for type in ["Button","LineEdit"]:theme.set_stylebox(state,type,style)
	return theme

static func paper(contrast:=false) -> StyleBox:
	if contrast:
		var high:=StyleBoxFlat.new();high.bg_color=Color("fff9e9");high.border_color=Color("17251d");high.set_border_width_all(3);high.set_corner_radius_all(10);high.content_margin_left=14;high.content_margin_right=14;high.content_margin_top=12;high.content_margin_bottom=12
		return high
	var frame:=FRAME.new();frame.face=Color("fff9e9") if contrast else PAPER;frame.rivets=false
	frame.content_margin_left=14;frame.content_margin_right=14;frame.content_margin_top=12;frame.content_margin_bottom=12
	return frame
