extends RefCounted
## Moves only what the renderer draws. Node positions, sorting anchors and bodies stay as authored.

static func whole(value: Vector2) -> Vector2:
	return (value+Vector2(0.5,0.5)).floor()

## Draws a static child of an unrotated, unscaled parent on a whole world unit.
static func draw_whole(item: Node2D) -> void:
	if not item.is_inside_tree(): return
	var drawn := item.transform
	drawn.origin += whole(item.global_position)-item.global_position
	RenderingServer.canvas_item_set_transform(item.get_canvas_item(),drawn)
