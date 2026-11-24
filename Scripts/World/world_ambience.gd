extends Node2D
## Fixed-budget, camera-local falling snow with visible round flakes.
const FLAKE_COUNT := 96
var follow: Node2D
var time: float = 0.0
var redraw_elapsed := 0.0

func _process(delta: float) -> void:
	time += delta
	redraw_elapsed += delta
	if redraw_elapsed < 1.0 / 30.0:
		return
	redraw_elapsed = fmod(redraw_elapsed,1.0 / 30.0)
	if is_instance_valid(follow):
		position = follow.position
	queue_redraw()

func _draw() -> void:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var viewport_size := get_viewport_rect().size
	for i in range(FLAKE_COUNT):
		var depth := float(i % 3 + 1)
		var x := fposmod(float(i*137)+time*(12.0+depth*7.0)+sin(time*0.7+i)*9.0,viewport_size.x+32.0)-16.0
		var y := fposmod(float(i*83)+time*(23.0+depth*13.0),viewport_size.y+32.0)-16.0
		var at := inverse * Vector2(x,y)
		var pixel_scale := inverse.x.length()
		var radius := (1.1+depth*0.45)*pixel_scale
		# A restrained blue edge keeps white flakes visible over off-white ground.
		draw_circle(at+Vector2(0.3,0.45)*pixel_scale,radius+0.45*pixel_scale,Color(0.48,0.62,0.74,0.12+depth*0.04))
		draw_circle(at,radius,Color(0.96,0.99,1.0,0.50+depth*0.10))
