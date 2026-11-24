extends RefCounted
## Geometry and one gesture only. No scene, save, simulation or rendering access.
const NONE := -1
const MOUSE := -2
const INNER_RADIUS := 0.30
const OUTER_RADIUS := 0.94
const HYSTERESIS := PI/22.5 # Eight degrees past a quadrant boundary.
const ANGLES := {"thermal":-PI/2,"vacuum":0.0,"cryo":PI/2,"pressure":PI}
var pointer := NONE
var preview := ""

func _offset(point: Vector2, extent: Vector2) -> Vector2:
	if not point.is_finite() or not extent.is_finite() or minf(extent.x,extent.y) <= 0:
		return Vector2(INF,INF)
	return (point-extent/2)/(minf(extent.x,extent.y)/2)

func contains(point: Vector2, extent: Vector2) -> bool:
	return _offset(point,extent).length() <= OUTER_RADIUS

func mode_at(point: Vector2, extent: Vector2, previous := "") -> String:
	var offset := _offset(point,extent)
	var radius := offset.length()
	if not is_finite(radius) or radius <= INNER_RADIUS or radius > OUTER_RADIUS: return ""
	var angle := offset.angle()
	if ANGLES.has(previous) and absf(angle_difference(ANGLES[previous],angle)) <= PI/4+HYSTERESIS:
		return previous
	var closest := ""
	var distance := INF
	for mode: String in ANGLES:
		var delta := absf(angle_difference(ANGLES[mode],angle))
		if delta < distance:
			closest = mode
			distance = delta
	return closest

func owns(index: int) -> bool:
	return pointer != NONE and pointer == index

func begin(index: int, point: Vector2, extent: Vector2) -> bool:
	if pointer != NONE or (index < 0 and index != MOUSE) or not contains(point,extent): return false
	pointer = index
	preview = mode_at(point,extent)
	return true

func drag(index: int, point: Vector2, extent: Vector2) -> bool:
	if not owns(index): return false
	preview = mode_at(point,extent,preview)
	return true

func finish(index: int, point: Vector2, extent: Vector2, canceled := false) -> String:
	if not owns(index): return ""
	var result := "" if canceled else mode_at(point,extent,preview)
	cancel()
	return result

func cancel() -> void:
	pointer = NONE
	preview = ""
