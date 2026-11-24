extends CanvasLayer
## Shared player-facing guidance and level-scoped early knowledge altars.
const Visual = preload("res://Scripts/UI/mechanic_visual.gd")
const Quest = preload("res://Scripts/UI/quest_ui.gd")
const BANKS = preload("res://Scripts/Content/level_questions.gd").BANKS
var level: Node2D
var opened := false
var previous_pause := false
var shade: ColorRect
var column: VBoxContainer
var hint_card: PanelContainer
var hint_title: Label
var hint_body: Label
var help_button: Button
var cues: Node2D
var focus_data: Dictionary = {}
var visual: Control
var demo_topic := "melting"
var demo_step := 0
var waiting_continue := false
var feedback: Label
var cue_time := 0.0
var guide: Control
var return_to_altar := false
var return_to_help := false
var contextual_demo_topic := ""
var discovery_cooldown := 3.0
var discovery_tick := 0.0
var mechanism_status: CanvasLayer


func _exit_tree() -> void:
	if opened:
		get_tree().paused = previous_pause


func bindLevel(owner_level: Node2D) -> void:
	level = owner_level
	layer = 76
	process_mode = Node.PROCESS_MODE_ALWAYS
	shade = $Overlay
	column = $Overlay/Card/Scroll/Content
	Quest.name_scroll_effects($Overlay/Card/Scroll)
	help_button = level.hud_root.get_node("GuideButton")
	help_button.pressed.connect(open_demo)
	level.mobile_controls.excluded_controls.append(help_button)
	hint_card = level.stats_panel.column.get_node("NextActionCard")
	hint_title = hint_card.get_node("Content/Title")
	hint_body = hint_card.get_node("Content/Description")
	level.mobile_controls.excluded_controls.append(level.stats_panel.side_tab)
	cues = level.get_node("LearningCues")
	cues.draw.connect(_draw_cues)
	if level.props.has("learning_altar"):
		_place_altar()
	get_viewport().size_changed.connect(_layout)
	_layout()
	mechanism_status = level.get_node("MechanismStatus")
	mechanism_status.bindLevel(level)


func _label(text: String, size: int) -> Label:
	var label: Label = preload("res://UI/Controls/KnowledgeText.tscn").instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button: Button = preload("res://UI/Controls/KnowledgeAnswer.tscn").instantiate()
	button.text = text
	button.pressed.connect(action)
	return button


func _layout() -> void:
	_layout_help_panel()
	var size := get_viewport().get_visible_rect().size
	if is_instance_valid(hint_card):
		hint_card.visible = not level.overview and not level.complete and not opened
		if level.mobile_controls.touch_mode:
			var sidebar_y: float = 196.0 if size.x < 800 else level.stats_panel.rest_position.y
			level.stats_panel.place_below(Vector2(18, sidebar_y), 245, maxf(150, size.y - sidebar_y - 100))
		level.stats_panel.visible = not level.overview and not level.complete and not opened
	if is_instance_valid(help_button):
		help_button.visible = not get_tree().paused and not opened and not level.complete and not level.overview
		if level.mobile_controls.touch_mode:
			var map_rect: Rect2 = level.mobile_controls.button_rects.get("map", Rect2())
			help_button.position = map_rect.position - Vector2(208, 0)
			help_button.custom_minimum_size = Vector2(196, 52)
			help_button.size = Vector2(196, 52)
			help_button.text = "Show me this mechanic"


func _layout_help_panel() -> void:
	if not is_instance_valid(shade): return
	var size := get_viewport().get_visible_rect().size
	var panel: Control = shade.get_node("Card")
	panel.offset_left = -minf(470, size.x * .46)
	panel.offset_right = minf(470, size.x * .46)
	panel.offset_top = -minf(335, size.y * .46)
	panel.offset_bottom = minf(335, size.y * .46)



func _place_altar() -> void:
	level.props.learning_altar.active = passed()


func passed() -> bool:
	return level.SAVE_LEVEL > 3 or level.learning_answers >= level_questions().size()


func level_topics() -> Array:
	if level.SAVE_LEVEL == 1:
		return ["melting", "fuel_air", "reflection"]
	if level.SAVE_LEVEL == 2:
		return ["melting", "fuel_air", "conduction", "reflection"]
	if level.SAVE_LEVEL == 3:
		return ["freezing", "routing"]
	var result: Array = ["cycle", "freezing"]
	for topic: String in level.specialties:
		if not result.has(topic):
			result.append(topic)
	if level.SAVE_LEVEL == 6:
		result.append("assembly")
	return result


