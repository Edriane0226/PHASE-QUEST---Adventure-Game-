extends "res://Scripts/UI/gameplay_hud.gd"
## Canonical campaign view. L1 legacy binding and other level adapters share this scene.
var mode_selector: Node
var fire_input: Node
var _title_before_feedback := true


func _ready() -> void:
	var palette = preload("res://Scripts/UI/campaign_panel_theme.gd")
	palette.apply($HudRoot)
	var audio = get_node("/root/GameAudio")
	$HudRoot/PausePanel/Settings/Music.toggled.connect(func(enabled: bool): audio.set_enabled("music",enabled))
	$HudRoot/PausePanel/Settings/SoundEffects.toggled.connect(func(enabled: bool): audio.set_enabled("sfx",enabled))
	$HudRoot/PausePanel/Actions/SettingsButton.pressed.connect(_show_pause_settings.bind(true))
	$HudRoot/PausePanel/Settings/BackButton.pressed.connect(_show_pause_settings.bind(false))
	$HudRoot/PausePanel.visibility_changed.connect(func():
		if $HudRoot/PausePanel.visible: _show_pause_settings(false))

	$HudRoot/MobileControls.layout_changed.connect(_layout_guides)
	_layout_guides.call_deferred()
	get_viewport().size_changed.connect(_layout_status)
	_layout_status.call_deferred()
	get_node("/root/PlayerSave").changed.connect(_refresh_device_view)
	get_node("/root/PlayerSave").restored.connect(_profile_restored)
	$HudRoot/PausePanel/Settings/ReducedEffects.toggled.connect(_device_effects_changed)
	_device_effects_changed(bool(get_node("/root/PlayerSave").data.get("extras",{}).get("level1_reduced_effects",false)))
	_refresh_device_view()
	$HudRoot/QuestHints.minimum_size_changed.connect(_fit_objectives)
	mode_selector = preload("res://Scripts/UI/phase_mode_selector.gd").new()
	mode_selector.name = "ModeSelector"
	add_child(mode_selector)
	mode_selector.bind($HudRoot/PhaseModeDial,get_node("/root/PlayerSave"),_device_selection_allowed)
	mode_selector.feedback_changed.connect(_device_feedback)
	$HudRoot/MobileControls.radial_input = mode_selector
	$HudRoot/MobileControls.context_prompt = $HudRoot/NearbyInteraction
	$HudRoot/MobileControls.context_allowed = _context_input_allowed
	fire_input = preload("res://Scripts/UI/phase_fire_input.gd").new()
	fire_input.name = "FireInput"
	add_child(fire_input)
	fire_input.bind(get_parent().get_node_or_null("Actors/Player"),$HudRoot/MobileControls,_world_actions_allowed)

func connectActions(level: Node) -> void:
	super.connectActions(level)
	$HudRoot/PausePanel/Actions/GuidesButton.pressed.connect(func(): level.learning_support.open_demo())
	$HudRoot/PausePanel/Settings/ReducedEffects.set_pressed_no_signal(level.reduced_effects)
	$HudRoot/PausePanel/Settings/ReducedEffects.toggled.connect(level.set_reduced_effects)


func updatePlayerName(playerName: String) -> void:
	var nameplate: Label = $HudRoot/ProfileFrame/Profile/PlayerNameplate
	nameplate.text = playerName if not playerName.is_empty() else "Explorer"
	nameplate.tooltip_text = nameplate.text

func connect_campaign(actions: Dictionary, preview_touch := false) -> void:
	var root=$HudRoot
	root.get_node("MobileControls").preview_on_desktop=preview_touch
	root.get_node("MobileControls").touch_mode=preview_touch or OS.has_feature("android") or DisplayServer.is_touchscreen_available()
	for entry in [["PausePanel/Actions/ResumeButton","resume"],["PausePanel/Actions/RestartButton","restart"],["PausePanel/Actions/SaveMenuButton","main_menu"],["PausePanel/Actions/GuidesButton","guides"],["GameOverPanel/Actions/Checkpoint","recover"],["GameOverPanel/Actions/Restart","restart"],["GameOverPanel/Actions/Menu","main_menu"],["GuideButton","guides"],["NearbyInteraction","interact"],["CloseMapButton","map"]]:
		root.get_node(entry[0]).pressed.connect(actions[entry[1]])
	root.get_node("PausePanel/Settings/ReducedEffects").toggled.connect(actions.effects)
	root.get_node("CompletionPanel/Content/ReplayButton").pressed.connect(actions.restart)
	root.get_node("CompletionPanel/Content/MenuButton").pressed.connect(actions.save_menu)
	for id in ["ObjectivesHUD","ToggleQuestSidebar","StatusText","MechanismStatusCard","MaterialsInventory","KeyboardHints","ThawingProgress","NearbyInteraction","ThoughtBubble","CompletionPanel","PauseShade","PausePanel","CloseMapButton","GameOverPanel"]:
		root.get_node(id).hide()
	for index in range(3): root.get_node("WaypointPin"+str(index)).hide()
	for id in ["PauseShade","CloseMapButton"]: root.get_node(id).add_to_group("teaching_modal")
	root.get_node("MobileControls").set_enabled(true)

