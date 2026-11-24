extends Control
const QuestUI = preload("res://Scripts/UI/quest_ui.gd")
const RANK_SHEET = preload("res://assets/ui/ranks/rank_badges.png")
const RANK_NAMES := ["Apprentice","Researcher","Phase Master"]
const RANK_RANGES := ["0–6 stars","7–12 stars","13–18 stars"]
const GuideText = preload("res://Scripts/UI/mechanic_visual.gd")
const Teaching = preload("res://Scripts/World/Learning/professor_content.gd")
var player_name_label: Label
var rank_label: Label
var stars_label: Label
var next_rank_label: Label
var adventure_label: Label
var rank_progress: ProgressBar
var current_badge: TextureRect
var rank_cards: Array[PanelContainer] = []
var rank_status_labels: Array[Label] = []
var zone_entry_labels: Dictionary = {}
var zone_empty_labels: Dictionary = {}
var progress_tabs: TabContainer
var achievements: ScrollContainer
var guide_picker: OptionButton
var guide_frame: PanelContainer
var guide_description: Label
var guide_replay: Button
var guide_preview: Control
var guide_records: Dictionary = {}
var guide_signature := ""

func _ready() -> void:
	QuestUI.name_control_internals($TabContainer)
	_build_profile()
	_build_gardens()
	_build_locked_zone_entries()
	_organize_tabs()
	get_node("/root/PlayerSave").changed.connect(_refresh_profile)
	get_node("/root/PlayerSave").changed.connect(_refresh_guides)
	_refresh_profile()
	_refresh_guides()

func _organize_tabs() -> void:
	var tabs := $TabContainer
	var old_tabs := tabs.get_children()
	var titles := ["Adventure ranks","The Melting Gardens","The Mistfall Highlands","The Frostveil Peaks"]
	var progress := Control.new()
	progress.name = "Progress"
	tabs.add_child(progress)
	progress_tabs = TabContainer.new()
	progress_tabs.name = "ProgressSections"
	progress.add_child(progress_tabs)
	progress_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(old_tabs.size()):
		old_tabs[index].reparent(progress_tabs)
		progress_tabs.set_tab_title(index,titles[index])
	var guides := Control.new()
	guides.name = "Guides"
	guides.add_to_group("teaching_modal")
	tabs.add_child(guides)
	_build_guides(guides)
	achievements = ScrollContainer.new()
	achievements.name = "Achievements"
	achievements.set_script(preload("res://Scripts/UI/achievement_collection.gd"))
	tabs.add_child(achievements)
	for index in range(3):
		tabs.set_tab_title(index,["Progress","Guides","Achievements"][index])
	tabs.current_tab = 0
	QuestUI.name_control_internals(tabs)

func _build_guides(host: Control) -> void:
	var scroll := QuestUI.scroll_container()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 12
	scroll.offset_bottom = -12
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	scroll.add_child(column)
	column.add_child(_text("Discovered Guides",24))
	guide_picker = OptionButton.new()
	guide_picker.custom_minimum_size.y = 48
	guide_picker.item_selected.connect(func(index): _show_guide(str(guide_records.keys()[index])))
	column.add_child(guide_picker)
	guide_frame = PanelContainer.new()
	guide_frame.custom_minimum_size.y = 250
	column.add_child(guide_frame)
	guide_description = _text("",19)
	column.add_child(guide_description)
	guide_replay = Button.new()
	guide_replay.text = "Replay demonstration"
	guide_replay.custom_minimum_size.y = 48
	guide_replay.pressed.connect(func(): if is_instance_valid(guide_preview): guide_preview.replay())
	column.add_child(guide_replay)

func _refresh_guides() -> void:
	var records: Dictionary = get_node("/root/PlayerSave").discovered_guides()
	var signature := JSON.stringify(records)
	if signature == guide_signature: return
	guide_signature = signature
	guide_records.clear()
	guide_picker.clear()
	for topic: String in records:
		if not GuideText.LESSONS.has(topic): continue
		guide_records[topic] = records[topic]
		guide_picker.add_item(GuideText.LESSONS[topic][0])
	guide_picker.disabled = guide_records.is_empty()
	guide_frame.visible = not guide_records.is_empty()
	guide_replay.visible = not guide_records.is_empty()
	if guide_records.is_empty():
		guide_description.text = "Explore the garden to discover Guides. Replay remains free."
	else:
		guide_picker.select(0)
		_show_guide(str(guide_records.keys()[0]))

func _show_guide(topic: String) -> void:
	for child in guide_frame.get_children():
		guide_frame.remove_child(child)
		child.queue_free()
	var entry: Dictionary = guide_records[topic].duplicate()
	entry.topic = topic
	guide_preview = Teaching.preview(entry)
	guide_frame.visible = is_instance_valid(guide_preview)
	if is_instance_valid(guide_preview):
		guide_frame.add_child(guide_preview)
	guide_description.text = GuideText.LESSONS[topic][1][1].trim_prefix("DO: ")
	if GuideText.PUZZLE_EXPLANATIONS.has(entry.get("puzzle_type","")):
		guide_description.text = GuideText.PUZZLE_EXPLANATIONS[entry.puzzle_type] + "\n" + guide_description.text
	guide_replay.disabled = not is_instance_valid(guide_preview)

func _build_gardens() -> void:
	var host := $TabContainer/SolidTabBar/SolidPanel
	var margins := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		margins.add_theme_constant_override("margin_"+edge,12)
	host.add_child(margins,true)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_child(preload("res://UI/Dialogs/GardensJournal.tscn").instantiate(),true)