func allowed_topics() -> Array:
	var result: Array = []
	for topic: String in get_node("/root/PlayerSave").discovered_guides():
		if Visual.LESSONS.has(topic):
			result.append(topic)
	if return_to_help and Visual.LESSONS.has(contextual_demo_topic) and not result.has(contextual_demo_topic):
		result.append(contextual_demo_topic)
	return result


func guide_entry(topic: String) -> Dictionary:
	var current: Dictionary = {}
	for entry: Dictionary in get_node("/root/PlayerSave").guide_records().values():
		if entry.topic == topic and entry.zone == level.SAVE_ZONE and entry.level == level.SAVE_LEVEL:
			current = entry
			if entry.has("puzzle_type"): return entry
	if not current.is_empty(): return current
	return get_node("/root/PlayerSave").discovered_guides().get(
		topic, {"zone": level.SAVE_ZONE, "level": level.SAVE_LEVEL, "object": ""}
	)


func _object_topic(id: String) -> String:
	if id in ["heater_module","heater_dock"]:
		return "melting"
	if id == "player":
		return "movement"
	if id == "Camp" or id.begins_with("WarmShelter"):
		return "warmth" if level.SAVE_LEVEL <= 2 else "coat"
	if id.begins_with("crystal"):
		return "crystals"
	if id == "wood":
		return "fuel"
	if id == "blades":
		return "fan_blades"
	if id == "vent" or id == "brazier1":
		return "fuel_air"
	if id.begins_with("brazier") or id.begins_with("ice"):
		return "melting"
	if id.begins_with("valve"):
		return "conduction"
	if id.begins_with("mirror") or id == "receiver":
		return "reflection"
	if id.begins_with("cooler") or id.begins_with("pool"):
		return "freezing"
	if id.begins_with("sluice"):
		return "sluice"
	if id.begins_with("core") or id.begins_with("socket"):
		return "coolant"
	if id == "diverter":
		return "routing"
	if id.begins_with("waypoint"):
		return "checkpoint"
	if id.begins_with("note"):
		return "notes"
	if id == "professor":
		return "professor"
	if id == "learning_altar" or id.begins_with("altar"):
		return "altar"
	if id == "exit":
		return "assembly" if level.SAVE_LEVEL == 6 else "exit"
	if id.begins_with("pump") or id.begins_with("source"):
		return "cycle"
	if id.begins_with("basin"):
		return "freezing"
	if id.begins_with("aux"):
		return level.specialties[int(id.trim_prefix("aux"))]
	return ""


func discover(topic: String, object_id: String) -> bool:
	if opened or not Visual.LESSONS.has(topic):
		return false
	var store = get_node("/root/PlayerSave")
	var id: String = store.instance_id(level.SAVE_ZONE, level.SAVE_LEVEL, object_id) + ":" + topic
	if store.guide_records().has(id): return false
	if not store.discover_guide(topic, level.SAVE_LEVEL, object_id, level.SAVE_ZONE):
		discovery_cooldown = 2.5
		level._message(store.last_error)
		return false
	discovery_cooldown = 3.0
	_fly_to_guides(topic)
	level._message(Visual.LESSONS[topic][1][1].trim_prefix("DO: ") + " Replay in Guides.")
	return true


func _check_discovery() -> void:
	var store = get_node("/root/PlayerSave")
	if (
		not store.session_active
		or opened
		or get_tree().paused
		or discovery_cooldown > 0
		or level.dead
		or level.complete
	):
		return
	var unlocked := allowed_topics()
	if level.overview:
		if not unlocked.has("map"):
			discover("map", "waypoint0")
		return
	var closest := 145.0
	var object_id := ""
	var topic := ""
	var view: Rect2 = level.get_viewport_rect().grow(-12)
	for key: String in level.props:
		var prop = level.props[key]
		if not is_instance_valid(prop) or not prop.is_visible_in_tree():
			continue
		var candidate := _object_topic(key)
		if candidate.is_empty() or unlocked.has(candidate):
			continue
		if not view.has_point(prop.get_global_transform_with_canvas().origin):
			continue
		var distance: float = level.player.position.distance_to(prop.position)
		if distance < closest:
			closest = distance
			object_id = key
			topic = candidate
	if not topic.is_empty():
		discover(topic, object_id)
	elif not unlocked.has("warmth") and level.SAVE_LEVEL <= 2 and level.warmth < 85:
		discover("warmth", "Camp")
	elif not unlocked.has("coat") and level.SAVE_LEVEL >= 3:
		discover("coat", "player")
	elif not unlocked.has("map") and level.overview:
		discover("map", "waypoint0")
	elif (
		not unlocked.has("movement")
		and level.player.position.distance_to(level.iso(level.SPAWN)) > 55
	):
		discover("movement", "player")