func present(model: Dictionary) -> void:
	var root=$HudRoot
	updatePlayerName(model.get("name","Explorer"))
	root.get_node("ProfileFrame/Profile/WarmthBar").value=model.warmth
	root.get_node("ProfileFrame/Profile/WarmthText").text="Warmth %d%%" % ceili(model.warmth)
	root.get_node("LevelTitle").text=model.title
	root.get_node("QuestHints/Content/Title").text=model.quest_title
	root.get_node("QuestHints/Content/Hint").text=model.quest
	root.get_node("QuestHints").visible=not model.get("modal",false)
	root.get_node("InteractionText").text=model.get("notice","")
	root.get_node("GuideButton").visible=not model.get("modal",false)

func present_interaction(target: Node2D, action: String, enabled: bool) -> void:
	var prompt: Button=$HudRoot/NearbyInteraction
	prompt.visible=enabled and target!=null
	if not prompt.visible: return
	prompt.text=action
	prompt.set_meta("context_target",target.get_instance_id())
	prompt.set_meta("context_action",action)
	prompt.reset_size()
	var at: Vector2=target.get_global_transform_with_canvas().origin
	prompt.position = _context_position(at,prompt.get_combined_minimum_size())

func device_caption_position(at: Vector2, extent: Vector2, exclusions: Array[Rect2]) -> Vector2:
	return _context_position(at,extent,true,exclusions)

func _context_position(at: Vector2, extent: Vector2, avoid_context := false, exclusions: Array[Rect2] = []) -> Vector2:
	var safe := preload("res://Scripts/UI/responsive_menu_layout.gd").safe_area(get_viewport())
	var blocked: Array[Rect2] = []
	blocked.append_array(exclusions)
	for id: String in ["ProfileFrame","QuestHints","PhaseModeDial","GuideButton","LevelTitle","ModeFeedback"]:
		var view: Control = $HudRoot.get_node(id)
		if view.is_visible_in_tree(): blocked.append(view.get_global_rect().grow(4))
	if avoid_context and $HudRoot/NearbyInteraction.is_visible_in_tree():
		blocked.append($HudRoot/NearbyInteraction.get_global_rect().grow(4))
	if $HudRoot/MobileControls.is_visible_in_tree():
		blocked.append($HudRoot/MobileControls/Joystick.get_global_rect().grow(20))
		for rect: Rect2 in $HudRoot/MobileControls.button_rects.values(): blocked.append(rect.grow(4))
	var candidates: Array[Vector2] = [at+Vector2(26,-extent.y-18),at-Vector2(extent.x+26,extent.y+18),at+Vector2(-extent.x/2,-extent.y-64),at+Vector2(26,20),at+Vector2(-extent.x-26,20)]
	# On a compact phone, try the free central strip before a bounded grid.
	candidates.append(Vector2(safe.get_center().x-extent.x/2,safe.get_center().y+4))
	for candidate: Vector2 in candidates:
		candidate = candidate.clamp(safe.position,Vector2(maxf(safe.position.x,safe.end.x-extent.x),maxf(safe.position.y,safe.end.y-extent.y)))
		if _context_clear(Rect2(candidate,extent),blocked): return candidate
	# Long objectives can leave a narrow usable band. Sample exact obstacle
	# edges; a coarse pixel grid can miss it and wrongly cover the mode dial.
	var middle := safe.get_center().x-extent.x/2
	for obstacle: Rect2 in blocked:
		for y: float in [obstacle.position.y-extent.y,obstacle.end.y]:
			var candidate := Vector2(middle,y).clamp(safe.position,safe.end-extent)
			if _context_clear(Rect2(candidate,extent),blocked): return candidate
	candidates.clear()
	var xs: Array[float] = [safe.position.x,safe.end.x-extent.x]
	var ys: Array[float] = [safe.position.y,safe.end.y-extent.y]
	for obstacle: Rect2 in blocked:
		xs.append_array([obstacle.position.x-extent.x,obstacle.end.x])
		ys.append_array([obstacle.position.y-extent.y,obstacle.end.y])
	for y: float in ys:
		for x: float in xs: candidates.append(Vector2(x,y))
	var best := safe.position
	var score := INF
	for candidate: Vector2 in candidates:
		candidate = candidate.clamp(safe.position,Vector2(maxf(safe.position.x,safe.end.x-extent.x),maxf(safe.position.y,safe.end.y-extent.y)))
		var rect := Rect2(candidate,extent)
		if not _context_clear(rect,blocked): continue
		var distance := rect.get_center().distance_squared_to(at)
		if distance < score:
			best = candidate
			score = distance
	return best if is_finite(score) else safe.position

