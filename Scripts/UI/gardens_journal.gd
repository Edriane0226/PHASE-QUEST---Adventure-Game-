extends ScrollContainer
## Completed-level memories, not a guide to unfinished puzzles.
const QuestUI = preload("res://Scripts/UI/quest_ui.gd")
var column: VBoxContainer
var level_headers: Dictionary = {}
var level_bodies: Dictionary = {}
var expanded: Dictionary = {}
var demonstration: SubViewportContainer
var caption: Label
var replay: Button
var phase_time := 0.0
var last_unlocked := -1
var replaying := false
const CAPTIONS := ["Solid ice: molecules vibrate in place.","The heater transfers heat to the colder ice.","Melting: molecules can move past one another.","Liquid water: the same H₂O, a different state."]

func _ready() -> void:
	QuestUI.name_scroll_effects(self)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column = $Content
	get_node("/root/PlayerSave").changed.connect(_refresh_notes)
	_refresh_notes()

func _refresh_notes() -> void:
	var store = get_node("/root/PlayerSave")
	var completion_mask := 0
	for level in range(1,2):
		if store.is_level_complete("melting_and_freezing",level): completion_mask |= 1 << (level-1)
	if completion_mask==last_unlocked: return
	last_unlocked = completion_mask
	demonstration = null
	replaying = false
	level_headers.clear()
	level_bodies.clear()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	column.add_child(_text("THE MELTING GARDENS",25),true)
	column.add_child(_text("Open a completed level to revisit your discoveries." if completion_mask!=0 else "Complete a level to add its discoveries to your journal.",17),true)
	for level in range(1,2):
		var completed: bool = store.is_level_complete("melting_and_freezing",level)
		if not completed:
			expanded.erase(level)
			continue
		var header := Button.new()
		header.name = "Level%dDropdown"%level
		header.toggle_mode = true
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.custom_minimum_size.y = 52
		header.add_theme_font_override("font",QuestUI.FONT)
		header.add_theme_font_size_override("font_size",18)
		header.add_theme_color_override("font_color",QuestUI.INK)
		header.add_theme_stylebox_override("normal",QuestUI.frame(Color("f8e8bd"),false))
		header.add_theme_stylebox_override("pressed",QuestUI.frame(Color("ecd7a3"),false))
		header.add_theme_stylebox_override("hover",QuestUI.frame(Color("fff3d5"),false))
		column.add_child(header,true)
		level_headers[level] = header
		var body := VBoxContainer.new()
		body.name = "Level%dDiscoveries"%level
		body.add_theme_constant_override("separation",12)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.visible = false
		column.add_child(body,true)
		level_bodies[level] = body
		header.toggled.connect(func(opened: bool): _toggle_level(level,opened))
		_set_header(level,completed,false)
		if expanded.get(level,false):
			header.set_pressed_no_signal(true)
			_toggle_level(level,true)

func _set_header(level: int, completed: bool, opened: bool) -> void:
	level_headers[level].text = "%s  LEVEL %d  ·  %s"%["▾" if opened else "▸",level,"★ Discoveries" if completed else "Locked"]
	level_headers[level].tooltip_text = ("Close" if opened else "Open")+" Level %d field notes"%level

func _toggle_level(level: int, opened: bool) -> void:
	var completed: bool = get_node("/root/PlayerSave").is_level_complete("melting_and_freezing",level)
	if not completed or not level_bodies.has(level): return
	var body: VBoxContainer = level_bodies[level]
	expanded[level] = opened
	body.visible = opened
	_set_header(level,completed,opened)
	if opened and body.get_child_count()==0:
		if not completed:
			body.add_child(_text("Complete Level %d to unlock its discoveries."%level,18),true)
		elif level==1:
			_build_level_one(body)
	if level==1 and is_instance_valid(demonstration):
		demonstration.process_mode = Node.PROCESS_MODE_INHERIT if opened else Node.PROCESS_MODE_DISABLED
		demonstration.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if opened and is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _build_level_one(body: VBoxContainer) -> void:
	var states := HBoxContainer.new()
	states.alignment = BoxContainer.ALIGNMENT_CENTER
	states.add_theme_constant_override("separation",18)
	body.add_child(states,true)
	for item in [[preload("res://assets/zones/zone_1/storybook/heater_lit.tres"),"HEAT"],[preload("res://assets/zones/zone_1/storybook/ice_solid.tres"),"SOLID"],[preload("res://assets/zones/zone_1/storybook/ice_puddle.tres"),"LIQUID"]]:
		var tile := VBoxContainer.new()
		tile.add_child(_icon(item[0],64),true)
		var label := _text(item[1],15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(label,true)
		states.add_child(tile,true)
	body.add_child(_text("Heat added → ice melts. Same water, different state.",19),true)
	demonstration = preload("res://Scripts/UI/map_lesson_scenario.gd").new()
	demonstration.name = "CompletedLevelDemonstration"
	demonstration.custom_minimum_size = Vector2(0,300)
	demonstration.size = Vector2(780,300)
	demonstration.mode = "lesson"
	body.add_child(demonstration)
	# Keep the magnified model within this compact journal view.
	demonstration.molecules.position = Vector2(150,125)
	caption = _text(CAPTIONS[0],18)
	body.add_child(caption,true)
	replay = Button.new()
	replay.text = "▶  Replay discovery"
	replay.custom_minimum_size.y = 44
	replay.pressed.connect(_replay)
	body.add_child(replay,true)
	demonstration.finished.connect(func():
		replaying = false
		replay.text = "▶  Replay discovery")
	demonstration.running = false
	body.add_child(_text("H₂O stays intact. Its molecules change arrangement and movement.",17),true)
	body.add_child(_text("TOOLS YOU USED",17),true)
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation",22)
	body.add_child(tools,true)
	for item in [[preload("res://assets/zones/zone_1/storybook/firewood.tres"),"Fuel"],[preload("res://assets/zones/zone_1/storybook/air_vent.tres"),"Airflow"],[preload("res://assets/zones/zone_1/storybook/heat_reflector.tres"),"Heat direction"],[preload("res://assets/zones/zone_1/storybook/checkpoint_lantern.tres"),"Checkpoints"]]:
		var tile := VBoxContainer.new()
		tile.custom_minimum_size.x = 110
		tile.add_child(_icon(item[0],48),true)
		var tool_name := _text(item[1],16)
		tool_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(tool_name,true)
		tools.add_child(tile,true)

func _replay() -> void:
	if (last_unlocked & 1)==0 or not expanded.get(1,false): return
	demonstration.reset_scenario()
	caption.text = CAPTIONS[0]
	phase_time = 0
	replaying = true
	replay.text = "↻  Restart discovery"

func _process(delta: float) -> void:
	if not is_instance_valid(demonstration): return
	var shown := demonstration.is_visible_in_tree()
	demonstration.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	demonstration.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if not shown or not replaying: return
	phase_time += delta
	if phase_time>=3.3:
		phase_time = 0
		demonstration.advance_dialogue()
		caption.text = CAPTIONS[demonstration.phase]

func _icon(texture: Texture2D, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side,side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",QuestUI.FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",QuestUI.INK)
	return label
