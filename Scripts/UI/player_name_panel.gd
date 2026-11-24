extends CanvasLayer
signal accepted
const QuestUI = preload("res://Scripts/UI/quest_ui.gd")
var name_input: LineEdit
var error_label: Label

func _ready() -> void:
	var column := $Backdrop/Center/NamePanel/Content
	name_input = column.get_node("NameInput")
	error_label = column.get_node("Error")
	name_input.text_submitted.connect(func(_value: String): _submit())
	column.get_node("Start").pressed.connect(_submit)
	column.get_node("Back").pressed.connect(queue_free)
	$Backdrop/Center/NamePanel.custom_minimum_size.x = minf(420, get_viewport().get_visible_rect().size.x - 32)
	name_input.grab_focus()


func _submit() -> void:
	var store = get_node("/root/PlayerSave")
	if not store.set_player_name(name_input.text):
		error_label.text = store.last_error
		return
	accepted.emit()
	queue_free()
