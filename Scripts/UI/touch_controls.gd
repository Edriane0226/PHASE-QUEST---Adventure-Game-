extends Control
## Touch ownership uses saved button rectangles, including simultaneous stick/action fingers.
signal movement_changed(value: Vector2)
signal sprint_changed(value: bool)
signal interact_requested
signal fire_pressed
signal fire_released
signal map_requested
signal pause_requested
signal jump_requested
signal layout_changed
@export var preview_on_desktop := false
@export var stick_radius := 58.0
@export var dead_zone := 0.12
var touch_mode := false
var controls_enabled := true
var interact_available := false
var active_finger := -1
var action_fingers: Dictionary = {}
var excluded_controls: Array[Control] = []
var button_rects: Dictionary = {}
var safe_rect := Rect2()
var movement := Vector2.ZERO
var thumb_offset := Vector2.ZERO
var base_position := Vector2.ZERO
var _thumb_home := Vector2.ZERO
var radial_input: Node
var _has_focus := true
var _suspended := false
var context_prompt: Button
var context_allowed: Callable
var context_pointer := -1
var _context_token: Array = []


func _ready() -> void:
	touch_mode = preview_on_desktop or OS.has_feature("android") or DisplayServer.is_touchscreen_available()
	_thumb_home = $Joystick/Thumb.position
	visible = touch_mode and controls_enabled
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout.call_deferred()


func _refresh_layout() -> void:
	reset_input()
	safe_rect = preload("res://Scripts/UI/responsive_menu_layout.gd").safe_area(get_viewport())
	var compact := safe_rect.size.y < 500
	var unit := 0.78 if compact else 1.0
	var right := safe_rect.end.x
	var bottom := safe_rect.end.y
	var action_layout := {
		"fire":Rect2(Vector2(right-128*unit,bottom-142*unit),Vector2(96,96)*unit),
		"jump":Rect2(Vector2(right-226*unit,bottom-106*unit),Vector2(72,72)*unit),
		"sprint":Rect2(Vector2(right-123*unit,bottom-238*unit),Vector2(68,68)*unit),
		"map":Rect2(Vector2(right-210, safe_rect.position.y+20),Vector2(88,48)),
		"pause":Rect2(Vector2(right-108, safe_rect.position.y+20),Vector2(88,48))
	}
	for action in action_layout:
		var button: Control = get_node("Buttons/"+action)
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = action_layout[action].position
		button.size = action_layout[action].size
	var stick: Control = $Joystick
	stick.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stick.size = Vector2(132,132)*unit
	stick.position = Vector2(safe_rect.position.x+38*unit,bottom-182*unit)
	$Joystick/Thumb.size = Vector2(46,46)*unit
	_thumb_home = (stick.size-$Joystick/Thumb.size)/2
	$Joystick/Thumb.position = _thumb_home
	stick_radius = stick.size.x*0.38
	for action in ["fire","sprint","jump","map","pause"]:
		button_rects[action] = get_node("Buttons/"+action).get_global_rect()
	base_position = $Joystick.get_global_rect().get_center()
	layout_changed.emit()


func set_enabled(value: bool) -> void:
	controls_enabled = value
	reset_input()
	visible = touch_mode and value


func reset_input() -> void:
	if is_instance_valid(radial_input): radial_input.cancel()
	var was_firing := action_fingers.values().has("fire")
	context_pointer = -1
	_context_token.clear()
	if is_instance_valid(context_prompt): context_prompt.set_pressed_no_signal(false)
	active_finger = -1
	action_fingers.clear()
	if was_firing: fire_released.emit()
	thumb_offset = Vector2.ZERO
	movement = Vector2.ZERO
	movement_changed.emit(movement)
	sprint_changed.emit(false)
	if is_node_ready():
		$Joystick/Thumb.position = _thumb_home
		for action in button_rects: get_node("Buttons/"+action).set_pressed_no_signal(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _has_focus = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _has_focus = true
	elif what == NOTIFICATION_APPLICATION_PAUSED: _suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _suspended = false
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]:
		reset_input()


