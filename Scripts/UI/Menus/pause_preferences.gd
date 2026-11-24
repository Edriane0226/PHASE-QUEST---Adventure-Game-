extends Control
const ROOT := "PanelContainer/Content"
func _ready() -> void:
	var audio = get_node("/root/GameAudio")
	get_node(ROOT+"/Music").set_pressed_no_signal(audio.music_enabled)
	get_node(ROOT+"/SoundEffects").set_pressed_no_signal(audio.sfx_enabled)
	get_node(ROOT+"/Music").toggled.connect(func(value: bool):audio.set_enabled("music",value))
	get_node(ROOT+"/SoundEffects").toggled.connect(func(value: bool):audio.set_enabled("sfx",value))
	var store=get_node("/root/PlayerSave")
	get_node(ROOT+"/ReducedEffects").set_pressed_no_signal(bool(store.data.extras.get("level1_reduced_effects",false)))
	get_node(ROOT+"/ReducedEffects").toggled.connect(func(value: bool):
		store.data.extras["level1_reduced_effects"]=value
		store.save_profile())
	_layout()
	get_viewport().size_changed.connect(_layout)
func _layout() -> void:
	var safe=preload("res://Scripts/UI/responsive_menu_layout.gd").safe_area(get_viewport())
	var inverse=get_global_transform_with_canvas().affine_inverse()
	var panel: Control=$PanelContainer
	panel.size=Vector2(360,340)
	panel.position=inverse*safe.get_center()-panel.size/2
	$CloseButton.position=panel.position+Vector2(panel.size.x-54,12)
	$CloseButton.size=Vector2(42,42)
	$CloseButton.custom_minimum_size=Vector2(42,42)
	$CloseButton.icon=null
	$CloseButton.text="×"
	$CloseButton.add_theme_font_size_override("font_size",28)

