extends SceneTree
## Windowed check of the ground while playing: bake use, streaming, a floor change, Reduced Effects.
## Use a disposable profile folder. SHOT_DIR receives the captures.
##   Godot --path <project> -s res://tools/world/terrain_bake/runtime_check.gd
const ENTRY := preload("res://tools/world/r3_052/title_entry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:run.call_deferred()

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ",text)

func run() -> void:
	root.size = Vector2i(1280,720)
	var world: Node = await ENTRY.open(self,false)
	if world == null:return
	var ground: Node2D = world.art_layers[0]
	var surface: RefCounted = ground.surface
	check(world.art_layers.size() == 1 and surface.models.size() == 3,"one painter holds three zones")
	check(surface.bake_loaded,"baked pages match the generated ground")
	print("STATS ",surface.stats)
	for i in 120:await process_frame
	var seen: Rect2 = ground.view()
	var missing := 0
	for page in ground._pages_in(seen):
		if not ground._shown.has(page):missing += 1
	check(missing == 0,"every page on screen is shown")
	var frames := {}
	for i in 240:
		await process_frame
		frames[ground._frame] = true
	check(frames.size() >= 3,"water moves through its frames "+str(frames.keys()))
	var profile: Node = root.get_node("PlayerSave")
	profile.data.extras["level1_reduced_effects"] = true
	profile.changed.emit()
	await process_frame
	await process_frame
	frames.clear()
	for i in 240:
		await process_frame
		frames[ground._frame] = true
	check(ground.still and frames.size() == 1 and frames.has(0),"Reduced Effects holds the water "+str(frames.keys()))
	profile.data.extras["level1_reduced_effects"] = false
	profile.changed.emit()
	# A floor change on screen: the old page stays until the new one is painted.
	for i in 60:await process_frame
	var model: RefCounted = world.models[int(str(world.active_subregion_id).substr(1,1))-1]
	var page_center: Vector2 = ground.view().get_center()
	model.add_floor(PackedVector2Array([page_center+Vector2(-30,-30),page_center+Vector2(30,-30),page_center+Vector2(30,30),page_center+Vector2(-30,30)]),world.active_subregion_id,"legacy",300.0)
	ground.queue_redraw()
	var worst := 0.0; var waited := 0; var holes := 0
	var last := Time.get_ticks_usec()
	while waited < 600:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst,(now-last)/1000.0); last = now
		waited += 1
		var stale := 0
		for page in ground._pages_in(ground.view()):
			if not ground._shown.has(page):holes += 1
			elif ground._shown[page].stale:stale += 1
		if waited > 4 and stale == 0:break
	check(holes == 0 and waited < 600,"a floor change leaves no hole; ready after "+str(waited)+" frames, worst frame "+str(snappedf(worst,.1))+" ms")
	var current := 0
	for page in ground._shown:
		if ground._shown[page].signature == ground._wanted[page]:current += 1
	check(current > 0,"pages on screen match the floors: "+str(current))
	model.floors.pop_back()
	for key in model.floor_bins:model.floor_bins[key].erase(model.floors.size())
	ground.queue_redraw()
	for i in 200:await process_frame
	check(ground._shown.size() < 60,"far pages are released: "+str(ground._shown.size())+" shown")
	print("GROUND ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(1 if failures else 0)
