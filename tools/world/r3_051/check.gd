extends SceneTree
## Run each suite in a separate Godot process with the real project autoloads.
const CAMPAIGN = "res://World/CampaignWorld.tscn"
const TITLE = "res://UI/Menus/MainMenuPanel.tscn"
const GARDEN_PATH = NodePath("GroundSort/Zone1/Garden")
const PROFILE_NAME = "Garden 051"
const EVIDENCE = "res://output/world/r3-prompt051/evidence/"
var checks := 0
var failures: Array[String] = []
var store: Node

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func wait_for(predicate: Callable, limit := 90000) -> bool:
	var until := Time.get_ticks_msec() + limit
	while not predicate.call() and Time.get_ticks_msec() < until:
		await process_frame
	return predicate.call()

func run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	store = root.get_node("PlayerSave")
	var args := OS.get_cmdline_user_args()
	if args.has("--editor-layout"):
		check_layout()
	elif args.has("--direct"):
		await check_direct()
	else:
		await check_title(args.has("--cold"), args.has("--legacy"))
	if is_instance_valid(current_scene) and current_scene.scene_file_path == CAMPAIGN:
		change_scene_to_file(TITLE)
		await scene_changed
		await process_frame
	print("CAMPAIGN_051 ", "PASS" if failures.is_empty() else "FAIL", " / ", checks, " checks / ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func check_layout() -> void:
	var map := (load(CAMPAIGN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var garden := map.get_node(GARDEN_PATH)
	var floor_node := garden.get_node("Layout/Floors").get_child(0) as Polygon2D
	var points := floor_node.polygon
	points[0] += Vector2(2,0)
	floor_node.polygon = points
	var test_scene := PackedScene.new()
	check(test_scene.pack(map) == OK, "editor-style repack of changed inline Garden floor")
	var reopened := test_scene.instantiate()
	check(reopened.get_node(GARDEN_PATH).get_node("Layout/Floors").get_child(0).polygon == points, "authored floor edit survives pack and reopen")
	check(garden.owner == map and garden.scene_file_path.is_empty() and floor_node.owner == map, "Garden and floor owned directly by campaign scene")
	check(garden.get_node("Layout/Checkpoints").get_child_count() == 4, "four editable checkpoints")
	check(garden.get_node("Collision").find_children("*","CollisionPolygon2D",true,false).size() > 200, "editable collision polygons")
	check(garden.get_node("Layout/Routes").find_children("*","Line2D",true,false).size() > 0, "editable trail and portal routes")
	for dependency in ResourceLoader.get_dependencies(CAMPAIGN):
		if ".tscn" not in dependency: continue
		var path := str(dependency).get_slice("::",str(dependency).get_slice_count("::")-1)
		check(path.begins_with("res://Actors/") or path.begins_with("res://UI/"), "component scene dependency " + path)
	reopened.free()
	map.free()

func check_direct() -> void:
	var hash := FileAccess.get_sha256(store.save_path) if FileAccess.file_exists(store.save_path) else ""
	change_scene_to_file(CAMPAIGN)
	await scene_changed
	await process_frame
	var world := current_scene
	check(world.restoration_pending and not world.entry_authorized and not world.player_controls_allowed(), "direct scene launch has safe recovery panel and no authorized session")
	check(not store.enter_world_subregion(world,"Z1L1") and not store.update_run({}), "direct scene launch cannot write campaign state")
	check((FileAccess.get_sha256(store.save_path) if FileAccess.file_exists(store.save_path) else "") == hash, "direct launch preserves profile bytes")

func check_title(cold: bool, legacy: bool) -> void:
	change_scene_to_file(TITLE)
	await scene_changed
	await process_frame
	var menu := current_scene
	check(store.save_path.ends_with("campaign-staging-profile.save") != legacy, "selected profile namespace")
	check(not store.has_meta("r3_015_fixture") and not store.has_meta("r3_019_permissions"), "real PlayerSave without fixture permissions")
	if cold:
		check(store.has_player_name() and store.data.player_name == PROFILE_NAME, "cold start reads named profile")
		check(not menu.view.buttons["continue"].disabled, "title offers Continue")
		menu.view.buttons["continue"].pressed.emit()
	else:
		check(not store.has_player_name(), "fresh disposable profile")
		menu.view.buttons["new_game"].pressed.emit()
		check(menu.view.dialog_id == "new_game", "title opens New Game name form")
		menu.name_input.text = PROFILE_NAME
		menu.view.dialog.action_buttons["confirm_new_game"].pressed.emit()
	var expected := "res://Zone_1/Levels/wrld_lvl_1.tscn" if legacy else CAMPAIGN
	check(await wait_for(func():return current_scene != null and current_scene.scene_file_path == expected and not root.get_node("SceneTransition").busy), "ordinary title button reaches " + expected)
	if current_scene == null or current_scene.scene_file_path != expected or legacy:return
	var world := current_scene
	check(await wait_for(func():return world.entry_authorized and not world.restoration_pending), "authorized Garden input and location")
	if not world.entry_authorized or world.restoration_pending:return
	var provider: Node = world.learning_provider()
	check(provider != null and provider.active(), "active original Garden provider")
	check(world.chunks.size() == world.REGISTRY.CAMPAIGN_DISTRICTS.size() and world.active_chunk() == world.get_node(GARDEN_PATH), "registered districts mounted and directly owned Garden active")
	check(world.find_children("*","Camera2D",true,false).size() == 1 and world.get_node("GameplayHUD").get_child_count() == 2, "one gameplay camera and HUD")
	check(not world.development_preview and not world.demonstration_mode and store.world_navigation_source(world,"Z1L1"), "standing player is authorized in registered campaign district")
	check(not store.begin_level("melting_and_freezing",1) and store.request_continue().is_empty(), "standalone entry and save APIs refuse the staged profile")
	check(not store.world_navigation_source(world,"Z1L2") and not store.enter_world_subregion(world,"Z1L2"), "different district rejected for navigation writes")
	var entire_map: Array = world.REGISTRY.definitions()
	check(entire_map.filter(func(row):return world.access.allowed(row.id)).size() == 1, "all other districts are unready")
	var mill: Vector2 = world.REGISTRY.local_to_ground("Z1L2",Vector2.ZERO)
	check(not world.activate("Z1L2",mill) and not world.world_contact_allowed(world.player.position,mill), "unready Mill blocks travel and Fire")
	var perimeter: Array = world.active_chunk().find_children("*","StaticBody2D",true,false).filter(func(body):return body.get_meta("staged_boundary",false) and body.collision_layer == 8)
	if world.chunks.size()==1:
		check(perimeter.size() == world.active_chunk().permission_polygon().size(), "every staged perimeter edge has active collision")
	else:
		check(world.permissions.Z1L2.all(func(body):return body.collision_layer==8), "locked Mill perimeter retains collision")
	var completion_key: String = store.level_key("melting_and_freezing",1)
	var before: Dictionary = store.data.completed.duplicate()
	store.data.completed[completion_key] = true
	world.access.refresh()
	check(store.is_level_unlocked("melting_and_freezing",2) and world.access.allowed("Z1L2")==world.REGISTRY.CAMPAIGN_DISTRICTS.has("Z1L2"), "earned prerequisite unlocks only registered authored Mill")
	store.data.completed = before
	world.access.refresh()
	for path in ["res://World/Zone1/Z1L1Shell.tscn","res://World/Zone1/Legacy/Z1L1Bodies.tscn","res://World/Zone1/Legacy/Z1L1Details.tscn","res://World/Navigation/ConnectedWorld.tscn","res://Zone_1/Levels/wrld_lvl_1.tscn"]:
		check(not ResourceLoader.has_cached(path), "run never loads " + path)
	if cold:
		check(provider._state.legacy.melted[0] == 1 and provider.bodies[0].collision_layer == 0, "melt and first barrier restored")
		check(store.data.active_run.state.checkpoint_progress.unlock_sequence == ["C0","C1"], "earned checkpoint survives separate process")
		check(store.data.active_run.state.device_outcomes.size() == 1 and store.pending_explanations().is_empty(), "single outcome and acknowledged feedback retained")
		check(world.player.position.distance_to(store.world_record().location.position) < 1, "player restores to saved grounded position")
		return
	await check_thermal(world,provider)

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):return
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(EVIDENCE + label + ".png") == OK, "desktop capture " + label)

func check_thermal(world: Node, provider: Node) -> void:
	check(await wait_for(func():return world.input_adapter.modal == "lesson"), "fresh guided lesson precedes Fire")
	if world.input_adapter.modal != "lesson":return
	check(not store.has_device_capability("melting"), "Thermal locked before guided acknowledgement")
	await capture("garden-lesson")
	world.panels.action_buttons["lesson_ack"].pressed.emit()
	check(await wait_for(func():return store.has_device_capability("melting") and provider.targets.size() == 1), "lesson acknowledgement grants Thermal and binds original target")
	if provider.targets.is_empty():return
	var before_hash := FileAccess.get_sha256(store.save_path)
	var key: String = store.instance_id("melting_and_freezing",1,"lesson_melting") + ":melting"
	world.input_adapter.open_panel("guides")
	world.input_adapter._open_guide(key)
	check(await wait_for(func():return is_instance_valid(world.input_adapter.guide_preview)), "free Melting Guide creates isolated demo")
	var preview: Node = world.input_adapter.guide_preview
	check(not store.campaign_source(preview,"melting_and_freezing",1) and not store.commit_world_lesson("melting_and_freezing",1,"melting","lesson_melting",preview), "preview cannot commit to live attempt")
	check(FileAccess.get_sha256(store.save_path) == before_hash and provider._state.legacy.melted[0] == 0, "preview leaves profile and puzzle unchanged")
	world.input_adapter.close_panel()
	check(await aim_at_barrier(world,provider), "supported authored approach selects the real Thermal target")
	var target: Node = provider.targets.get(provider.FIRST_ID)
	if target == null or world.input_adapter.emitter.selected != target:return
	await capture("garden-thermal")
	world.input_adapter.refresh()
	world.hud.route_touch(501,world.hud.rects.fire.get_center(),true)
	var melted := await wait_for(func():return provider._state.legacy.melted[0] == 1, 5000)
	world.hud.route_touch(501,world.hud.rects.fire.get_center(),false)
	check(melted and provider.bodies[0].collision_layer == 0, "HUD hold Fire commits verified melt and opens first collision barrier")
	check(provider.bodies[1].collision_layer != 0 and provider.bodies[2].collision_layer != 0, "independent fan and mirror barriers remain closed")
	check(await wait_for(func():return world.input_adapter.modal == "explanation"), "original first-success feedback appears")
	if world.input_adapter.modal == "explanation":world.panels.action_buttons["explanation_ack"].pressed.emit()
	check(store.data.extras.solved_puzzle_ids.get("melting_and_freezing:1:puzzle0") == "melt_direct", "original puzzle ID and receipt retained")
	check(store.world_record().attempts.Z1L1.checkpoint_progress.unlock_sequence == ["C0","C1"], "exact original checkpoint unlock")
	world.input_adapter.open_panel("pause")
	world.panels.action_buttons["save_menu"].pressed.emit()
	check(await wait_for(func():return current_scene != null and current_scene.scene_file_path == TITLE), "Pause Save & Menu returns to title")
	check(FileAccess.file_exists(store.save_path), "durable staged save created")

func aim_at_barrier(world: Node, provider: Node) -> bool:
	var target: Node = provider.targets.get(provider.FIRST_ID)
	var emitter: Node = world.input_adapter.emitter
	for radius in [55,65,75,85,95]:
		for step in 32:
			var point: Vector2 = target.get_meta("ground_xy") + Vector2.from_angle(step*TAU/32)*radius
			if not world.valid_landing(point) or not world.activate("Z1L1",point):continue
			emitter.facing = (target.global_position-world.player.device_muzzle().global_position).normalized()
			emitter.release()
			emitter._aim()
			if emitter.selected == target:
				await physics_frame
				return true
	return false
