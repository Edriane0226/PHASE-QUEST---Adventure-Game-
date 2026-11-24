extends RefCounted
## Shared campaign panel palette and button hierarchy.
static func frame(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.02,0.04,0.08,0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,2)
	return style

static func apply(root: Control) -> void:
	var ink := Color("#25364a")
	var gold := Color("#b5a179")
	var ivory := Color("#f1eee4")
	for panel_name in ["PausePanel","GameOverPanel","CompletionPanel"]:
		var panel: Control = root.get_node(panel_name)
		panel.add_theme_stylebox_override("panel",frame(ivory,gold,16))
		for view in panel.find_children("*","Label",true,false):
			view.add_theme_color_override("font_color",ink)
			view.add_theme_constant_override("outline_size",0)
		for button: Button in panel.find_children("*","Button",true,false):
			button.add_theme_color_override("font_color",ink)
			button.add_theme_color_override("font_hover_color",ink)
			button.add_theme_color_override("font_pressed_color",ivory)
			button.add_theme_color_override("font_focus_color",ink)
			button.add_theme_color_override("font_hover_pressed_color",ivory)
			button.add_theme_color_override("font_disabled_color",Color("#7c8490"))
			button.add_theme_constant_override("outline_size",0)
			button.add_theme_stylebox_override("normal",frame(Color("#e3dfd3"),Color("#c5bdab"),8))
			button.add_theme_stylebox_override("hover",frame(Color("#faf8ef"),gold,8))
			button.add_theme_stylebox_override("pressed",frame(ink,gold,8))
			button.add_theme_stylebox_override("focus",frame(Color.TRANSPARENT,gold,8))
	root.get_node("PausePanel/Actions/Label").text = "Paused"