func _context_clear(area: Rect2, blocked: Array[Rect2]) -> bool:
	for obstacle: Rect2 in blocked:
		if area.intersects(obstacle): return false
	return true

func present_progress(fraction: float, enabled: bool, caption := "Melting ice") -> void:
	$HudRoot/ThawingProgress.visible=enabled and fraction>0
	$HudRoot/ThawingProgress/ThawingBar.value=fraction*100
	$HudRoot/ThawingProgress/Label.text=caption


func _layout_guides() -> void:
	var map_button: Control = $HudRoot/MobileControls/Buttons/map
	var guide: Button = $HudRoot/GuideButton
	guide.set_anchors_preset(Control.PRESET_TOP_LEFT)
	guide.position = map_button.position-Vector2(102,0)
	guide.size = map_button.size
	var source: Button = map_button as Button
	guide.add_theme_stylebox_override("normal",source.get_theme_stylebox("normal"))
	guide.add_theme_stylebox_override("pressed",source.get_theme_stylebox("pressed"))
	_layout_status()

func present_health(value: float) -> void:
	$HudRoot/ProfileFrame/Profile/HealthBar.value=value
	$HudRoot/ProfileFrame/Profile/HealthBar/HealthText.text="%d/10" % ceili(value)

func _layout_status() -> void:
	if is_instance_valid(mode_selector): mode_selector.cancel()
	var safe := preload("res://Scripts/UI/responsive_menu_layout.gd").safe_area(get_viewport())
	var stick: Control = $HudRoot/MobileControls/Joystick
	var compact := safe.size.y < 580 or safe.size.x < 800
	var dial: Control = $HudRoot/PhaseModeDial
	# Reserve the joystick's 20px acquisition halo plus a 4px visual gap.
	var diameter := minf(196,stick.position.y-safe.position.y-24)
	dial.size = Vector2.ONE*diameter
	dial.position = Vector2(maxf(safe.position.x,stick.position.x+stick.size.x/2-diameter/2),stick.position.y-24-diameter)
	var status: Control = $HudRoot/ProfileFrame
	status.size = Vector2(352,128)
	var factor := (0.65 if safe.size.y < 440 else 0.8) if compact else 1.0
	status.scale = Vector2.ONE*factor
	status.position = Vector2(safe.get_center().x-176*factor,safe.end.y-128*factor) if compact else safe.position+Vector2(18,18)
	$HudRoot/ProfileFrame/Profile/HealthBar/HealthText.add_theme_font_size_override("font_size",18 if compact else 15)
	$HudRoot/ProfileFrame/Profile/WarmthText.add_theme_font_size_override("font_size",16 if compact else 11)
	var hints: Control = $HudRoot/QuestHints
	var card := StyleBoxFlat.new()
	card.bg_color = Color("f1eee4",0.94)
	card.border_color = Color("b5a179")
	card.set_border_width_all(1)
	card.set_corner_radius_all(8)
	card.content_margin_left = 8
	card.content_margin_right = 8
	card.content_margin_top = 6
	card.content_margin_bottom = 6
	hints.add_theme_stylebox_override("panel",card)
	for label: Label in [$HudRoot/QuestHints/Content/Title,$HudRoot/QuestHints/Content/Hint]:
		label.add_theme_color_override("font_color",Color("25364a"))
		label.add_theme_constant_override("outline_size",0)
	var hints_left := dial.position.x+dial.size.x+24
	hints.position = Vector2(hints_left,safe.position.y+72 if compact else status.position.y+128+12)
	# Long text can grow downward without entering Run's column on a short phone.
	var hints_right := minf(safe.end.x,$HudRoot/MobileControls/Buttons/sprint.position.x-12) if compact else safe.end.x
	hints.size = Vector2(minf(420 if compact else 340,hints_right-hints_left),0)
	$HudRoot/QuestHints/Content/Title.add_theme_font_size_override("font_size",13 if compact else 16)
	$HudRoot/QuestHints/Content/Title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$HudRoot/QuestHints/Content/Hint.add_theme_font_size_override("font_size",14 if compact else 20)
	$HudRoot/QuestHints/Content.add_theme_constant_override("separation",4 if compact else 9)
	var title: Label = $HudRoot/LevelTitle
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(hints_left if compact else safe.get_center().x-245,safe.position.y)
	title.size = Vector2(safe.end.x-hints_left if compact else 490,24 if compact else 32)
	title.add_theme_font_size_override("font_size",14 if compact else 23)
	var feedback: Label = $HudRoot/ModeFeedback
	feedback.add_theme_font_size_override("font_size",12 if compact else 16)
	feedback.position = title.position
	feedback.size = Vector2(title.size.x,20 if compact else 32)
	var notice: Label = $HudRoot/InteractionText
	notice.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notice.position = Vector2(status.position.x,status.position.y-50) if compact else Vector2(safe.get_center().x-350,safe.end.y-100)
	notice.size = Vector2(352*factor,44) if compact else Vector2(700,64)
	notice.add_theme_font_size_override("font_size",12 if compact else 16)
	_fit_objectives.call_deferred()

