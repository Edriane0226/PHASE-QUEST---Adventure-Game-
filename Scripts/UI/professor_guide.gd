extends CanvasLayer
signal closed
## In-world choices and subtitles, with isolated, resettable map demonstrations.
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
const Scenario = preload("res://Scripts/UI/map_lesson_scenario.gd")
var level: Node
var root_ui: Control
var dialog: Control
var blur: ColorRect
var shade: ColorRect
var choices: VBoxContainer
var subtitle: Label
var speaker: Label
var scene: SubViewportContainer
var section := "menu"
var is_open := false
var continue_hint: Label
var last_advance_frame := -1
var onboarding := false
var continuation := ""
var focus_tween: Tween
var focus_state: Dictionary = {}


func _ready() -> void:
	root_ui = $ViewRoot
	blur = $ViewRoot/BackgroundBlur
	shade = $ViewRoot/Backdrop
	dialog = $ViewRoot/Dialog
	speaker = $ViewRoot/Dialog/Speaker
	subtitle = $ViewRoot/Dialog/ContentText
	continue_hint = $ViewRoot/Dialog/ContinueHint
	choices = $ViewRoot/Dialog/Choices
	preload("res://Scripts/UI/quest_ui.gd").apply(dialog)
	root_ui.gui_input.connect(_continue_input)
	if OS.has_feature("android"):
		blur.material = null
		blur.color = Color(0.02, 0.04, 0.06, 0.14)
	_layout()
	get_viewport().size_changed.connect(_layout)
	root_ui.hide()


func _layout() -> void:
	var visible_size := get_viewport().get_visible_rect().size
	var physical := Vector2(DisplayServer.window_get_size())
	if DisplayServer.get_name() == "headless":
		physical = visible_size
	var scale_factor := maxf(1, visible_size.x / maxf(1, physical.x))
	dialog.scale = Vector2.ONE * scale_factor
	dialog.size = visible_size / scale_factor
	if is_open:
		_position_text()


func _process(_delta: float) -> void:
	if is_open:
		_position_text()


func _position_text() -> void:
	var size := dialog.size
	speaker.position = Vector2(size.x * 0.08, size.y * 0.72)
	speaker.size = Vector2(size.x * 0.84, 30)
	subtitle.position = Vector2(size.x * 0.08, size.y * 0.72 + 34)
	subtitle.size = Vector2(size.x * 0.84, size.y * 0.20)
	continue_hint.position = Vector2(size.x * 0.08, size.y * 0.94)
	continue_hint.size = Vector2(size.x * 0.84, 24)
	var width := minf(300, size.x - 36)
	choices.size.x = width
	choices.position = Vector2(
		maxf(18, size.x - width - 24), maxf(20, (size.y - choices.size.y) * 0.5)
	)


func open() -> void:
	if is_open:
		return
	is_open = true
	level.player.call("reset_touch_movement")
	level.face_professor()
	level.mobile_controls.set_enabled(false)
	level.interaction_prompt.hide()
	level.hud_root.hide()
	get_tree().paused = true
	root_ui.show()
	_choose("menu")


func open_controls() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	root_ui.show()
	_choose("play")


func start_welcome() -> void:
	onboarding = true
	open()
	_begin_welcome_focus()
	var store = get_node("/root/PlayerSave")
	var explorer: String = str(store.data["player_name"])
	if not store.mark_melting_intro_seen():
		level._message(store.last_error)
	_intro_line(
		(
			"Welcome to The Melting Gardens, %s! I'm Professor Scaldwell. I'll help you discover how heat can change the world around us."
			% explorer
		),
		"welcome"
	)


func _begin_welcome_focus() -> void:
	var camera: Camera2D = level.camera
	if focus_tween and focus_tween.is_valid():
		focus_tween.kill()
	focus_state = {
		"position": camera.position,
		"zoom": camera.zoom,
		"process_mode": camera.process_mode,
		"callback": camera.process_callback
	}
	# Keep the camera moving while the conversation pauses gameplay.
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	var center: Vector2 = (
		(level.player.global_position + level.props.professor.global_position) * 0.5
		+ Vector2(0, -22)
	)
	var target: Vector2 = camera.get_parent().to_local(center)
	focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	focus_tween.tween_property(camera, "position", target, 0.85)
	focus_tween.tween_property(camera, "zoom", focus_state.zoom * 1.35, 0.85)
	camera.reset_physics_interpolation()


func _end_welcome_focus() -> void:
	if focus_state.is_empty() or not is_instance_valid(level):
		return
	if focus_tween and focus_tween.is_valid():
		focus_tween.kill()
	var camera: Camera2D = level.camera
	var original := focus_state.duplicate()
	focus_state.clear()
	focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	focus_tween.tween_property(camera, "position", original.position, 0.55)
	focus_tween.tween_property(camera, "zoom", original.zoom, 0.55)
	focus_tween.chain().tween_callback(
		func():
			camera.process_mode = original.process_mode
			camera.process_callback = original.callback
			camera.reset_physics_interpolation()
	)


func _intro_line(text: String, next: String) -> void:
	section = "welcome"
	_clear_choices()
	_clear_scene()
	blur.hide()
	shade.color.a = 0.18
	subtitle.text = text
	continuation = next
	continue_hint.show()


func close() -> void:
	if not is_open:
		return
	_end_welcome_focus()
	_clear_scene()
	is_open = false
	onboarding = false
	continuation = ""
	root_ui.hide()
	get_tree().paused = false
	if is_instance_valid(level):
		level.hud_root.show()
		level.mobile_controls.set_enabled(not level.dead and not level.complete)
		level.player.call("reset_touch_movement")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if (
		is_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode in [KEY_SPACE, KEY_ENTER]
	):
		_next_dialogue()
		get_viewport().set_input_as_handled()
	if (
		is_open
		and event is InputEventKey
		and event.pressed
		and event.physical_keycode == KEY_ESCAPE
	):
		close()
		get_viewport().set_input_as_handled()


