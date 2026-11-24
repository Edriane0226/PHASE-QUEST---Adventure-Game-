extends SceneTree

func _initialize() -> void:
	var result := ResourceSaver.save(ThemeDB.fallback_font,"res://Assets/Font/InterfaceSans.tres")
	quit(0 if result==OK else 1)
