extends Node
## Selection adapter. TouchControls routes events; PlayerSave owns transactions.
signal feedback_changed(message: String)
const GESTURE = preload("res://Scripts/UI/phase_dial_gesture.gd")
const LESSONS := {"thermal":"Melting", "cryo":"Freezing", "pressure":"Deposition", "vacuum":"Sublimation"}
var gesture := GESTURE.new()
var view: Control
var store: Node
var allowed: Callable
var feedback := ""
var _feedback_seconds := 0.0
var _has_focus := true
var _suspended := false

func bind(dial: Control, save_store: Node, permission: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = dial
	store = save_store
	allowed = permission

func available() -> bool:
	return (
		is_instance_valid(view) and is_instance_valid(store) and view.is_visible_in_tree()
		and _has_focus and not _suspended and not get_tree().paused
		and allowed.is_valid() and allowed.call()
	)

func owns_pointer(index: int) -> bool:
	return gesture.owns(index)

func _local(point: Vector2) -> Vector2:
	return view.get_global_transform_with_canvas().affine_inverse()*point

func _message(value: String, seconds := 0.0) -> void:
	_feedback_seconds = seconds
	if feedback == value: return
	feedback = value
	feedback_changed.emit(value)

func _preview(mode: String, dragging: bool) -> void:
	view.set_preview(mode)
	if mode.is_empty():
		_message("")
	elif not store.is_device_mode_unlocked(mode):
		_message("%s locked · %s / %s" % [view.NAMES[mode],view.UNLOCKS[mode],LESSONS[mode]])
	else:
		_message(("Release to select %s" if dragging else "Click to select %s") % view.NAMES[mode])

func handle_touch(index: int, point: Vector2, pressed: bool, canceled := false) -> bool:
	if not available():
		var was_owner := owns_pointer(index)
		cancel()
		return was_owner
	if not pressed or canceled:
		if not owns_pointer(index): return false
		var mode := gesture.finish(index,_local(point),view.size,canceled)
		view.set_preview("")
		_message("")
		if mode.is_empty(): return true
		if not store.is_device_mode_unlocked(mode):
			_preview(mode,true)
			# Keep information briefly, but release the preview and pointer.
			view.set_preview("")
			_feedback_seconds = 3.0
			return true
		# Ownership is cleared before the synchronous save/changed signal.
		var saved: bool = store.select_device_mode(mode)
		view.present(store.device_state(),"",view.reduced_effects)
		_message("Selected "+view.NAMES[mode] if saved else "Selection not saved. Try again.",2.5)
		return true
	if owns_pointer(index): return true
	if not gesture.begin(index,_local(point),view.size): return false
	_preview(gesture.preview,true)
	return true

func handle_drag(index: int, point: Vector2) -> bool:
	if not owns_pointer(index): return false
	if not available(): cancel(); return true
	gesture.drag(index,_local(point),view.size)
	_preview(gesture.preview,true)
	return true

func hover(point: Vector2) -> void:
	if gesture.pointer != GESTURE.NONE: return
	if not available(): cancel(); return
	_preview(gesture.mode_at(_local(point),view.size,view.hovered_mode),false)

func cancel() -> void:
	gesture.cancel()
	if is_instance_valid(view): view.set_preview("")
	_message("")

func _process(delta: float) -> void:
	if not available():
		if gesture.pointer != GESTURE.NONE or not feedback.is_empty() or (is_instance_valid(view) and not view.hovered_mode.is_empty()): cancel()
		return
	if _feedback_seconds > 0:
		_feedback_seconds -= delta
		if _feedback_seconds <= 0: _message("")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_focus = false
		cancel()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		cancel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _has_focus = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _suspended = false
	elif what == NOTIFICATION_EXIT_TREE: cancel()
