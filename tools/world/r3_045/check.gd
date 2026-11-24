extends SceneTree

const WORLD := "res://World/Navigation/ConnectedWorld.tscn"
const MENU := "res://UI/Menus/MainMenuPanel.tscn"
const ACTIVITY = preload("res://Scripts/World/Learning/optional_activity.gd")
const TOUCH = preload("res://touch_route.gd")
const IDS := ["Z1L4","Z1L5","Z2L2","Z2L4","Z2L5","Z3L2","Z3L4","Z3L5"]
const OUTPUT := "res://../../../output/world/r3-prompt045/evidence/"
var world: Node2D
var profile: Node
var driver: TOUCH

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,360)
	root.content_scale_size = root.size
	profile = root.get_node("PlayerSave")
	var manual := "--manual" in OS.get_cmdline_user_args()
	if manual: scene_changed.connect(_bind_shortcuts)
	change_scene_to_file(WORLD)
	await scene_changed
	world = current_scene
	driver = PracticeDriver.new(self,world)
	if DisplayServer.get_name() != "headless": root.grab_focus()
	await driver.ticks(8)
	if manual:
		print("OPTIONAL045 READY · keys 1–8 visit practice pads. Esc closes panels.")
		return
	var baseline := progression()
	var restoring := "--restore" in OS.get_cmdline_user_args()
	var render := "--render" in OS.get_cmdline_user_args()
	var mill: Node = world.chunks["Z1L2.shell"]
	driver.check(mill.optional_activity == null and is_instance_valid(mill.runtime_provider),"required Thaw & Sort uses its existing provider")
	for id in IDS:
		var station: ACTIVITY = world.chunks[id+".shell"].optional_activity
		if not driver.check(is_instance_valid(station),id+" mounts the reserved optional pad"): continue
		if not driver.check(await visit(station),id+" can enter optional pad after the verified task"): continue
		if restoring:
			driver.check(station._state.placed.size() == station.shapes.size() and not world.player.carrying,id+" cold Continue restores all placements and empty hands")
			driver.check(station.targets.is_empty(),id+" prepared samples never return as live Fire targets")
			if render:
				await capture(id+"-matched")
				if not await use(station,"sign"): break
				driver.check(world.input_adapter.modal == "optional_activity" and world.panels.action_buttons.is_empty(),id+" uses the single briefing close action")
				await capture(id+"-brief")
				await driver.panel_button(world.panels.close_button)
			continue
		if not await exercise(station,render): break
		driver.check(progression() == baseline,id+" adds zero progression, receipts, checkpoint changes or rewards")
		print(id," matched ",station._state.placed.size(),"/",station.shapes.size())
	if restoring and not render: await check_remount()
	driver.check(world.fall_count == 0,"all practice carries follow supported walking lanes")
	if render and driver.failures.is_empty(): await check_menu_continue()
	print("OPTIONAL045 %s · %d checks · %.1f world units walked" % ["PASS" if driver.failures.is_empty() else "FAIL",driver.checks,driver.walked])
	quit(0 if driver.failures.is_empty() else 1)

func progression() -> Dictionary:
	var extras: Dictionary = profile.data.extras
	var device: Dictionary = profile.device_state()
	device.erase("selected_mode")
	var states := {}
	for id in profile.world_record().attempts:
		var attempt: Dictionary = profile.world_record().attempts[id]
		var state: Dictionary = attempt.attempt.state.duplicate(true)
		state.erase("position")
		states[id] = [attempt.attempt.attempt_id,state,attempt.checkpoint_progress]
	var learning := {}
	for key in ["lessons_seen","guides_unlocked","explained_types","pending_explanations","inventory","currency"]:
		learning[key] = extras.get(key)
	return {"completed":profile.data.completed.duplicate(true),"stars":profile.total_stars(),"device":device,"learning":learning.duplicate(true),
		"rank":profile.rank_name(),"achievements":profile.achievement_state(),"solved":extras.solved_puzzle_ids.duplicate(true),
		"independent":extras.independent_puzzle_ids.duplicate(true),"attempts":states}

func visit(station: ACTIVITY) -> bool:
	if not pose(world,station): return false
	await driver.ticks(5)
	return station._control_available

static func pose(host: Node2D, station: ACTIVITY) -> bool:
	var store: Node = station.store
	return host.activate(station.region,station.center) and store.enter_world_subregion(host,station.region)