func _fit_objectives() -> void:
	var hints: Control = $HudRoot/QuestHints
	hints.size.y = hints.get_combined_minimum_size().y

func _refresh_device_view() -> void:
	var store = get_node("/root/PlayerSave")
	var dial = $HudRoot/PhaseModeDial
	dial.present(store.device_state(),dial.hovered_mode,dial.reduced_effects)

func _profile_restored() -> void:
	$HudRoot/MobileControls.reset_input()
	_refresh_device_view()

func _device_effects_changed(enabled: bool) -> void:
	var dial = $HudRoot/PhaseModeDial
	dial.present(dial.state,dial.hovered_mode,enabled)

func _device_selection_allowed() -> bool:
	var level := get_parent()
	return (
		level.is_node_ready() and level.has_method("player_controls_allowed")
		and $HudRoot/MobileControls.controls_enabled and $HudRoot/QuestHints.visible
		and not $HudRoot/PausePanel.visible and not $HudRoot/PauseShade.visible
		and level.player_controls_allowed()
	)

func _world_actions_allowed() -> bool:
	var level := get_parent()
	return visible and not get_tree().paused and level.is_node_ready() and level.get("demonstration_mode") != true and level.has_method("player_controls_allowed") and $HudRoot/MobileControls.controls_enabled and not $HudRoot/PauseShade.visible and level.player_controls_allowed()

func _context_input_allowed() -> bool:
	if not _world_actions_allowed(): return false
	var actor = get_parent().get_node_or_null("Actors/Player")
	return is_instance_valid(actor) and actor.is_node_ready() and actor.jump_elapsed < 0 and actor.action_elapsed < 0

func _device_feedback(message: String) -> void:
	var label: Label = $HudRoot/ModeFeedback
	var title: Label = $HudRoot/LevelTitle
	if not message.is_empty():
		if not label.visible: _title_before_feedback = title.visible
		title.hide()
	elif label.visible:
		title.visible = _title_before_feedback
	label.text = message
	label.visible = not message.is_empty()

func _process(_delta: float) -> void:
	# Match objective visibility during map/completion/death; pause/modal layers
	# stay above this non-interactive decoration. No gameplay state is changed.
	var dial = $HudRoot/PhaseModeDial
	dial.visible = (
		$HudRoot/QuestHints.visible and not dial.state.unlocked_modes.is_empty()
		and not $HudRoot/PausePanel.visible and not $HudRoot/PauseShade.visible
	)

func _show_pause_settings(opened: bool) -> void:
	var audio = get_node("/root/GameAudio")
	$HudRoot/PausePanel/Settings/Music.set_pressed_no_signal(audio.music_enabled)
	$HudRoot/PausePanel/Settings/SoundEffects.set_pressed_no_signal(audio.sfx_enabled)
	$HudRoot/PausePanel/Actions.visible = not opened
	$HudRoot/PausePanel/Settings.visible = opened
