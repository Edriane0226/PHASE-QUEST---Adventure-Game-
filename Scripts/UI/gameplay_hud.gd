extends CanvasLayer
## Scene-owned presentation. The level remains responsible for gameplay state.


func _enter_tree() -> void:
	if get_parent().get("legacy_hud_binding") == true:
		bindLevel(get_parent())


func bindLevel(level: Node) -> void:
	visible = not level.demonstration_mode
	if level.demonstration_mode:
		process_mode = Node.PROCESS_MODE_DISABLED
	for view in find_children("*", "", true, false):
		if view.has_meta("levelField"):
			level.set(str(view.get_meta("levelField")), view)
	level.stats_panel.level = level
	level.mobile_controls.preview_on_desktop = level.preview_touch_controls


func connectActions(level: Node) -> void:
	$HudRoot/NearbyInteraction.pressed.connect(level._request_interact)
	$HudRoot/PausePanel/Actions/ResumeButton.pressed.connect(level._set_paused.bind(false))
	$HudRoot/PausePanel/Actions/RestartButton.pressed.connect(level._restart_level)
	$HudRoot/PausePanel/Actions/SaveMenuButton.pressed.connect(level._save_and_menu)
	$HudRoot/CompletionPanel/Content/ReplayButton.pressed.connect(level._restart_level)
	$HudRoot/CompletionPanel/Content/MenuButton.pressed.connect(level._return_to_menu)
	$HudRoot/GameOverPanel/Actions/Checkpoint.pressed.connect(level._return_to_checkpoint)
	$HudRoot/GameOverPanel/Actions/Restart.pressed.connect(level._restart_level)
	$HudRoot/GameOverPanel/Actions/Menu.pressed.connect(level._return_to_menu)
	$HudRoot/CompletionPanel/Content/Heading.text = level._completion_heading()
	$HudRoot/CompletionPanel/Content/Description.text = level._completion_description()
	updatePlayerName(str(level.get_node("/root/PlayerSave").data["player_name"]))
	level.stats_panel.refresh()


func updatePlayerName(playerName: String) -> void:
	var nameplate: Label = $HudRoot/ProfileFrame/Profile/PlayerNameplate
	nameplate.text = playerName if not playerName.is_empty() else "Explorer"
	nameplate.tooltip_text = nameplate.text
	var nameFont: Font = nameplate.get_theme_font("font")
	var fontSize := 21
	while (
		fontSize > 12
		and (
			nameFont.get_string_size(nameplate.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x
			> 194
		)
	):
		fontSize -= 1
	nameplate.add_theme_font_size_override("font_size", fontSize)
