extends CanvasLayer
## Content and input only; the portrait/text layout is authored in the UI scene.
signal closed
var level: Node
var is_open := false
var lines: Array[Dictionary] = []
var cursor := 0
var _last_advance := -1
var _reveal := 0.0
var _was_paused := false
var explanation_type := ""
const EXPLORER_PORTRAITS := "res://assets/characters/cast/explorer/portraits/"
const PORTRAITS := "res://assets/characters/cast/professor/portraits/"


func _ready() -> void:
	$View.hide()
	$View/Panel/Content/Actions/Continue.pressed.connect(advance)
	$View/Panel/Content/Actions/Close.pressed.connect(close)


func open(content: Array, type_id := "") -> void:
	if content.is_empty(): return
	explanation_type = type_id
	lines.assign(content)
	cursor = 0
	is_open = true
	_was_paused = get_tree().paused
	level.player.reset_touch_movement()
	level.mobile_controls.set_enabled(false)
	level.interaction_prompt.hide()
	get_tree().paused = true
	$View.show()
	_show_line()


func _show_line() -> void:
	var entry: Dictionary = lines[cursor]
	var explorer := str(level.get_node("/root/PlayerSave").data.player_name)
	var speaker: String = entry.get("speaker","professor")
	$View/Panel/Content/Speaker.text = explorer if speaker=="explorer" else "Professor Scaldwell"
	$View/Panel/Content/Words.text = str(entry.text).replace("{name}",explorer)
	$View/Panel/Content/Words.visible_characters = 0
	$View/Panel/Content/StateDiagram.text = entry.get("diagram", "")
	$View/Panel/Content/StateDiagram.visible = not $View/Panel/Content/StateDiagram.text.is_empty()
	_reveal = 0.0
	var key: String = entry.get("speaker","professor")+"_"+entry.get("expression","neutral")
	$View/Portrait.texture = load((EXPLORER_PORTRAITS if speaker=="explorer" else PORTRAITS)+key+".tres")
	$View/Panel/Content/Actions/Continue.text = "Continue" if cursor<lines.size()-1 else "Return to garden"


func _process(delta: float) -> void:
	if not is_open: return
	_reveal += delta*46.0
	$View/Panel/Content/Words.visible_characters = int(_reveal)


func advance() -> void:
	if not is_open or _last_advance==Engine.get_process_frames(): return
	_last_advance = Engine.get_process_frames()
	var words: Label = $View/Panel/Content/Words
	if words.visible_characters < words.get_total_character_count():
		_reveal = words.get_total_character_count()+1
		words.visible_characters = -1
		return
	cursor += 1
	if cursor>=lines.size(): close()
	else: _show_line()


func close() -> void:
	if not is_open: return
	if not explanation_type.is_empty():
		var store = level.get_node("/root/PlayerSave")
		if not store.acknowledge_explanation(explanation_type):
			$View/Panel/Content/Words.text = str(lines[cursor].text) + "\n" + store.last_error + " Select Return to garden to retry."
			$View/Panel/Content/Words.visible_characters = -1
			return
	explanation_type = ""
	is_open = false
	$View.hide()
	get_tree().paused = _was_paused
	level.player.reset_touch_movement()
	level.mobile_controls.set_enabled(not _was_paused and not level.dead and not level.complete and not level.overview)
	_last_advance = Engine.get_process_frames()
	closed.emit()
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# A scene reload can remove an unread portrait before its Close button runs.
	if is_open:
		get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if not is_open: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_E]:
			advance()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE:
			close()
