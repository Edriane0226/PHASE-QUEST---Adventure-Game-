extends Control
var target := Vector2.ZERO
var clock := 0.0
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	draw_circle(target,18,Color(1,1,1,0.16))
	draw_arc(target,20+sin(clock*4)*3,0,TAU,40,Color("fff3c9"),2,true)
	draw_circle(target,7,Color("e9fbff"))
