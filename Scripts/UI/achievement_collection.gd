extends ScrollContainer
const Registry = preload("res://Scripts/Autoload/achievement_registry.gd")
const Icon = preload("res://Scripts/UI/achievement_icon.gd")
const QuestUI = preload("res://Scripts/UI/quest_ui.gd")
var cards: Dictionary = {}
var grid: GridContainer
var summary: Label
var hint: Label
var readability_scale := 0.0

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	QuestUI.name_scroll_effects(self)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",16)
	add_child(column)
	summary = _text("",22)
	column.add_child(summary)
	hint = _text("Collectible achievements • Adventure ranks remain in Progress.",16)
	column.add_child(hint)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	column.add_child(grid)
	for index in range(Registry.DEFINITIONS.size()):
		_build_card(Registry.DEFINITIONS[index], index)
	resized.connect(_layout)
	get_node("/root/PlayerSave").changed.connect(refresh)
	_layout()
	refresh()

func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",QuestUI.FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",QuestUI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_card(item: Dictionary, index: int) -> void:
	var card := PanelContainer.new()
	card.name = "Discovery%d" % (index+1)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", QuestUI.frame(QuestUI.CREAM,false))
	grid.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	var icon := Control.new()
	icon.set_script(Icon)
	row.add_child(icon)
	var title := _text("",21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var condition := _text("",17)
	column.add_child(condition)
	var status := _text("",16)
	column.add_child(status)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 16
	bar.show_percentage = false
	column.add_child(bar)
	cards[item.id] = {"icon":icon, "title":title, "condition":condition, "status":status, "bar":bar}

func _layout() -> void:
	if grid == null: return
	var screen_width := size.x * get_global_transform_with_canvas().get_scale().x
	var columns := 2 if screen_width >= 680 else 1
	if grid.columns != columns: grid.columns = columns
	var factor := maxf(1.0, 1.0 / maxf(0.1, get_global_transform_with_canvas().get_scale().x))
	if is_equal_approx(factor, readability_scale): return
	readability_scale = factor
	summary.add_theme_font_size_override("font_size", roundi(22*factor))
	hint.add_theme_font_size_override("font_size", roundi(16*factor))
	for views: Dictionary in cards.values():
		views.icon.custom_minimum_size = Vector2.ONE*60*factor
		views.title.add_theme_font_size_override("font_size", roundi(21*factor))
		views.condition.add_theme_font_size_override("font_size", roundi(17*factor))
		views.status.add_theme_font_size_override("font_size", roundi(16*factor))
		views.bar.custom_minimum_size.y = 16*factor

func _process(_delta: float) -> void:
	# Journal's authored layout scales with its parent rather than resizing.
	_layout()

func refresh() -> void:
	var store := get_node("/root/PlayerSave")
	var state: Dictionary = store.achievement_state()
	summary.text = "%d / 32 achievements earned" % state.unlocks.size()
	for item: Dictionary in Registry.DEFINITIONS:
		var views: Dictionary = cards[item.id]
		var earned: bool = state.unlocks.has(item.id)
		var concealed: bool = item.get("hidden",false) and not earned
		views.icon.kind = "hidden" if concealed else item.icon
		views.icon.earned = earned
		views.icon.queue_redraw()
		views.title.text = "Hidden discovery" if concealed else item.name
		views.condition.text = "Keep exploring to uncover this achievement." if concealed else item.condition
		var target: int = Registry.target(item)
		var count: int = Registry.progress_count(item,state)
		views.status.text = "Unlocked" if earned else "Locked"
		views.bar.visible = target > 1 and not concealed
		views.bar.max_value = target
		views.bar.value = count
		if target > 1 and not concealed:
			views.status.text += " • %d / %d" % [count,target]
