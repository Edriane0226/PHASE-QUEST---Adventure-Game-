extends Node2D
## Magnified model: one oxygen and two hydrogen atoms stay bonded during melting.
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
const MOLECULE_COUNT := 9
var liquid_fraction := 0.0
var clock := 0.0
var change_name := "Melting"

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func molecule_position(index: int) -> Vector2:
	var fixed := Vector2((index%3-1)*38,(index/3-1)*34)
	var vibration := Vector2(sin(clock*10+index),cos(clock*11+index))*1.3
	var angle := float(index)*TAU/9.0+clock*(0.35+float(index%3)*0.07)
	var liquid := Vector2(cos(angle)*57,sin(angle)*51)
	if index==4: liquid = Vector2(sin(clock*0.8)*15,cos(clock*0.9)*14)
	return (fixed+vibration).lerp(liquid,liquid_fraction)

func _draw() -> void:
	draw_circle(Vector2.ZERO,83,Color(0.035,0.09,0.13,0.85))
	draw_arc(Vector2.ZERO,83,0,TAU,80,Color("b5e8f4"),2,true)
	_text("WATER MOLECULES · H₂O",-110,16)
	for i in range(MOLECULE_COUNT):
		var at := molecule_position(i)
		var turn := liquid_fraction*sin(clock*0.6+i)*1.0
		var hydrogen_a := at+Vector2(-11,8).rotated(turn)
		var hydrogen_b := at+Vector2(11,8).rotated(turn)
		draw_line(at,hydrogen_a,Color("d5e7ee"),3,true)
		draw_line(at,hydrogen_b,Color("d5e7ee"),3,true)
		draw_circle(at,7,Color("df706c"))
		draw_circle(at+Vector2(-2,-2),2,Color("ffd3bf"))
		draw_circle(hydrogen_a,4,Color("f1f9fc"))
		draw_circle(hydrogen_b,4,Color("f1f9fc"))
	_text("Ice: vibrate in place" if liquid_fraction<0.1 else "Liquid: move past each other" if liquid_fraction>0.95 else change_name+": arrangement changes",107,15)
	_text("Red: oxygen · White: hydrogen",129,12)
	_text("Same molecules · Model, not actual size",148,12)

func _text(value: String, y: float, font_size: int) -> void:
	var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string_outline(FONT,Vector2(-width/2,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("182b36"))
	draw_string(FONT,Vector2(-width/2,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
