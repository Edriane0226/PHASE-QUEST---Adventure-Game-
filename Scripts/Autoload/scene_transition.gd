extends CanvasLayer
## One persistent overlay keeps navigation covered across scene replacement.
const Screen = preload("res://Scripts/UI/phase_loading.gd")
const LOADING_DURATION := 3.0
const LOADING_FADE_DURATION := 0.25
var busy := false
var screen: Control
var fact_index := 0

func _loads_on_main_thread(path: String) -> bool:
	# Keep the authored campaign's shader and atlas graph on the main thread.
	return path.begins_with("res://UI/") or path == "res://World/CampaignWorld.tscn"

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Screen.new()
	screen.name = "LoadingScreen"
	add_child(screen)
	screen.hide()

func run(action: Callable, learning := false, scene_path := "") -> void:
	if busy:
		return
	busy = true
	if not scene_path.is_empty() and not _loads_on_main_thread(scene_path):
		ResourceLoader.load_threaded_request(scene_path,"PackedScene")
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null and learning: audio.set_loading(true)
	if audio != null: audio.play("page")
	screen.learning = learning
	screen.fact_index = fact_index%6
	if learning:
		fact_index += 1
	screen.progress = 0.0
	screen.modulate.a = 0.0
	screen.show()
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(screen,"modulate:a",1.0,LOADING_FADE_DURATION if learning else 0.14)
	await fade.finished
	if learning:
		var reading := create_tween()
		reading.tween_property(screen,"progress",1.0,LOADING_DURATION - 2.0 * LOADING_FADE_DURATION)
		await reading.finished
	if action.is_valid():
		await action.call()
	# Scene replacement is deferred; let the destination finish its first layout.
	await get_tree().process_frame
	await get_tree().process_frame
	fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(screen,"modulate:a",0.0,LOADING_FADE_DURATION if learning else 0.14)
	await fade.finished
	screen.hide()
	busy = false
	if audio != null and learning: audio.set_loading(false)

func change_scene(path: String) -> Error:
	if _loads_on_main_thread(path):
		var destination := load(path) as PackedScene
		if destination == null: return ERR_CANT_OPEN
		return get_tree().change_scene_to_packed(destination)
	var status := ResourceLoader.load_threaded_get_status(path)
	if status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var error := ResourceLoader.load_threaded_request(path,"PackedScene")
		if error!=OK: return error
		status = ResourceLoader.load_threaded_get_status(path)
	while status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status!=ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Unable to load scene: "+path)
		return ERR_CANT_OPEN
	var destination := ResourceLoader.load_threaded_get(path) as PackedScene
	return get_tree().change_scene_to_packed(destination)
