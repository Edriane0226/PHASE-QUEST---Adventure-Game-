extends "res://Scripts/UI/gardens_learning_support.gd"
func guide_entry(topic: String) -> Dictionary:
	var entry := super.guide_entry(topic)
	if topic == "melting" and entry.get("zone") == "melting_and_freezing" and entry.get("level") == 1 and level.has_method("device_first_task"):
		entry = entry.duplicate(true)
		entry.instructions = "Select Thermal at the top of the dial. Face nearby first ice with a clear path; hold Fire to add heat. Release to stop. Solid ice melts into liquid water."
	return entry

func _object_topic(id: String) -> String:
	if level.has_method("device_first_task"):
		if id in ["heater_module","heater_dock","brazier0"]: return ""
		if id == "ice1": return "fuel_air"
		if id == "ice2": return "reflection"
	return super._object_topic(id)

func _layout() -> void:
	_layout_help_panel()
	if is_instance_valid(level):
		level.stats_panel.hide()
	if is_instance_valid(help_button):
		help_button.text = "Guides"
		help_button.visible = not get_tree().paused and not opened and not level.complete and not level.overview

func _next_action() -> Dictionary:
	if level.has_method("device_first_task"):
		return {"title":level.current_quest()[0], "action":level.professor_hint(), "topic":help_context().topic}
	if level.module_state=="ground": return _goal("heater_module","HEATER MODULE","Carry the module to its dock.","melting")
	if level.module_state=="carried": return _goal("heater_dock","CONNECT THE MODULE","Place the module in its matching dock.","melting")
	return super._next_action()

func help_context() -> Dictionary:
	var quest: PackedStringArray = level.current_quest()
	var topic := "exit"
	if level.melted[0] < 1.0 or (not level.has_method("device_first_task") and (level.module_state != "docked" or not level.lit[0])):
		topic = "melting"
	elif level.carry_item in ["wood", "blades"] or not level.has_wood or not level.has_blades or not level.fan_installed or not level.lit[1] or level.melted[1] < 1.0:
		topic = "fuel_air"
	elif level.melted[2] < 1.0: topic = "reflection"
	elif level.collected.size() < 6: topic = "crystals"
	return {"title":quest[0], "action":level.professor_hint(), "topic":topic}

func allowed_topics() -> Array:
	var topics := super.allowed_topics()
	topics.erase("altar")
	return topics

func _help_guidance_shown() -> void:
	level.achievement_events.help_shown()

func _help_guidance_acknowledged() -> void:
	level.achievement_events.help_acknowledged()
	if not level._persist_run():
		level._message(get_node("/root/PlayerSave").last_error)

func _help_closed() -> void:
	level.achievement_events.help_puzzle = ""

func _input(event: InputEvent) -> void:
	if is_instance_valid(level) and level.story.is_open: return
	super._input(event)

func open_observation() -> void:
	_open()
	_clear()
	var question: Dictionary = preload("res://Scripts/Content/level_registry.gd").definition(level.SAVE_ZONE, level.SAVE_LEVEL).practice_question
	column.add_child(_label("Observe melting", 24), true)
	column.add_child(_label(question.text, 21), true)
	for i in range(question.choices.size()):
		var button := _button(question.choices[i], _answer_observation.bind(i))
		button.name = "ObservationAnswer%d" % i
		column.add_child(button, true)
	feedback = _label("", 18)
	column.add_child(feedback, true)
	var back := _button("Return to garden", close)
	back.name = "ObservationReturn"
	column.add_child(back, true)

func _answer_observation(choice: int) -> void:
	var question: Dictionary = preload("res://Scripts/Content/level_registry.gd").definition(level.SAVE_ZONE, level.SAVE_LEVEL).practice_question
	feedback.text = ("Correct! " if choice == question.correct else "Try again. ") + question.feedback
