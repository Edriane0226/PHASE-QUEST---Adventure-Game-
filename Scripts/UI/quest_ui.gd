extends RefCounted
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
const TITLE_FONT = preload("res://assets/fonts/PhasequestUI.ttf")
const FRAME = preload("res://Scripts/UI/quest_frame.gd")
const BACKDROP = preload("res://assets/zones/zone_1/storybook/storybook_menu.png")
const INK := Color("25364a")
const CREAM := Color("f1eee4")
const BLUE := Color("d4dce1")
static var _theme: Theme

static func scroll_container() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	name_scroll_effects(scroll)
	return scroll

static func name_scroll_effects(scroll: ScrollContainer) -> void:
	# Godot 4.7 creates two unnamed internal fade textures in its constructor.
	var fade_index := 0
	for child in scroll.get_children(true):
		if child is TextureRect and "@" in str(child.name):
			child.name = "ScrollFade%d"%fade_index
			fade_index += 1

static func name_control_internals(control: Node, inside_internal: bool = false) -> void:
	# RichTextLabel and TabContainer also create anonymous private UI nodes.
	var public_children := control.get_children()
	for child in control.get_children(true):
		var private_child: bool = inside_internal or child not in public_children
		if private_child and "@" in str(child.name):
			var base: String = child.get_class()
			var readable := base
			var index := 2
			while control.has_node(NodePath(readable)):
				readable = base+str(index)
				index += 1
			child.name = readable
		name_control_internals(child,private_child)

static func frame(color: Color = CREAM, corners: bool = true) -> StyleBox:
	var style := FRAME.new()
	style.face = color
	style.rivets = corners
	return style

static func theme() -> Theme:
	if _theme!=null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = FONT
	_theme.default_font_size = 20
	for type in ["Label","Button","CheckButton","CheckBox","TabBar","TabContainer","OptionButton","LineEdit"]:
		_theme.set_color("font_color",type,INK)
		_theme.set_color("font_hover_color",type,INK)
		_theme.set_color("font_pressed_color",type,INK)
		_theme.set_color("font_focus_color",type,INK)
		_theme.set_color("font_disabled_color",type,Color("788d91"))
		_theme.set_color("font_outline_color",type,CREAM)
		_theme.set_constant("outline_size",type,0)
	_theme.set_color("default_color","RichTextLabel",INK)
	for type in ["TabBar","TabContainer"]:
		for state in ["font_selected_color","font_unselected_color","font_hovered_color","font_focus_color"]:
			_theme.set_color(state,type,INK)
	for type in ["CheckButton","CheckBox"]:
		_theme.set_icon("checked",type,load("res://assets/ui/icons/quest_toggle_on.svg"))
		_theme.set_icon("unchecked",type,load("res://assets/ui/icons/quest_toggle_off.svg"))
		for state in ["normal","hover","pressed","focus","disabled"]:
			_theme.set_stylebox(state,type,StyleBoxEmpty.new())
	for name in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]:
		_theme.set_font(name,"RichTextLabel",FONT)
	_theme.set_font_size("normal_font_size","RichTextLabel",20)
	for type in ["PanelContainer","Panel","TabContainer"]:
		_theme.set_stylebox("panel",type,frame())
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var fill := CREAM
			if state=="hover" or state=="focus": fill = Color("faf8ef")
			if state=="pressed": fill = Color("c7d3de")
			if state=="disabled": fill = Color("c7ccd0")
			_theme.set_stylebox(state,type,frame(fill,false))
	for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled","tab_focus"]:
		_theme.set_stylebox(state,"TabContainer",frame(CREAM if state=="tab_selected" else Color("9db8c8"),false))
		_theme.set_stylebox(state,"TabBar",frame(CREAM if state=="tab_selected" else Color("9db8c8"),false))
	_theme.set_stylebox("background","ProgressBar",frame(Color("7596a7"),false))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("68c4e0")
	fill.set_corner_radius_all(3)
	_theme.set_stylebox("fill","ProgressBar",fill)
	_theme.set_constant("h_separation","GridContainer",12)
	_theme.set_constant("v_separation","GridContainer",12)
	return _theme

static func apply(root: Node) -> void:
	if root is Control and root.name=="MainMenuPanel":
		return
	if root is TextureRect and root.name=="bgPanel":
		root.texture = BACKDROP
		root.material = null
		root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if root is TextureRect and root.name=="TextureRect" and root.get_parent()!=null:
		if root.get_parent() is ColorRect or root.get_parent().name in ["JournalPanel","Settings"]:
			root.texture = load("res://assets/fonts/doodlebg.png")
			root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var scrolling := ShaderMaterial.new()
			scrolling.shader = load("res://assets/shaders/ui/ScrollEffects.gdshader")
			scrolling.set_shader_parameter("direction",Vector2.ONE)
			scrolling.set_shader_parameter("speed",0.04)
			root.material = scrolling
			root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Level cards have authored category colors and a single frame in the scene.
	if root is GridContainer and root.name=="LevelGrid":
		return
	if root is Control:
		root.theme = theme()
		root.theme_type_variation = &""
		for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_outline_color","font_shadow_color","default_color"]:
			root.remove_theme_color_override(color)
		for style in ["panel","normal","hover","pressed","focus","disabled","tab_selected","tab_unselected"]:
			root.remove_theme_stylebox_override(style)
		for constant in ["outline_size","shadow_outline_size"]:
			root.remove_theme_constant_override(constant)
		root.add_theme_font_override("font",FONT)
		if root is RichTextLabel:
			root.add_theme_font_override("normal_font",FONT)
			root.add_theme_font_size_override("normal_font_size",20)
		if root is Button:
			root.flat = false
		if root is TextureButton and root.name=="CloseButton":
			root.texture_normal = preload("res://assets/ui/icons/quest_close.svg")
		if root is Button and root.name=="CloseButton":
			root.icon = preload("res://assets/ui/icons/quest_close.svg")
			root.expand_icon = true
			root.add_theme_constant_override("icon_max_width",48)
			for state in ["normal","hover","pressed","focus"]:
				root.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		if root is TextureRect and root.name in ["PreviousFrame","NextFrame"]:
			root.texture = null
			root.custom_minimum_size = Vector2(40,40)
		if root is Button and root.name in ["PreviousBtn","NextBtn"]:
			root.icon = preload("res://assets/ui/icons/quest_arrow.svg") if root.name=="PreviousBtn" else preload("res://assets/ui/icons/quest_arrow_right.svg")
			root.expand_icon = true
			root.add_theme_constant_override("icon_max_width",24)
			for state in ["normal","hover","pressed","focus"]:
				var style := frame(CREAM if state!="pressed" else BLUE,false)
				style.content_margin_left = 8
				style.content_margin_right = 8
				style.content_margin_top = 8
				style.content_margin_bottom = 8
				root.add_theme_stylebox_override(state,style)
	for child in root.get_children():
		apply(child)
