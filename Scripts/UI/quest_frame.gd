@tool
extends StyleBox
## Shared rounded ivory frames for menus, lessons and campaign panels.
@export var face: Color = Color("fff0cb")
@export var rivets: bool = true
@export var inset: float = 14.0
@export var storybook: bool = true

func _init() -> void:
	content_margin_left = 18
	content_margin_right = 18
	content_margin_top = 12
	content_margin_bottom = 12

func _draw(canvas: RID, rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f1eee4") if face.r>0.8 and face.g>0.75 else face
	style.border_color = Color("#b5a179")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.anti_aliasing = true
	style.shadow_color = Color(0.02,0.04,0.08,0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,2)
	style.draw(canvas,rect)