func use(station: ACTIVITY, id: String) -> bool:
	var at: Vector2 = station.center if id == "sign" else station.assembly.marker(id).position
	var key := station.station_id+":"+id
	var nearby := func(): return station.world_context().get("key") == key
	if not driver.check(await driver.approach(at,nearby,[23,30,38]),"walk to "+key): return false
	world.input_adapter.refresh()
	driver.tap(world.hud.controls.context.get_global_rect().get_center())
	await driver.ticks()
	return true

func fire(station: ACTIVITY, id: String) -> bool:
	var target: Node2D = station.targets.get(id)
	if not driver.check(is_instance_valid(target),"live optional target "+id): return false
	var at: Vector2 = target.get_meta("ground_xy")
	var emitter: Node = world.input_adapter.emitter
	var points: Array[Vector2] = []
	for radius in [59,70,82]:
		for step in range(16):
			var point := at+Vector2.from_angle(step*TAU/16)*float(radius)
			if point.distance_to(station.center) < 118 and world.valid_landing(point): points.append(point)
	points.sort_custom(func(a,b): return world.player.position.distance_squared_to(a) < world.player.position.distance_squared_to(b))
	for point in points:
		if not await driver.go(point): continue
		for i in 2:
			driver.stick(world.player.device_muzzle().global_position.direction_to(target.global_position))
			await driver.ticks(1)
		if emitter.selected == target:
			driver.stop()
			world.hud.route_touch(TOUCH.FIRE,world.hud.rects.fire.get_center(),true)
			await driver.wait(float(target.definition().required_exposure)+0.4)
			world.hud.route_touch(TOUCH.FIRE,Vector2.ZERO,false)
			return driver.check(target.is_committed(),"HUD Fire prepared "+station.station_id+":"+id)
		driver.stop()
	return driver.check(false,"aim at "+station.station_id+":"+id+" ("+emitter.reason+")")

func exercise(station: ACTIVITY, render: bool) -> bool:
	var id := station.region
	var first: String = station.shapes[0]
	if not await use(station,"sign"): return false
	driver.check(paused and world.input_adapter.modal == "optional_activity",id+" briefing pauses nearby world")
	if render: await capture(id+"-brief")
	if DisplayServer.get_name() != "headless":
		await driver.panel_button(world.panels.close_button)
	else:
		world.panels.close_button.pressed.emit()
	await driver.ticks()
	driver.check(not paused,id+" closes briefing freely")
	world.demonstration_mode = true
	driver.check(station.world_context().is_empty() and not station._action_allowed("source_"+first)
		and station.targets.values().all(func(target): return not target.belongs_to(world,profile)),id+" demonstration authority cannot act")
	world.demonstration_mode = false
	if id == "Z1L4":
		var practice_before := station._state.duplicate(true)
		var rules: Dictionary = profile.data.active_run.state.device_outcomes
		var proof: Dictionary = rules.freeze_side
		rules.erase("freeze_side")
		station._refresh()
		driver.check(not station._control_available and not station.owns_target(station.targets.get("source_triangle")),"practice waits for the local freezing result")
		rules.freeze_side = proof
		station._refresh()
		var guides: Dictionary = profile.guide_records()
		for key in guides:
			if guides[key].topic != "freezing": continue
			world.input_adapter.open_panel("guides")
			world.input_adapter._open_guide(key)
			await driver.wait(3.0)
			driver.check(is_instance_valid(world.input_adapter.guide_preview) and station._state == practice_before,
				"freezing Guide playback leaves local practice untouched")
			world.input_adapter.close_panel()
			break
	match station.kind:
		"dry":
			if not await use(station,"control"): return false
			await driver.wait(2.2)
			driver.check(station._state.prepared.size() == 3,"sun and fan dry the three pennants")
		"paths": pass
		_:
			if not await driver.mode(station.activity.mode): return false
			for target in station._target_components():
				if not await fire(station,target): return false
	if not await use(station,"source_"+first): return false
	var carried: Array = world.player.get_node("CarriedModule").get_children().filter(func(item): return item.has_meta("unique_item_id"))
	driver.check(world.player.carrying and carried.size() == 1,id+" lifts one unique item")
	var other: String = station.shapes[1]
	if not await use(station,"slot_"+other): return false
	driver.check(station._state.placed.is_empty() and station.holding_item(),id+" wrong display keeps the item for retry")
	if id == "Z1L4":
		profile.fail_commit = true
		var attempted := await use(station,"slot_"+first)
		profile.fail_commit = false
		if not attempted: return false
		driver.check(station._state.placed.is_empty() and station.holding_item() and not profile.last_error.is_empty(),
			"failed placement save retains the carried item for retry")
	if not await use(station,"slot_"+first): return false
	driver.check(station._state.placed.has(first) and not world.player.carrying,id+" matching placement saves once")
	if not await use(station,"source_"+other): return false
	if not await use(station,"sign"): return false
	driver.check(station._state.placed.has(first) and station._ready_item(other) and not world.player.carrying,id+" free return restores unplaced source")
	if not await use(station,"source_"+other): return false
	station.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	driver.check(station._state.placed.has(first) and not world.player.carrying,id+" background recovery preserves committed work")
	if not await use(station,"source_"+other): return false
	if not driver.check(await walk_off(station),id+" walk off pad"): return false
	driver.check(not world.player.carrying and station._state.placed.has(first),id+" walking off returns loose cargo")
	if not driver.check(await driver.go(station.center),id+" walk back to practice"): return false
	for shape in station.shapes.slice(1):
		if not await use(station,"source_"+shape) or not await use(station,"slot_"+shape): return false
	driver.check(station._state.placed.size() == station.shapes.size() and not world.player.carrying,id+" completes locally")
	if render:
		await driver.go(station.center)
		await capture(id+"-matched")
	return true

