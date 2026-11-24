extends Control
## A drawn cloud with small trailing thought dots; follows the explorer in screen space.
const CLOUD_SCALE := 0.70
var words: Label
var tail_tip := Vector2(125, 136)


func _ready() -> void:
	words = $ThoughtText


func set_text(value: String) -> void:
	words.text = value


func place_above(head: Vector2, viewport_size: Vector2) -> void:
	# Keep the small dot above the head even when the cloud is clamped at an edge.
	var tip := head + Vector2(0, -6)
	position = Vector2(
		clampf(tip.x - 125 * CLOUD_SCALE, 8, maxf(8, viewport_size.x - 250 * CLOUD_SCALE - 8)),
		maxf(8, tip.y - 136 * CLOUD_SCALE)
	)
	tail_tip = (tip - position) / CLOUD_SCALE
	queue_redraw()


func _draw() -> void:
	var cloud := Color("fffaf0")
	for circle in [
		Vector3(40, 52, 32),
		Vector3(74, 35, 31),
		Vector3(115, 32, 30),
		Vector3(156, 33, 30),
		Vector3(199, 43, 32),
		Vector3(217, 66, 27),
		Vector3(180, 77, 30),
		Vector3(137, 78, 30),
		Vector3(95, 78, 30),
		Vector3(54, 76, 28)
	]:
		draw_circle(Vector2(circle.x, circle.y), circle.z + 2, Color("657e86"))
	for circle in [
		Vector3(40, 52, 32),
		Vector3(74, 35, 31),
		Vector3(115, 32, 30),
		Vector3(156, 33, 30),
		Vector3(199, 43, 32),
		Vector3(217, 66, 27),
		Vector3(180, 77, 30),
		Vector3(137, 78, 30),
		Vector3(95, 78, 30),
		Vector3(54, 76, 28)
	]:
		draw_circle(Vector2(circle.x, circle.y), circle.z, cloud)
	draw_circle(Vector2(125, 104).lerp(tail_tip, 0.48), 6, cloud)
	draw_circle(tail_tip, 3, cloud)
