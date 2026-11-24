extends Control
## Original Phase Quest wordmark in the project's retained OFL typeface; no copied logo.
const FONT=preload("res://assets/fonts/PhasequestUI.ttf")
const TEXT="Phase Quest"
const PX=112
func _draw() -> void:
	var width:=FONT.get_string_size(TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,PX).x
	var at:=Vector2((size.x-width)/2,148)
	draw_string_outline(FONT,at+Vector2(2,4),TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,PX,7,Color(.03,.06,.08,.65))
	draw_string_outline(FONT,at+Vector2(-1,1),TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,PX,2,Color("80cce8"))
	draw_string_outline(FONT,at+Vector2(1,-1),TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,PX,1,Color("d8b96d"))
	draw_string(FONT,at,TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,PX,Color("fff5d9"))
	var center:=Vector2(size.x/2,190)
	draw_line(center-Vector2(68,0),center-Vector2(14,0),Color("a7c7b9"),1,true);draw_line(center+Vector2(14,0),center+Vector2(68,0),Color("a7c7b9"),1,true)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-6),center+Vector2(6,0),center+Vector2(0,6),center+Vector2(-6,0)]),Color("dcc691"))
