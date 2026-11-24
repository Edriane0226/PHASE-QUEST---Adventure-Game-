extends CanvasLayer
const QuestUI = preload("res://Scripts/UI/quest_ui.gd")
var active_id := ""
var remaining := 3.0
var retry := 0.0
var focused := true
var suspended := false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN: focused = true
		NOTIFICATION_APPLICATION_PAUSED: suspended = true
		NOTIFICATION_APPLICATION_RESUMED: suspended = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Check modal state after level/UI controllers have updated this frame.
	process_priority = 100
	$Banner.theme = QuestUI.theme()
	$Banner.add_theme_stylebox_override("panel", QuestUI.frame(QuestUI.CREAM))
	get_viewport().size_changed.connect(_layout)
	_layout()
	$Banner.hide()

func _layout() -> void:
	var width := minf(470, get_viewport().get_visible_rect().size.x-32)
	$Banner.offset_left = -width/2
	$Banner.offset_right = width/2

func _blocked(store: Node) -> bool:
	if get_tree().paused or not focused or suspended: return true
	for view in get_tree().get_nodes_in_group("teaching_modal"):
		if view is CanvasItem and view.is_visible_in_tree(): return true
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and transition.busy: return true
	var scene := get_tree().current_scene
	if scene == null or scene.get("demonstration_mode") != false: return true
	if scene.get("dead") == true or scene.get("complete") == true: return true
	var state: Variant = store.data.active_run.get("state")
	if state is Dictionary and store.WORLD_SAVE.truth(state.get("death_pending")): return true
	if scene.has_method("player_controls_allowed") and not scene.player_controls_allowed(): return true
	var world_input := scene.get_node_or_null("WorldInput")
	if world_input != null:
		if is_instance_valid(world_input.emitter) and world_input.emitter.held: return true
		var actor: Node2D = scene.player
		if not actor.movement_input().is_zero_approx() or actor.jump_elapsed >= 0 or actor.action_elapsed >= 0: return true
		return not world_input.pending_feedback().is_empty()
	for entry: Dictionary in store.pending_explanations():
		if entry.instance_id.begins_with("%s:%d:" % [scene.get("SAVE_ZONE"),scene.get("SAVE_LEVEL")]): return true
	for property in ["story", "professor_guide", "learning_support"]:
		var view: Variant = scene.get(property)
		if is_instance_valid(view):
			if view.get("is_open") == true or view.get("opened") == true: return true
	return false

func _process(delta: float) -> void:
	var store := get_node("/root/PlayerSave")
	var state: Dictionary = store.achievement_state()
	if not active_id.is_empty() and not state.toasts.has(active_id):
		active_id = ""
	if _blocked(store) or state.toasts.is_empty():
		$Banner.hide()
		return
	if active_id.is_empty():
		active_id = state.toasts[0]
		remaining = 3.0
		var item: Dictionary = store.ACHIEVEMENTS.definition(active_id)
		$Banner/Content/Words/Title.text = item.name
		$Banner/Content/Icon.kind = item.icon
		$Banner/Content/Icon.earned = true
		$Banner/Content/Icon.queue_redraw()
		var audio := get_node_or_null("/root/GameAudio")
		if audio != null: audio.play("page")
	$Banner.show()
	remaining -= delta
	retry = maxf(0, retry-delta)
	if remaining <= 0 and retry <= 0:
		if store.acknowledge_achievement_toast(active_id):
			active_id = ""
			$Banner.hide()
		else:
			retry = 1.0
