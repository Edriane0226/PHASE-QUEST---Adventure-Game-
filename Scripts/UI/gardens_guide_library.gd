extends Control
const Lessons = preload("res://Scripts/UI/mechanic_visual.gd")
const Teaching = preload("res://Scripts/World/Learning/professor_content.gd")
var support: CanvasLayer
var search: LineEdit
var list: VBoxContainer
var sidebar: ScrollContainer
var detail: VBoxContainer
var preview: Control
var title: Label
var status: Label
var description: Label
var topics: Array = []
var selected := ""
var footer: HBoxContainer
var back_button: Button
var heading: Label
var desktop_layout: Dictionary = {}
var compact_active := false
func _ready() -> void:
	heading = $Heading
	back_button = $Return
	search = $Search
	sidebar = $Sidebar
	list = $Sidebar/Topics
	detail = $Detail
	footer = $Footer
	title = $Detail/Title
	status = $Detail/Status
	description = $Detail/Description
	if not is_instance_valid(support):
		return
	back_button.text = "Back to help" if support.return_to_help else ("Return to question" if support.return_to_altar else "Return to garden")
	back_button.pressed.connect(support.return_from_guide)
	$Footer/Help.pressed.connect(support.open_help)
	search.text_changed.connect(func(_value): _filter())
	$Footer/Previous.pressed.connect(func(): _turn(-1))
	$Footer/Replay.pressed.connect(func(): if is_instance_valid(preview): preview.replay())
	$Footer/Pause.pressed.connect(func(): if is_instance_valid(preview): preview.toggle_playback())
	$Footer/Next.pressed.connect(func(): _turn(1))
	topics = support.allowed_topics()
	resized.connect(_layout)
	select_topic(support.demo_topic)
	_layout()


func label(text: String, font_size: int) -> Label:
	var item: Label = preload("res://UI/Controls/GuideText.tscn").instantiate()
	item.custom_minimum_size.x = 200
	item.text = text
	item.add_theme_color_override("font_color",Color("f2eddb"))
	item.add_theme_font_size_override("font_size",font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item
func button(text: String, action: Callable) -> Button:
	var item: Button = preload("res://UI/Guides/GuideTopicButton.tscn").instantiate()
	item.text = text
	item.custom_minimum_size = Vector2(70,44)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size",16)
	item.pressed.connect(action)
	return item
func topic_title(topic: String) -> String:
	var entry: Dictionary = support.guide_entry(topic)
	return entry.title if entry.has("title") else Lessons.LESSONS[topic.trim_prefix("past:")][0]

func _filter() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var count := 0
	var last_group := ""
	for topic: String in topics:
		var text: String = topic_title(topic)
		if not search.text.is_empty() and not text.to_lower().contains(search.text.to_lower()): continue
		if support.has_method("topic_group"):
			var group: String = support.topic_group(topic)
			if group != last_group:
				list.add_child(label(group,18))
				last_group = group
		var item := button(("▶  " if topic==selected else "    ")+text,select_topic.bind(topic))
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.custom_minimum_size = Vector2(180,60)
		item.toggle_mode = true
		item.set_pressed_no_signal(topic == selected)
		list.add_child(item,true)
		count += 1
	if count==0: list.add_child(label("Explore to discover tutorials" if topics.is_empty() else "No matching tutorials",17),true)
func select_topic(topic: String) -> void:
	selected = topic if topics.has(topic) else (str(topics[0]) if not topics.is_empty() else "")
	support.demo_topic = selected
	var frame := $Detail/PreviewFrame
	for child in frame.get_children():
		frame.remove_child(child)
		child.queue_free()
	preview = null
	if selected.is_empty():
		preview = null
		frame.hide()
		title.text = "No guides discovered yet"
		status.text = "Approach a new item or puzzle in the world. Its tutorial will appear here after you discover it."
		description.text = ""
		for child in footer.get_children(): child.disabled = child.name != "Help"
		_filter()
		_layout()
		return
	for child in footer.get_children(): child.disabled = false
	var entry: Dictionary = support.guide_entry(selected)
	var topic_id := selected.trim_prefix("past:")
	if topic_id not in ["map","checkpoint"] and support.has_method("create_preview"):
		preview=support.create_preview(selected)
	else:
		var reference := entry.duplicate()
		reference.topic = topic_id
		preview = Teaching.preview(reference)
	var has_preview := is_instance_valid(preview)
	frame.visible = has_preview
	$Footer/Replay.disabled = not has_preview
	$Footer/Pause.disabled = not has_preview
	status.text = "Demonstration" if has_preview else "Lesson notes"
	if has_preview:
		preview.custom_minimum_size.y = 160
		preview.narrated.connect(func(text): status.text = text)
		frame.add_child(preview,true)
	support.visual = preview
	title.text = topic_title(selected)
	description.text = entry.instructions if entry.has("instructions") else Lessons.LESSONS[topic_id][1][1].trim_prefix("DO: ")
	if Lessons.PUZZLE_EXPLANATIONS.has(entry.get("puzzle_type", "")):
		description.text = Lessons.PUZZLE_EXPLANATIONS[entry.puzzle_type] + "\n" + description.text
	_filter()
	_layout()
func _turn(direction: int) -> void:
	if topics.is_empty(): return
	select_topic(topics[posmod(topics.find(selected)+direction,topics.size())])
func _layout() -> void:
	if not is_instance_valid(search): return
	var properties := ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]
	if size.x >= 720:
		if compact_active:
			compact_active = false
			for view in desktop_layout:
				for property_name in properties:
					view.set(property_name, desktop_layout[view][property_name])
				heading.add_theme_font_size_override("font_size", 26)
		return
	if not compact_active:
		for view in [heading, back_button, search, sidebar, detail, footer]:
			var settings: Dictionary = {}
			for property_name in properties:
				settings[property_name] = view.get(property_name)
			desktop_layout[view] = settings
			view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		compact_active = true
	var margin := 18.0
	heading.position = Vector2(margin,18)
	heading.size = Vector2(size.x-margin*2,34)
	heading.add_theme_font_size_override("font_size",20)
	back_button.position = Vector2(margin,size.y-58)
	back_button.size = Vector2(size.x-margin*2,42)
	search.position = Vector2(margin,70)
	search.size = Vector2(size.x-margin*2,44)
	sidebar.position = Vector2(margin,122)
	sidebar.size = Vector2(size.x-margin*2,100)
	detail.position = Vector2(margin,234)
	detail.size = Vector2(size.x-margin*2,size.y-360)
	footer.position = Vector2(margin,size.y-112)
	footer.size = Vector2(size.x-margin*2,44)
