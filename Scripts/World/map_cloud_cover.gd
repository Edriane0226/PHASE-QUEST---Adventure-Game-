extends Node2D
## Painted fog for locked regions in gameplay and the map overview.
const CLOUD := preload("res://assets/zones/zone_1/storybook/map_cloud.png")
var puffs: Array[Vector2] = []
var clearing: float = 0.0:
	set(value):
		clearing = value
		queue_redraw()

func _draw() -> void:
	for i in range(puffs.size()):
		var drift := Vector2(-1.0 if i%2==0 else 1.0,-0.35)*clearing*260.0
		var at := puffs[i]+drift
		var size := Vector2(440.0,240.0)*(1.0+float(i%3)*0.04)
		draw_texture_rect(CLOUD,Rect2(at-size*0.5,size),false)