func _continue_input(event: InputEvent) -> void:
	var pressed: bool = (
		(
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if not pressed or not is_open:
		return
	if continuation.is_empty() and (not is_instance_valid(scene) or not scene.running):
		return
	var frame := Engine.get_process_frames()
	if frame == last_advance_frame:
		return
	last_advance_frame = frame
	_next_dialogue()
	root_ui.accept_event()


func _choose(value: String) -> void:
	section = value
	continuation = ""
	_clear_choices()
	_clear_scene()
	continue_hint.hide()
	blur.visible = value in ["lesson", "play"]
	shade.color.a = 0.36 if blur.visible else 0.18
	if value == "menu":
		subtitle.text = "Shall we investigate melting, practice the trail, or think through your next puzzle?"
		_menu_choices()
	elif value == "talk":
		subtitle.text = level.professor_hint()
		_menu_choices()
	else:
		subtitle.text = "Let's watch what happens at the frozen crossing."
		scene = Scenario.new()
		scene.mode = value
		scene.position = Vector2(dialog.size.x * 0.04, dialog.size.y * 0.03)
		scene.size = Vector2(dialog.size.x * 0.92, dialog.size.y * 0.65)
		scene.narrated.connect(func(text: String): subtitle.text = text)
		scene.finished.connect(_scenario_finished)
		dialog.add_child(scene, true)
		dialog.move_child(scene, 0)
		_scenario_choices()
	_position_text()


func _menu_choices() -> void:
	if is_instance_valid(level.learning_support):
		_choice(
			"Show the mechanic step by step",
			func():
				close()
				level.learning_support.open_demo()
		)
	_choice("Lesson", _choose.bind("lesson"))
	_choice("How to Play", _choose.bind("play"))
	_choice("Just Talk", _choose.bind("talk"))
	_choice("Goodbye", close)


func _scenario_finished() -> void:
	_clear_choices()
	continue_hint.hide()
	if section == "lesson":
		subtitle.text = "What happened to the ice when it gained heat?"
		_choice("It melted into liquid water.", _answer.bind(true))
		_choice("It disappeared completely.", _answer.bind(false))
		_choice("It became a new substance.", _answer.bind(false))
	else:
		subtitle.text = "Drag the joystick to move and hold Run to go faster. Use the nearby action prompt for objects. Open the Checkpoint map to revisit an attuned pin. Fire is a separate control."
		if onboarding:
			continuation = "farewell"
			continue_hint.show()
		else:
			_end_choices()


func _answer(correct: bool) -> void:
	if not correct:
		subtitle.text = "Look at the liquid left behind. It is still water. What change of state did you observe?"
		return
	subtitle.text = "Exactly! Melting is a physical change from solid to liquid. The water molecules change their arrangement and movement, but each still has one oxygen and two hydrogen atoms."
	_clear_choices()
	if onboarding:
		continuation = "controls"
		continue_hint.show()
	else:
		_end_choices()


func _end_choices() -> void:
	_choice("Replay the scenario", _replay)
	if not is_instance_valid(level):
		_choice("Return to main menu", close)
		return
	_choice("Back to conversation", _choose.bind("menu"))
	_choice("Back to the trail", close)


func _offer_controls() -> void:
	_intro_line(
		"That same change will help you open the frozen trails ahead. You know the science now—would you like me to show you how to move around and use the controls?",
		""
	)
	continue_hint.hide()
	_choice("Yes, show me how to play.", _accept_controls)
	_choice("I'll explore on my own.", _skip_controls)


func _accept_controls() -> void:
	_intro_line(
		"Let's try it together! We'll start with moving, then sprinting and interacting with objects. Take your time; touch to continue whenever you're ready.",
		"play"
	)


func _skip_controls() -> void:
	_intro_line(
		"Of course! Follow the lanterns to the first frozen crossing and try its heater. If you need a hand, come back and choose How to Play. I'll be right here.",
		"finish"
	)


func _replay() -> void:
	_clear_choices()
	scene.reset_scenario()
	_scenario_choices()


func _scenario_choices() -> void:
	continue_hint.show()


func _next_dialogue() -> void:
	if not continuation.is_empty():
		var next := continuation
		continuation = ""
		match next:
			"welcome":
				_intro_line(
					"You've arrived at just the right time. Ice is blocking the trails, but a little science can help us open them. Let's first discover what happens when ice gains heat.",
					"lesson"
				)
			"lesson":
				_intro_line(
					"Take a closer look at this crossing with me. The magnified view will show the tiny water molecules inside the ice. Watch what changes when we turn on the heater.",
					"begin_lesson"
				)
			"begin_lesson":
				_choose("lesson")
			"controls":
				_offer_controls()
			"play":
				_choose("play")
			"farewell":
				_intro_line(
					"That's everything you need to begin. Now it's your turn to use what we've learned! Follow the lanterns to the first frozen crossing and try its heater. Come back whenever you want a lesson or a clue. Stay warm, explorer!",
					"finish"
				)
			"finish":
				close()
		return
	if is_instance_valid(scene) and scene.running:
		scene.advance_dialogue()


func _clear_scene() -> void:
	if is_instance_valid(scene):
		dialog.remove_child(scene)
		scene.queue_free()
	scene = null


func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	choices.size.y = 0


func _choice(text: String, action: Callable) -> void:
	var button: Button = preload("res://UI/Controls/DialogueChoice.tscn").instantiate()
	button.text = text
	button.custom_minimum_size.x = minf(300, dialog.size.x - 36)
	button.pressed.connect(action)
	choices.add_child(button, true)
