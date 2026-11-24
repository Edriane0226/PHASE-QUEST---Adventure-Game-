extends ScrollContainer
## Native scenes also need readable names for the engine's private fade nodes.


func _ready() -> void:
	preload("res://Scripts/UI/quest_ui.gd").name_scroll_effects(self)