func _text(value: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",QuestUI.FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",QuestUI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_locked_zone_entries() -> void:
	for entry in [["LiquidTabBar/LiquidPanel","vaporization_and_condensation","The Mistfall Highlands"],["GasTabBar/GasPanel","sublimation_and_deposition","The Frostveil Peaks"]]:
		var margins := MarginContainer.new()
		$TabContainer.get_node(entry[0]).add_child(margins,true)
		margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+edge,12)
		var scroll := QuestUI.scroll_container()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margins.add_child(scroll,true)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",12)
		scroll.add_child(column,true)
		column.add_child(_text(entry[2],25),true)
		var empty := _text("Complete a level to add its discoveries to your journal.",18)
		column.add_child(empty,true)
		zone_empty_labels[entry[1]] = empty
		for number in range(1,7):
			var label := _text("",18)
			column.add_child(label,true)
			zone_entry_labels["%s:%d"%[entry[1],number]] = label

func _badge_texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = RANK_SHEET
	var width := float(RANK_SHEET.get_width())/3.0
	var height := minf(width,float(RANK_SHEET.get_height()))
	texture.region = Rect2(index*width,(RANK_SHEET.get_height()-height)/2.0,width,height)
	texture.filter_clip = true
	return texture

func _badge(size_px: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size_px,size_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _build_profile() -> void:
	var host := $TabContainer/PlayerProfileTabBar/PlayerProfilePanel
	var margins := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		margins.add_theme_constant_override("margin_"+edge,12)
	host.add_child(margins,true)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := QuestUI.scroll_container()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margins.add_child(scroll,true)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column,true)
	var heading := _text("ADVENTURE RANKS",25)
	heading.add_theme_font_override("font",QuestUI.TITLE_FONT)
	column.add_child(heading,true)
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation",16)
	column.add_child(overview,true)
	current_badge = _badge(116)
	current_badge.name = "CurrentRankBadge"
	overview.add_child(current_badge)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(details,true)
	player_name_label = _text("",29)
	player_name_label.name = "PlayerName"
	details.add_child(player_name_label)
	rank_label = _text("",22)
	details.add_child(rank_label,true)
	stars_label = _text("",20)
	details.add_child(stars_label,true)
	next_rank_label = _text("",18)
	details.add_child(next_rank_label,true)
	rank_progress = ProgressBar.new()
	rank_progress.custom_minimum_size.y = 16
	rank_progress.show_percentage = false
	column.add_child(rank_progress,true)
	adventure_label = _text("",17)
	column.add_child(adventure_label,true)
	column.add_child(_text("ADVENTURE RANK COLLECTION",19),true)
	var collection := HBoxContainer.new()
	collection.add_theme_constant_override("separation",12)
	column.add_child(collection,true)
	for index in range(3):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		collection.add_child(card,true)
		rank_cards.append(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",4)
		card.add_child(content,true)
		var icon := _badge(82)
		icon.texture = _badge_texture(index)
		content.add_child(icon,true)
		for text in [RANK_NAMES[index],RANK_RANGES[index]]:
			var label := _text(text,18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(label,true)
		var status := _text("",16)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(status,true)
		rank_status_labels.append(status)
	column.add_child(_text("Earn one star per completed level. Replays keep your earned star.",16),true)

func _refresh_profile() -> void:
	var store = get_node("/root/PlayerSave")
	var tabs := progress_tabs
	for zone_index in range(store.ZONES.size()):
		tabs.set_tab_disabled(zone_index+1,false)
		tabs.set_tab_icon(zone_index+1,null)
		tabs.set_tab_tooltip(zone_index+1,"Complete each level to unlock its discoveries.")
	for key: String in zone_entry_labels:
		zone_entry_labels[key].visible = bool(store.data.completed.get(key,false))
		zone_entry_labels[key].text = "★ Level %s completed · Field notes coming soon."%key.get_slice(":",1)
	for zone: String in zone_empty_labels:
		var any_completed := false
		for level in range(1,7):
			if store.is_level_complete(zone,level): any_completed = true
		zone_empty_labels[zone].visible = not any_completed
	var stars: int = store.total_stars()
	var rank: String = store.rank_name()
	var rank_index := RANK_NAMES.find(rank)
	player_name_label.text = str(store.data["player_name"]) if store.has_player_name() else "New explorer"
	rank_label.text = rank
	stars_label.text = "★ %d / 18 stars  ·  %d levels completed" % [stars,stars]
	current_badge.texture = _badge_texture(rank_index)
	var remaining: int = store.stars_to_next_rank()
	next_rank_label.text = "%d stars to %s" % [remaining,RANK_NAMES[mini(rank_index+1,2)]] if remaining>0 else "Highest rank achieved!"
	rank_progress.min_value = [0,7,13][rank_index]
	rank_progress.max_value = [7,13,18][rank_index]
	rank_progress.value = stars
	adventure_label.text = "No unfinished adventure. Choose Play to explore."
	if store.has_unfinished_run():
		var run: Dictionary = store.data["active_run"]
		var names := {"melting_and_freezing":"The Melting Gardens","vaporization_and_condensation":"The Mistfall Highlands","sublimation_and_deposition":"The Frostveil Peaks"}
		adventure_label.text = "Saved adventure: %s · Level %d. Continue from Main Menu." % [names.get(str(run["zone"]),"Unknown zone"),int(run["level"])]
	for index in range(3):
		var face := Color("fff0cb") if index==rank_index else Color("e3e8df")
		rank_cards[index].add_theme_stylebox_override("panel",QuestUI.frame(face,false))
		rank_cards[index].modulate.a = 1.0 if index<=rank_index else 0.65
		rank_status_labels[index].text = "Current rank" if index==rank_index else ("Achieved" if index<rank_index else "Requires %d stars" % [7 if index==1 else 13])
