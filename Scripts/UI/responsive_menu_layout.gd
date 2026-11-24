extends Node
## Preserve the authored 16:9 composition with uniform scale at every aspect ratio.
## Works for standalone panels and panels nested inside an already scaled menu.
const DESIGN := Vector2(1152,648)
var art_positions: Dictionary = {}
var art_scales: Dictionary = {}
var art_rect := Rect2()

static func safe_area(viewport: Viewport, margin: float = 18.0) -> Rect2:
	var area := viewport.get_visible_rect()
	if OS.has_feature("android"):
		var screen := DisplayServer.get_display_safe_area()
		var inverse := viewport.get_screen_transform().affine_inverse()
		var first := inverse*Vector2(screen.position)
		var last := inverse*Vector2(screen.end)
		var usable := Rect2(first,last-first).intersection(area)
		if usable.has_area():
			area = usable
	return area.grow(-margin)

func _ready() -> void:
	preload("res://Scripts/UI/quest_ui.gd").apply(get_parent())
	if get_parent().has_node("bgPanel"):
		for child in get_parent().get_children():
			if child is Node2D:
				art_positions[child] = child.position
				art_scales[child] = child.scale
		var detail := get_parent().get_node_or_null("TextureRect") as Control
		if detail!=null:
			art_rect = Rect2(detail.position,detail.size)
	_fit()

func _process(_delta: float) -> void:
	_fit()

func _fit() -> void:
	var panel := get_parent() as Control
	if panel==null:
		return
	var safe := safe_area(get_viewport(),12)
	var factor: float = minf(safe.size.x/DESIGN.x,safe.size.y/DESIGN.y)
	var parent_transform := panel.get_global_transform_with_canvas()*panel.get_transform().affine_inverse()
	var parent_scale := parent_transform.get_scale().abs()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = DESIGN
	panel.scale = Vector2(factor,factor)/parent_scale
	panel.position = parent_transform.affine_inverse()*(safe.get_center()-DESIGN*factor*0.5)
	# Backdrops fill the display; the authored foreground keeps its proportions.
	for name in ["ColorRect","TextureRect"]:
		var background := panel.get_node_or_null(name) as Control
		if background!=null and (background is ColorRect or panel.name in ["Settings","JournalPanel"]):
			background.set_anchors_preset(Control.PRESET_TOP_LEFT)
			var inverse := panel.get_global_transform_with_canvas().affine_inverse()
			background.position = inverse*Vector2.ZERO
			background.size = get_viewport().get_visible_rect().size/factor
	var artwork := panel.get_node_or_null("bgPanel") as TextureRect
	if artwork!=null:
		var inverse := panel.get_global_transform_with_canvas().affine_inverse()
		var bounds := Rect2(inverse*Vector2.ZERO,get_viewport().get_visible_rect().size/factor)
		artwork.set_anchors_preset(Control.PRESET_TOP_LEFT)
		artwork.position = bounds.position
		artwork.size = bounds.size
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var cover: float = maxf(bounds.size.x/DESIGN.x,bounds.size.y/DESIGN.y)
		var origin := bounds.get_center()-DESIGN*cover/2
		for item: Node2D in art_positions:
			item.position = origin+art_positions[item]*cover
			item.scale = art_scales[item]*cover
		var detail := panel.get_node_or_null("TextureRect") as Control
		if detail!=null:
			detail.position = origin+art_rect.position*cover
			detail.size = art_rect.size*cover
	var frame := panel.get_node_or_null("PanelContainer") as Control
	if frame==null:
		frame = panel.get_node_or_null("TabContainer") as Control
	var close := panel.get_node_or_null("CloseButton") as Control
	if close!=null and frame!=null:
		close.set_anchors_preset(Control.PRESET_TOP_LEFT)
		close.rotation = 0
		close.size = Vector2(48,48)
		close.position = frame.position+Vector2(frame.size.x-58,10)
		if close is TextureButton:
			close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