func walk_off(station: ACTIVITY) -> bool:
	for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT,
		Vector2(-1,1).normalized(),Vector2(1,1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,-1).normalized()]:
		var at := station.center+direction*137.0
		if not world.valid_landing(at) or not driver._clear(world.player.position,at): continue
		if await driver._walk_segment(at) and world.player.position.distance_to(station.center) > station.PAD_RADIUS:
			return true
	return false

func check_remount() -> void:
	const ID := "Z3L4.shell"
	if not driver.check(world.unmount_chunk(ID),"inactive Frost Gallery chunk unmounts"): return
	await driver.ticks()
	var chunk := preload("res://World/Zone3/Z3L4Shell.tscn").instantiate()
	chunk.configure_geometry(world.models[2])
	if not driver.check(world.mount_chunk(chunk),"Frost Gallery chunk remounts"): return
	var station: ACTIVITY = chunk.optional_activity
	if not driver.check(is_instance_valid(station) and await visit(station),"remounted reserved station accepts Hand"):
		return
	driver.check(station._state.placed.size() == 3 and station.targets.is_empty(),"remount restores displays without recreating samples")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	driver.check(image.save_png(ProjectSettings.globalize_path(OUTPUT+name+".png")) == OK,"capture "+name)

func check_menu_continue() -> void:
	driver.tap(world.hud.rects.pause.get_center())
	await driver.ticks()
	if not driver.check(world.input_adapter.modal == "pause","HUD Pause opens on the practice pad"): return
	if not await driver.press("save_menu"): return
	for frame in 300:
		if current_scene != null and current_scene.scene_file_path == MENU: break
		await process_frame
	if not menu_check(current_scene != null and current_scene.scene_file_path == MENU,"Save & Menu reaches the title"):
		return
	await driver.ticks(5)
	var button: Button = current_scene.view.buttons["continue"]
	if not menu_check(not button.disabled and current_scene.resume.subregion == "Z3L5","Continue resolves the practice district"):
		return
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.pressed = down
		Input.parse_input_event(click)
		await process_frame
	for frame in 300:
		if current_scene != null and current_scene.scene_file_path == WORLD: break
		await process_frame
	if not menu_check(current_scene != null and current_scene.scene_file_path == WORLD,"title Continue returns to ConnectedWorld"):
		return
	world = current_scene
	var station: ACTIVITY = world.active_chunk().optional_activity
	menu_check(is_instance_valid(station) and station.region == "Z3L5" and station._state.placed.size() == 3,
		"Save & Menu round trip retains all Frost Gallery placements")

func menu_check(ok: bool, label: String) -> bool:
	driver.checks += 1
	if not ok:
		driver.failures.append(label)
		print("FAIL ",label)
	return ok

func _bind_shortcuts() -> void:
	if current_scene.scene_file_path == WORLD: current_scene.add_child(PracticeShortcuts.new())

class PracticeDriver extends TOUCH:
	func _supported(at: Vector2) -> bool:
		return (not world.player.carrying or world.access.region_at(at) == world.active_subregion_id) and world.valid_landing(at)

class PracticeShortcuts extends Node:
	func _unhandled_key_input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo: return
		var index: int = event.physical_keycode-KEY_1
		if index < 0 or index >= IDS.size(): return
		var host := get_parent()
		if not host.input_adapter.modal.is_empty(): return
		var station: ACTIVITY = host.chunks[IDS[index]+".shell"].optional_activity
		if is_instance_valid(station):
			host.activate(station.region,station.center)
			station.store.enter_world_subregion(host,station.region)