func _fly_to_guides(topic: String) -> void:
	var token: Label = preload("res://UI/Guides/GuideDiscoveryToast.tscn").instantiate()
	token.text = "✓ " + Visual.LESSONS[topic][0] + " → Guides"
	add_child(token, true)
	var size := get_viewport().get_visible_rect().size
	token.position = size * .5 - Vector2(120, 20)
	_layout()
	var destination := help_button.get_global_rect().get_center()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	(
		tween
		. tween_property(token, "position", destination, .85)
		. set_delay(.6)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(token, "scale", Vector2(.15, .15), .85).set_delay(.6)
	tween.parallel().tween_property(token, "modulate:a", 0.0, .85).set_delay(.6)
	tween.chain().tween_callback(token.queue_free)
	tween.chain().tween_callback(
		func():
			help_button.modulate = Color("ffe09a")
			var pulse := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			pulse.tween_property(help_button, "modulate", Color.WHITE, .45)
	)


func _open() -> void:
	previous_pause = get_tree().paused
	if previous_pause:
		level.pause_panel.hide()
	opened = true
	shade.show()
	help_button.hide()
	hint_card.hide()
	get_tree().paused = true
	level.player.reset_touch_movement()
	level.player.velocity = Vector2.ZERO
	level.mobile_controls.set_enabled(false)
	level.interaction_prompt.hide()


func close() -> void:
	_help_closed()
	discovery_cooldown = 2.5
	return_to_altar = false
	return_to_help = false
	contextual_demo_topic = ""
	if is_instance_valid(guide):
		remove_child(guide)
		guide.queue_free()
	guide = null
	visual = null
	opened = false
	shade.hide()
	get_tree().paused = previous_pause
	level.pause_panel.visible = previous_pause
	level.mobile_controls.set_enabled(not previous_pause and not level.complete and not level.overview)


func _clear() -> void:
	if is_instance_valid(guide):
		remove_child(guide)
		guide.queue_free()
	guide = null
	visual = null
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()


func help_context() -> Dictionary:
	return _next_action()


func open_help() -> void:
	if level.dead or level.complete: return
	if not opened: _open()
	return_to_altar = false
	_show_help()


func _show_help() -> void:
	return_to_help = false
	contextual_demo_topic = ""
	_clear()
	shade.show()
	var context := help_context()
	column.add_child(_label("Professor reminder", 25), true)
	column.add_child(_label(context.get("title", "Next action"), 21), true)
	column.add_child(_label(context.get("action", level.professor_hint()), 20), true)
	column.add_child(_label("Help and demonstrations are always free. Try each step in the garden.", 17), true)
	var demo := _button("Show demonstration", _help_demonstration)
	demo.name = "HelpDemo"
	demo.disabled = not Visual.LESSONS.has(context.get("topic", ""))
	column.add_child(demo, true)
	var library := _button("All Guides", _help_library)
	library.name = "HelpGuides"
	column.add_child(library, true)
	var back := _button("Back to Pause" if previous_pause else "Return to garden", _acknowledge_help)
	back.name = "HelpReturn"
	column.add_child(back, true)
	_help_guidance_shown()

func _help_guidance_shown() -> void:
	pass

func _help_guidance_acknowledged() -> void:
	pass

func _help_closed() -> void:
	pass

func _acknowledge_help() -> void:
	_help_guidance_acknowledged()
	close()


func _help_demonstration() -> void:
	contextual_demo_topic = help_context().get("topic", "")
	if not Visual.LESSONS.has(contextual_demo_topic): return
	return_to_help = true
	demo_topic = contextual_demo_topic
	_show_demo()


func _help_library() -> void:
	return_to_help = false
	contextual_demo_topic = ""
	var topics := allowed_topics()
	demo_topic = str(topics[0]) if not topics.is_empty() else ""
	_show_demo()


func open_demo(topic: String = "") -> void:
	show()
	if opened:
		return
	var chosen: String = focus_data.get("topic", level_topics()[0]) if topic.is_empty() else topic
	var unlocked := allowed_topics()
	demo_topic = (
		chosen if unlocked.has(chosen) else (str(unlocked[0]) if not unlocked.is_empty() else "")
	)
	demo_step = 0
	_open()
	_show_demo()


func _select_topic(topic: String) -> void:
	demo_topic = topic
	demo_step = 0
	_show_demo()


func _show_demo() -> void:
	_clear()
	shade.hide()
	guide = preload("res://UI/Guides/GuidesLibrary.tscn").instantiate()
	guide.support = self
	add_child(guide, true)


func return_from_guide() -> void:
	if return_to_help:
		_show_help()
	elif return_to_altar:
		return_to_altar = false
		_show_question()
	else:
		close()


func open_altar() -> void:
	if level.SAVE_LEVEL > 3:
		return
	if passed():
		level._message("Knowledge seal earned. " + level.professor_hint())
		return
	_open()
	_show_question()


func _show_question() -> void:
	shade.show()
	_clear()
	waiting_continue = false
	var bank: Array = level_questions()
	var question: Array = bank[level.learning_answers]
	column.add_child(_label("LEVEL %d KNOWLEDGE ALTAR" % level.SAVE_LEVEL, 24), true)
	column.add_child(
		_label(
			(
				"Question %d/%d · Changes of state of matter"
				% [level.learning_answers + 1, bank.size()]
			),
			16
		),
		true
	)
	column.add_child(_label(question[1], 21), true)
	for i in range(question[2].size()):
		column.add_child(_button(question[2][i], answer.bind(i)), true)
	feedback = _label("", 17)
	column.add_child(feedback, true)
	column.add_child(_button("Review this state change", reviewStateChange.bind(question[0])), true)
	column.add_child(_button("Return later", close), true)


func reviewStateChange(topic: String) -> void:
	demo_topic = topic
	demo_step = 0
	_show_altar_demo()


func _show_altar_demo() -> void:
	if not allowed_topics().has(demo_topic):
		feedback.text = "Discover this mechanism in the world to unlock its gameplay guide."
		return
	return_to_altar = true
	_show_demo()


func answer(choice: int) -> void:
	if waiting_continue or passed():
		return
	var question: Array = level_questions()[level.learning_answers]
	if choice != question[3]:
		feedback.text = "Try again. " + question[4]
		level._sfx("warning")
		return
	waiting_continue = true
	level.learning_answers += 1
	level._persist_run()
	_clear()
	column.add_child(_label("Correct!", 25), true)
	column.add_child(_label(question[4], 21), true)
	column.add_child(
		_button("Earn knowledge seal" if passed() else "Next question", _continue_question), true
	)


func _continue_question() -> void:
	if not passed():
		_show_question()
		return
	level.props.learning_altar.active = true
	level._save_checkpoint(int(level.checkpoint.get("puzzle", -1)))
	level._message("Knowledge seal earned! Finish any remaining objectives, then open the exit.")
	close()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_J and get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if opened and event.physical_keycode in [KEY_J, KEY_ESCAPE]:
		return_from_guide()
		get_viewport().set_input_as_handled()
	elif (
		event.physical_keycode == KEY_J
		and not get_tree().paused
		and not level.overview
		and not level.complete
		and not level.dead
	):
		return_to_altar = false
		open_demo()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	cue_time += delta
	discovery_cooldown = maxf(0, discovery_cooldown - delta)
	discovery_tick += delta
	if discovery_tick >= .25:
		discovery_tick = 0
		_check_discovery()
	if not is_instance_valid(level.player):
		return
	focus_data = _next_action()
	help_button.visible = not get_tree().paused and not level.complete and not level.overview and not opened
	_layout()
	hint_title.text = focus_data.get("title", "NEXT ACTION")
	hint_body.text = focus_data.get("action", "")
	cues.queue_redraw()


func _draw_cues() -> void:
	if opened or level.overview or level.complete or focus_data.is_empty():
		return
	var target: String = focus_data.get("target", "")
	if not level.props.has(target):
		return
	var store = get_node("/root/PlayerSave")
	var discovery_id: String = store.instance_id(level.SAVE_ZONE,level.SAVE_LEVEL,target)+":"+str(focus_data.get("topic",""))
	if store.guide_records().has(discovery_id) or store.discovered_guides().has(str(focus_data.get("topic",""))):
		return
	var at: Vector2 = level.props[target].position
	var color := (
		Color("ffcd78")
		if focus_data.get("topic", "") in ["melting", "fuel_air", "conduction", "pressure"]
		else Color("9aebff")
	)
	cues.draw_set_transform(at, 0, Vector2(1, .45))
	cues.draw_arc(Vector2.ZERO, 22 + sin(cue_time * 3) * 3, 0, TAU, 36, Color(color, .8), 3, true)
	cues.draw_set_transform(Vector2.ZERO)
	var tip := at + Vector2(0, -125 + sin(cue_time * 3) * 4)
	cues.draw_colored_polygon(
		PackedVector2Array([tip + Vector2(-8, 0), tip + Vector2(8, 0), tip + Vector2(0, 12)]), color
	)
	# Energy leaves the water while cooling; distinguish it from blue water flow.
	if level.SAVE_LEVEL == 3:
		for i in range(4):
			if (
				not level.cooling[i]
				or level.flowing[i]
				or level.water[i] < 1
				or level.frozen[i] >= 1
			):
				continue
			if i >= 2 and not level.cores_installed[i - 2]:
				continue
			if i == 3 and level.routing != 2:
				continue
			var start: Vector2 = level.props["pool%d" % i].position + Vector2(0, -48)
			var end: Vector2 = level.props["cooler%d" % i].position + Vector2(0, -100)
			for pulse in range(4):
				var t := fposmod(cue_time * .3 + pulse * .25, 1.0)
				var point := start.lerp(end, t) + Vector2(0, -sin(t * PI) * 40)
				var direction := (end - start + Vector2(0, -cos(t * PI) * PI * 40)).normalized()
				var side := direction.orthogonal() * 4
				cues.draw_colored_polygon(
					PackedVector2Array(
						[
							point + direction * 7,
							point - direction * 4 + side,
							point - direction * 4 - side
						]
					),
					Color("ffb866")
				)


func _goal(target: String, title: String, action: String, topic: String) -> Dictionary:
	return {"target": target, "title": title, "action": action, "topic": topic}


func _next_action() -> Dictionary:
	if level.SAVE_LEVEL >= 4:
		var index := -1
		var distance := INF
		for i in range(level.controls.size()):
			if level.claimed[i]:
				continue
			var target: Vector2 = (
				level.props[("altar" if level.circuits_done[i] else "sluice") + str(i)].position
			)
			var value: float = level.player.position.distance_to(target)
			if value < distance:
				distance = value
				index = i
		if index < 0:
			return _goal(
				"exit",
				"ASSEMBLE / LEAVE",
				level.professor_hint(),
				"assembly" if level.SAVE_LEVEL == 6 else "cycle"
			)
		var i := index
		var tag := "CIRCUIT %d · " % [i + 1]
		var specialty: String = level.specialties[i]
		if level.circuits_done[i]:
			return _goal(
				"altar%d" % i,
				tag + "EARN REWARD",
				"Cross stable ice and answer this altar.",
				"cycle"
			)
		if specialty == "pressure" and level.auxiliary[i] != 1:
			return _goal(
				"aux%d" % i,
				tag + "VENT FIRST",
				"Open pressure release. Watch the needle move into green.",
				"pressure"
			)
		if level.source_melt[i] < 1:
			return _goal(
				"pump%d" % i,
				tag + "1. MELT SOURCE",
				(
					"Choose HEAT on the exchanger."
					if level.pump_modes[i] != 1
					else "Watch source ice shrink into water: %d%%." % [level.source_melt[i] * 100]
				),
				"melting" if level_topics().has("melting") else "cycle"
			)
		if specialty == "routing" and level.auxiliary[i] != 2:
			return _goal(
				"aux%d" % i,
				tag + "DIRECT WATER",
				"Point selector to Cooling Station before filling.",
				"routing"
			)
		if level.basin_water[i] < 1:
			return _goal(
				("sluice" if not level.sluices[i] else "basin") + str(i),
				tag + "2. FILL BASIN",
				(
					"OPEN the sluice."
					if not level.sluices[i]
					else "Blue water rises in the basin: %d%%." % [level.basin_water[i] * 100]
				),
				"cycle"
			)
		if level.sluices[i]:
			return _goal(
				"sluice%d" % i,
				tag + "3. CLOSE SLUICE",
				"Basin full. CLOSE its valve before cooling.",
				"freezing"
			)
		if not level._aux_ready(i):
			return _goal("aux%d" % i, tag + "SAFEGUARD", level._aux_text(i), specialty)
		if level.basin_ice[i] < 1:
			return _goal(
				("pump" if level.pump_modes[i] != 2 else "basin") + str(i),
				tag + "4. REMOVE HEAT",
				(
					"Choose COOL. Heat must LEAVE the water."
					if level.pump_modes[i] != 2
					else "Watch white frost spread: %d%%." % [level.basin_ice[i] * 100]
				),
				"freezing"
			)
		return _goal(
			"aux%d" % i,
			tag + "RELEASE LIFT",
			"Recovered heat is stored. RELEASE the lift to raise it.",
			"recovery"
		)
	if level.SAVE_LEVEL == 3:
		for i in range(4):
			if level.frozen[i] >= 1:
				continue
			if i == 3 and level.routing != 2:
				return _goal(
					"diverter",
					"DIRECT WATER",
					"Point brass dial toward Cooling Station.",
					"routing"
				)
			if level.water[i] < 1:
				return _goal(
					"sluice%d" % i,
					"FILL THE BASIN",
					"OPEN sluice; watch water level rise.",
					"freezing"
				)
			if level.flowing[i]:
				return _goal(
					"sluice%d" % i,
					"CLOSE THE SLUICE",
					"Full basin: CLOSE this valve before cooling.",
					"freezing"
				)
			if i >= 2 and not level.cores_installed[i - 2]:
				return _goal(
					("socket%d" % (i - 2)) if level.cores_found[i - 2] else ("core%d" % (i - 2)),
					"POWER THE COOLER",
					"Collect coolant crystal, then install it in this socket.",
					"freezing"
				)
			return _goal(
				"cooler%d" % i,
				"REMOVE HEAT",
				(
					"Switch this cooling station ON."
					if not level.cooling[i]
					else (
						"Heat leaves water. Frost spreads to solid ice: %d%%."
						% [level.frozen[i] * 100]
					)
				),
				"freezing"
			)
	else:
		for i in range(3):
			if level.melted[i] >= 1:
				continue
			if i == 1:
				if not level.has_wood:
					return _goal(
						"wood", "GET FUEL", "Collect wood for the second heater.", "fuel_air"
					)
				if not level.has_blades:
					return _goal(
						"blades",
						"GET FAN BLADES",
						"Find blades to restore the heater's airflow.",
						"fuel_air"
					)
				if not level.fan_installed:
					return _goal(
						"vent",
						"REPAIR FAN",
						"Install blades. Watch fan spin toward heater.",
						"fuel_air"
					)
			if i < 2 and not level.lit[i]:
				return _goal(
					"brazier%d" % i,
					"ADD HEAT",
					"Light this heater. Follow orange heat pulses.",
					"melting"
				)
			if i == 2 and not level.receiver_lit:
				return _goal(
					"mirror",
					"ALIGN THE BEAM",
					"Rotate mirrors so the beam reaches the receiver.",
					"reflection"
				)
			if level.SAVE_LEVEL == 2 and level.valve_modes[i] != 1:
				return _goal(
					"valve%d" % i,
					"CHOOSE COPPER",
					"Copper carries heat to the radiator. Wood insulates.",
					"conduction"
				)
			return _goal(
				"ice%d" % i,
				"WATCH ICE MELT",
				"Ice shrinks as heat enters: %d%% melted." % [level.melted[i] * 100],
				"conduction" if level.SAVE_LEVEL == 2 else "melting"
			)
	if level.props.has("learning_altar") and not passed():
		return _goal(
			"learning_altar",
			"EARN KNOWLEDGE SEAL",
			(
				"Answer questions about changes of state: %d/%d."
				% [level.learning_answers, level_questions().size()]
			),
			level_topics()[0]
		)
	for i in range(level.CRYSTALS.size()):
		if not level.collected.has(i):
			return _goal(
				"crystal%d" % i,
				"COLLECT REMAINING SIGIL",
				level.professor_hint(),
				level_topics()[0]
			)
	return _goal("exit", "EXIT READY", "Open the sanctuary gate.", level_topics()[0])

func level_questions() -> Array:
	var configured: Array = preload("res://Scripts/Content/level_registry.gd").questions(level.SAVE_ZONE, level.SAVE_LEVEL)
	return configured if not configured.is_empty() else BANKS.get(level.SAVE_LEVEL, []).duplicate(true)

