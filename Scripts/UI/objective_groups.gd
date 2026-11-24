extends PanelContainer
const Quest = preload("res://Scripts/UI/quest_ui.gd")
var level: Node2D
var header: Button
var scroll: ScrollContainer
var body: VBoxContainer
var sections := {}
var collapsed := false
var clock := 0.0
var column: VBoxContainer
var side_tab: Button
var side_offset := 0.0
var top_y := 145.0
var rest_position := Vector2(18, 145)


func _ready() -> void:
	rest_position = position
	top_y = position.y
	column = $Content
	header = $Content/ToggleObjectives
	scroll = $Content/Scroll
	body = $Content/Scroll/Groups
	side_tab = get_parent().get_node_or_null("ToggleQuestSidebar")
	Quest.name_scroll_effects(scroll)
	header.pressed.connect(_toggle_sidebar)
	if is_instance_valid(side_tab):
		side_tab.pressed.connect(_toggle_sidebar)


func _toggle_sidebar() -> void:
	collapsed = not collapsed
	side_tab.text = "›" if collapsed else "‹"
	if is_instance_valid(level) and is_instance_valid(level.learning_support):
		level.learning_support.discover.call_deferred("task_sidebar", "player")


func _process(delta: float) -> void:
	if not is_instance_valid(side_tab):
		return
	side_offset = move_toward(side_offset, -size.x - 18 if collapsed else 0, delta * 1400)
	position = Vector2(rest_position.x + side_offset, top_y)
	side_tab.position = Vector2(maxf(0, position.x + size.x - 2), top_y + 10)
	side_tab.visible = is_visible_in_tree()
	clock += delta
	if clock >= .2:
		clock = 0
		refresh()


func refresh() -> void:
	if not is_instance_valid(level):
		return
	for group: Dictionary in _groups():
		var key: String = group.id
		if not sections.has(key):
			var box: VBoxContainer = preload("res://UI/Controls/ObjectiveSection.tscn").instantiate()
			body.add_child(box, true)
			var toggle: Button = box.get_node("ToggleButton")
			var rows: VBoxContainer = box.get_node("Rows")
			rows.visible = key == "puzzles"
			toggle.pressed.connect(
				func():
					rows.visible = not rows.visible
					refresh()
					reset_size()
			)
			sections[key] = {"toggle": toggle, "rows": rows, "items": []}
		var widgets: Dictionary = sections[key]
		var done := 0
		for i in range(group.rows.size()):
			var row: Array = group.rows[i]
			if row[1]:
				done += 1
			if widgets.items.size() <= i:
				var item: VBoxContainer = preload("res://UI/Controls/ObjectiveRow.tscn").instantiate()
				widgets.rows.add_child(item, true)
				var check: CheckBox = item.get_node("CheckBox")
				var bar: ProgressBar = item.get_node("ProgressBar")
				widgets.items.append({"check": check, "bar": bar})
			var item: Dictionary = widgets.items[i]
			item.check.text = row[0]
			item.check.set_pressed_no_signal(row[1])
			item.bar.visible = row.size() > 2
			if row.size() > 2:
				item.bar.max_value = row[3]
				item.bar.value = row[2]
		widgets.toggle.text = (
			("▾ " if widgets.rows.visible else "▸ ")
			+ group.title
			+ "  %d/%d" % [done, group.rows.size()]
		)


func place_below(at: Vector2, width: float, height: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	rest_position.x = at.x
	top_y = at.y
	position = Vector2(rest_position.x + side_offset, top_y)
	custom_minimum_size.x = width
	size.x = width
	if is_instance_valid(scroll):
		scroll.custom_minimum_size.y = minf(
			maxf(50, height - 160), body.get_combined_minimum_size().y
		)
	reset_size()


func _count(values: Array, threshold: float = 1.0) -> int:
	return values.filter(func(value): return float(value) >= threshold).size()


func _row(title: String, current: float, total: int) -> Array:
	return [title + " · %d/%d" % [int(current), total], current >= total, current, total]


func _groups() -> Array:
	var puzzles: Array = []
	var supplies: Array = []
	var exploration: Array = []
	var knowledge: Array = []
	if level.SAVE_LEVEL <= 2:
		puzzles.append(_row("Melt ice barriers", _count(level.melted), 3))
		puzzles.append(["Light relay heater", level.receiver_lit, level.ignition_charge, 1])
		if level.SAVE_LEVEL == 2:
			puzzles.append(_row("Connect copper links", level.valve_modes.count(1), 3))
		supplies = [
			["Collect wood", level.has_wood],
			["Collect fan blades", level.has_blades],
			["Repair fan", level.fan_installed]
		]
		exploration.append(_row("Collect crystals", level.collected.size(), level.CRYSTALS.size()))
	elif level.SAVE_LEVEL == 3:
		puzzles.append(_row("Freeze water crossings", _count(level.frozen), 4))
		puzzles.append(_row("Fill water basins", _count(level.water), 4))
		supplies.append(_row("Install coolant crystals", level.cores_installed.count(true), 2))
		exploration.append(_row("Collect frost sigils", level.collected.size(), 4))
	else:
		puzzles.append(_row("Melt ice sources", _count(level.source_melt), level.controls.size()))
		puzzles.append(_row("Fill basins", _count(level.basin_water), level.controls.size()))
		puzzles.append(
			_row(
				"Complete frozen crossings", level.circuits_done.count(true), level.controls.size()
			)
		)
		knowledge.append(
			_row(
				"Earn materials" if level.SAVE_LEVEL == 6 else "Earn altar seals",
				level.claimed.count(true),
				level.claimed.size()
			)
		)
		if level.SAVE_LEVEL == 6:
			supplies = [
				_row("Install skiff parts", level.assembly_step, 4),
				["Assemble travel skiff", level.assembled]
			]
	exploration.append(
		_row(
			"Attune statues", level.unlocked_waypoints.count(true), level.unlocked_waypoints.size()
		)
	)
	if level.props.has("learning_altar"):
		knowledge.append(
			_row(
				"Answer state-change questions",
				level.learning_answers,
				3 if level.SAVE_LEVEL == 1 else 4
			)
		)
	var result: Array = [{"id": "puzzles", "title": "Puzzles", "rows": puzzles}]
	if not supplies.is_empty():
		result.append({"id": "supplies", "title": "Supplies & building", "rows": supplies})
	result.append({"id": "exploration", "title": "Exploration", "rows": exploration})
	result.append({"id": "knowledge", "title": "Knowledge & rewards", "rows": knowledge})
	return result