func handle_touch(index: int, point: Vector2, pressed: bool, canceled := false) -> bool:
	if not controls_enabled or not _has_focus or _suspended: return false
	if context_pointer != -1 and index == context_pointer:
		if not pressed or canceled:
			var activate := not canceled and _context_available() and _context_token == _context_identity() and context_prompt.get_global_rect().has_point(point)
			context_pointer = -1
			_context_token.clear()
			if is_instance_valid(context_prompt): context_prompt.set_pressed_no_signal(false)
			if activate: interact_requested.emit()
		return true
	# Existing owners keep their role even after dragging across another control.
	if not _owns_action_or_movement(index) and is_instance_valid(radial_input):
		if radial_input.handle_touch(index,point,pressed,canceled): return true
	if not _owns_action_or_movement(index) and pressed and not canceled and context_pointer == -1 and _context_available() and context_prompt.get_global_rect().has_point(point):
		context_pointer = index
		_context_token = _context_identity()
		context_prompt.set_pressed_no_signal(true)
		return true
	if not touch_mode or not visible: return false
	if not pressed or canceled:
		if index==active_finger:
			active_finger = -1
			thumb_offset = Vector2.ZERO
			movement = Vector2.ZERO
			movement_changed.emit(movement)
			$Joystick/Thumb.position = _thumb_home
			return true
		if action_fingers.has(index):
			var action: String = action_fingers[index]
			action_fingers.erase(index)
			get_node("Buttons/"+action).set_pressed_no_signal(action_fingers.values().has(action))
			if action=="sprint": sprint_changed.emit(action_fingers.values().has("sprint"))
			if action=="fire": fire_released.emit()
			return true
		return false
	if index==active_finger or action_fingers.has(index): return true
	for action: String in button_rects:
		if not button_rects[action].has_point(point): continue
		if action == "fire" and action_fingers.values().has("fire"): return true
		action_fingers[index] = action
		get_node("Buttons/"+action).set_pressed_no_signal(true)
		match action:
			"fire": fire_pressed.emit()
			"sprint": sprint_changed.emit(true)
			"jump": jump_requested.emit()
			"map": map_requested.emit()
			"pause": pause_requested.emit()
		return true
	if active_finger!=-1 or not $Joystick.get_global_rect().grow(20).has_point(point): return false
	for control in excluded_controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(point): return false
	active_finger = index
	return handle_drag(index,point)


func handle_drag(index: int, point: Vector2) -> bool:
	if not controls_enabled or not _has_focus or _suspended: return false
	if context_pointer != -1 and index == context_pointer:
		if is_instance_valid(context_prompt): context_prompt.set_pressed_no_signal(_context_available() and _context_token == _context_identity() and context_prompt.get_global_rect().has_point(point))
		return true
	if not _owns_action_or_movement(index) and is_instance_valid(radial_input):
		return radial_input.handle_drag(index,point)
	if not controls_enabled or active_finger==-1 or index!=active_finger: return action_fingers.has(index)
	thumb_offset = (point-base_position).limit_length(stick_radius)
	var magnitude := thumb_offset.length()/stick_radius
	movement = thumb_offset.normalized()*((magnitude-dead_zone)/(1-dead_zone)) if magnitude>dead_zone else Vector2.ZERO
	$Joystick/Thumb.position = _thumb_home+thumb_offset
	movement_changed.emit(movement)
	return true

func _owns_action_or_movement(index: int) -> bool:
	return (active_finger != -1 and index == active_finger) or action_fingers.has(index) or (context_pointer != -1 and index == context_pointer)

func _context_identity() -> Array:
	return [context_prompt.get_meta("context_target",0),context_prompt.get_meta("context_action",context_prompt.text)]

func _context_available() -> bool:
	return is_instance_valid(context_prompt) and context_prompt.is_visible_in_tree() and not context_prompt.disabled and interact_available and context_allowed.is_valid() and context_allowed.call()

func is_pointer_owned(index: int) -> bool:
	# Fire, contextual actions, dial and movement retain separate owners.
	return _owns_action_or_movement(index) or (is_instance_valid(radial_input) and radial_input.owns_pointer(index))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE and get_tree().paused:
		var world := get_parent().get_parent().get_parent()
		if world.story.is_open or world.learning_support.opened: return
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not controls_enabled or not _has_focus or _suspended: return
	var handled := false
	if event is InputEventScreenTouch:
		handled = handle_touch(event.index,event.position,event.pressed,event.canceled)
	elif event is InputEventScreenDrag:
		handled = handle_drag(event.index,event.position)
	elif event.device!=InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			handled = handle_touch(-2,event.position,event.pressed,event.canceled)
		elif event is InputEventMouseMotion:
			if is_pointer_owned(-2):
				handled = handle_drag(-2,event.position)
			elif is_instance_valid(radial_input): radial_input.hover(event.position)
	if handled: get_viewport().set_input_as_handled()
