@tool
extends Node2D
## Ground-level shallow water, with snowy banks and a slow current.
const WATER := preload("res://assets/zones/zone_1/storybook/shallow_river.png")
var crossings: Array[Vector2i] = []
var ground: Dictionary = {}
var clock := 0.0
var redraw_elapsed := 0.0




func iso(cell: Vector2i) -> Vector2:
	return Vector2((cell.x-cell.y)*40,(cell.x+cell.y)*20)

func _process(delta: float) -> void:
	clock += delta
	redraw_elapsed += delta
	if redraw_elapsed>=1.0/20.0:
		redraw_elapsed = 0.0
		queue_redraw()




func _draw() -> void:
	for cell in crossings:
		var at := iso(cell)
		var screen_at := get_global_transform_with_canvas()*at
		if not get_viewport_rect().grow(80.0).has_point(screen_at): continue
		var phase := fposmod(clock*0.22+float(cell.x+cell.y)*0.13,1.0)
		var ripple_at := at+Vector2((phase-0.5)*22.0,sin(phase*TAU)*3.0)
		draw_arc(ripple_at,8.0,-0.2,1.5,12,Color(0.85,0.98,1.0,sin(phase*PI)*0.32),1.0,true)
