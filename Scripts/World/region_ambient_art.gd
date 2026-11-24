@tool
extends Node2D
## Opt-in decorative art. Caller supplies region/settings; no save or science ownership.
@export_enum("snow", "vale", "lab") var biome := "snow"
@export var reduced_effects := false
@export var frozen := false
var phase := 0.0
const MAX_MARKS := 24

func _process(delta: float) -> void:
	if not frozen and not get_tree().paused:
		phase = fmod(phase+delta,24.0)
	queue_redraw()

func _draw() -> void:
	# Local 240x120-world-unit footprint. Reduced version omits decoration entirely.
	if reduced_effects: return
	for i in range(MAX_MARKS):
		var at := Vector2(fposmod(i*67.0+phase*7,240)-120,fposmod(i*37.0+phase*12,120)-60)
		match biome:
			"snow": draw_circle(at,0.7,Color(0.92,0.98,1,0.45))
			"vale":
				if i<8: draw_arc(Vector2(-80+i*23,24),5+fmod(phase+i,3),0,PI,10,Color(0.5,0.77,0.8,0.3),0.8,true)
			"lab":
				if i<6: draw_line(Vector2(-70+i*28,-18),Vector2(-70+i*28,-24-fmod(phase+i,3)),Color(0.65,0.77,0.78,0.3),0.8,true)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: frozen = true
	# Caller explicitly restores frozen state; background never resets an authored pause.
