extends SceneTree
## Used with the source project and with the exported pack as the main pack.
const TITLE := "res://UI/Menus/MainMenuPanel.tscn"
const WORLD := "res://World/CampaignWorld.tscn"
const SAVE := "user://phasequest_profile.save"
const OLD := ["res://Zone_1/Levels/wrld_lvl_1.tscn", "res://Zone_1/Levels/wrld_lvl_2.tscn",
	"res://World/PhaseWorld.tscn", "res://World/Navigation/ConnectedWorld.tscn",
	"res://UI/Guides/GameplayGuidePreview.tscn"]
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ",label)
	return ok

func run() -> void:
	await evaluate()
	print("ENTRY054 ","PASS" if failures == 0 else "FAIL"," ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)

func evaluate() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	var args := OS.get_cmdline_user_args()
	var desired := "Z1L1"
	var capture := ""
	var expected_stars := -1
	for arg in args:
		if arg.begins_with("--district="):desired = arg.trim_prefix("--district=")
		if arg.begins_with("--capture="):capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--stars="):expected_stars = arg.trim_prefix("--stars=").to_int()
	var settings: String = ProjectSettings.get_setting("application/run/main_scene","")
	if not check(settings == TITLE and change_scene_to_file(settings) == OK,"project main scene is the ordinary title"):return
	await scene_changed
	await process_frame
	var title := current_scene
	var profile := root.get_node("PlayerSave")
	check(profile.save_path == SAVE and OS.get_cmdline_user_args().find("--stage-campaign-garden") < 0,"real PlayerSave uses the ordinary profile")
	check(not profile.has_meta("r3_019_permissions") and not profile.has_meta("r3_015_fixture"),"real autoload has no fixture grants")
	var view: Control = title.view
	var earned: Dictionary = profile.data.completed.duplicate(true)
	if args.has("--new"):
		if not check(not view.buttons.continue.visible and not FileAccess.file_exists(SAVE),"fresh disposable profile starts empty"):return
	else:
		var backgrounds := {"Z1":"gardens","Z2":"vale","Z3":"laboratory"}
		var region: String = backgrounds[desired.left(2)]
		check(view.backdrop.current_region == region and not view.backdrop.fallback,"Continue selects the "+region+" title background")
		if not check(view.buttons.continue.visible and not view.buttons.continue.disabled,"ordinary saved title offers Continue"):return
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK,"captured production title background")
	if args.has("--new"):
		view.buttons.new_game.pressed.emit()
		title.name_input.text = "Phase Quest 054"
		view.dialog.action_buttons.confirm_new_game.pressed.emit()
	else:
		view.buttons.continue.pressed.emit()
	var transition := root.get_node("SceneTransition")
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == WORLD and not transition.busy:break
	var world := current_scene
	if not check(world != null and world.scene_file_path == WORLD,"ordinary title enters CampaignWorld"):return
	if not check(world.entry_authorized and not world.restoration_pending and world.active_subregion_id == desired,"authorized live district "+desired):return
	check(world.valid_landing(world.player.position) and profile.world_record().active_subregion == desired,"grounded location saved to the same district")
	check(profile.data.completed == earned,"entry preserves earned stars")
	if expected_stars >= 0:
		check(profile.total_stars() == expected_stars,"cold Continue retains all %d earned stars" % expected_stars)
	if args.has("--new"):
		check(not world.access.allowed("Z1L2") and not world.access.allowed("Z2L1") and not world.access.allowed("Z3L1"),"only introductory district is unlocked")
		for id in ["Z1L2","Z2L1","Z3L1"]:
			var row: Dictionary = world.REGISTRY.definition(id)
			var at := Vector2(row.entry[0],row.entry[1])
			var links: Array = world.permissions.get(id,[])
			check(not links.is_empty() and links.all(func(body):return body.collision_layer == 8) and not world.access.point_allowed(at)
				and world.map_provider.permission_image.get_pixelv(world.discovery.key_at(at)).r < .1,"collision and fog keep "+id+" locked")
		check(not profile.begin_level(profile.ZONES[0],1) and profile.request_next_world(world).is_empty(),"old start, completion and replay entry points cannot create a live attempt")
	if desired == "Z1L1":
		verify_guides(profile)
	check(OLD.all(func(path):return not ResourceLoader.has_cached(path)),"ordinary entry and replay load no old world or Guide scene")
	check(world.save_and_menu(),"grounded Save & Menu succeeds")
	await scene_changed
	check(current_scene.scene_file_path == TITLE and FileAccess.file_exists(SAVE),"real title restored and standard profile exists")

func verify_guides(profile: Node) -> void:
	var teaching: Script = load("res://Scripts/World/Learning/professor_content.gd")
	var before: Dictionary = profile.data.duplicate(true)
	var checksum := FileAccess.get_sha256(SAVE)
	for topic in ["melting","fuel_air","reflection","crystals","movement","professor","map"]:
		var model: Control = teaching.preview({"zone":profile.ZONES[0],"level":1,"object":"guide","topic":topic})
		if not check(is_instance_valid(model),"isolated Garden replay available for "+topic):continue
		root.add_child(model)
		model.replay()
		model.toggle_playback()
		model.free()
	check(profile.data == before and FileAccess.get_sha256(SAVE) == checksum,"Guide replays leave live memory and save bytes unchanged")
