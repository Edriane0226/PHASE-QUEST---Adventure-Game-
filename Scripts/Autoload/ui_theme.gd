extends Node
## Scripted StyleBoxes require a SceneTree; apply the shared theme after startup.
func _ready() -> void:
	get_tree().root.theme = load("res://UI/Themes/QuestTheme.tres") as Theme
