extends SceneTree
const WS=preload("res://Scripts/Content/world_save.gd")
const MENU=preload("res://Scripts/Content/menu_campaign.gd")
const SESSION=preload("res://Scripts/UI/Title/menu_session.gd")
var checks:=0
var failures: Array=[]
var profile: Node
var menu: Node
var entered: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func fresh() -> Dictionary:
	return {"version":1,"player_name":"Fixture explorer","completed":{},"active_run":{},"extras":{"currency":17,"inventory":{"part:original":1},"study":{"version":9,"keep":true}}}
func earned(id: String) -> Dictionary:
	var value:=fresh();var row:=WS.REGISTRY.definition(id)
	for r in WS.REGISTRY.definitions():value.completed[r.completion_key]=true
	value.active_run={"zone":row.zone_id,"level":int(row.level),"state":{"unique_item":"part:original","health":7.0,"warmth":39.0},"attempt_id":"original-"+id}
	return WS.migrate(value)
func write_profile() -> void:
	var file:=FileAccess.open(profile.save_path,FileAccess.WRITE);file.store_var(profile.data);file.close()
func open_menu() -> void:
	change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn");await scene_changed;await process_frame;menu=current_scene
func payload() -> Dictionary:
	return {"menu_revision":menu.view.revision,"view_revision":menu.view.revision,"context_key":menu.context}
func menu_checks() -> void:
	profile.data=fresh();write_profile()
	var snapshot: Dictionary=profile.data.duplicate(true);var hash:=FileAccess.get_sha256(profile.save_path)
	var last:=""
	for i in range(9):
		await open_menu()
		check(menu.chosen_region in SESSION.REGIONS and menu.chosen_region!=last,"no-Continue repeated opening excludes last "+str(i))
		last=menu.chosen_region
		check(not menu.view.buttons["continue"].visible,"first launch hides Continue")
		var prefs:=SESSION.new();prefs.load_preferences();check(prefs.last_region==last,"selection survives new preference instance")
		var region: String=menu.chosen_region
		menu.view._activate("options");await process_frame
		menu.view._dialog_intent("pause.open","menu_back",{})
		check(menu.chosen_region==region and menu.view.backdrop.current_region==region,"view stays fixed during Options/open frames")
	check(profile.data==snapshot and FileAccess.get_sha256(profile.save_path)==hash,"opening/rotation/options write no profile progress")
	check(menu.find_children("*Zone*","",true,false).is_empty(),"normal title has no zone/level selector")
	for n in range(1,4):
		profile.data=earned("Z%dL1"%n);profile.readiness_probe=true;write_profile();snapshot=profile.data.duplicate(true);hash=FileAccess.get_sha256(profile.save_path)
		await open_menu()
		check(menu.view.buttons["continue"].visible and menu.chosen_region==MENU.REGIONS[profile.data.active_run.zone],"saved current zone selects view "+str(n))
		check(profile.data==snapshot and FileAccess.get_sha256(profile.save_path)==hash,"locked-region preview grants no discovery/progress "+str(n))
		var stable: String=menu.chosen_region
		for frame in range(4):await process_frame
		check(menu.chosen_region==stable,"Continue view held "+str(n))
	profile.readiness_probe=false
	profile.data=earned("Z1L1");check(profile.menu_resume().zone==profile.ZONES[0],"current Zone1 wins over highest completed Zone3")
	profile.data=earned("Z2L1");check(profile.menu_resume().is_empty(),"unintegrated future provider not resumable in production")
	for raw in [{"version":99,"future":{"keep":true}},{"version":1,"location":[]},{"version":1,"active_zone":"unknown","active_subregion":"Z1L1","location":{"version":1,"subregion":"Z1L1"}}]:
		profile.data=fresh();profile.data.extras[WS.KEY]=raw;write_profile();snapshot=profile.data.duplicate(true)
		await open_menu();check(not menu.view.buttons["continue"].visible and profile.data==snapshot,"invalid/future world metadata retained; Continue hidden")
	profile.data=earned("Z1L1");profile.data.extras[WS.KEY].active_zone=profile.ZONES[2]
	check(profile.menu_resume().is_empty(),"mismatched current-zone metadata never picks highest completion")
	profile.data=earned("Z1L2");profile.data.completed.clear();check(profile.menu_resume().is_empty(),"saved location cannot bypass actual prerequisites")
	profile.data.completed["melting_and_freezing:1"]={"invalid":true}
	check(profile.menu_resume().is_empty(),"malformed known completion never grants a menu destination")
	profile.data=fresh();profile.read_only=true;await open_menu()
	check(not menu.view.buttons.new_game.disabled==false and menu.view.dialog_id=="unsupported_save","unknown root blocks New Game and exposes safe recovery")
	profile.read_only=false
	profile.data=fresh();await open_menu()
	var chosen: String=menu.chosen_region
	menu.view.backdrop.entries[chosen].static="res://missing_menu_background.png"
	menu.view.present(menu.view.model)
	check(menu.view.backdrop.fallback and menu.view.menu.visible and menu.view.region_label.text.is_empty(),"missing background uses neutral usable fallback")
	menu.view.backdrop.entries[chosen].static="res://Scripts/UI/Title/menu_session.gd";menu.view.present(menu.view.model)
	check(menu.view.backdrop.fallback and menu.view.backdrop.textures.is_empty(),"wrong resource type falls back without texture draw crash")
	check(profile.data==fresh(),"fallback never repairs or resets gameplay")
	menu.preferences.reduced_motion=false;menu._refresh();await process_frame
	menu._settings();check(menu.view.backdrop.reduced_motion,"modal freezes background movement")
	check(menu.view.dialog.model.rows.is_empty() and menu.view.dialog.model.settings.size()==3,"Settings contains its three settings without inherited Options rows")
	var p:=payload();p.setting_id="reduced_motion";p.value=true;menu._intent("setting",p)
	menu.view._dialog_intent("pause.open","menu_back",{})
	check(menu.view.backdrop.reduced_motion and menu.preferences.reduced_motion,"reduced motion stays static after closing settings")
	var journal_before: Dictionary=profile.data.duplicate(true);menu._journal()
	check(menu.view.dialog.model.badges.size()==profile.ACHIEVEMENTS.DEFINITIONS.size() and profile.data==journal_before,"Journal exposes real badge records without acknowledging or awarding")
func reset_checks() -> void:
	profile.data=earned("Z1L1");profile.readiness_probe=false;write_profile();await open_menu()
	var before: Dictionary=profile.data.duplicate(true);var hash:=FileAccess.get_sha256(profile.save_path)
	menu.view._activate("new_game")
	check(menu.view.dialog_id=="new_game" and is_instance_valid(menu.name_input),"New Game requires named confirmation even on existing save")
	menu.view._dialog_intent("pause.open","menu_back",{})
	menu._intent("confirm_new_game",payload())
	check(profile.data==before and FileAccess.get_sha256(profile.save_path)==hash,"cancel/stale confirm cannot reset adventure")
	menu.view._activate("new_game");var old:=payload()
	profile.data.extras.earned_after_dialog=true;profile.changed.emit();menu._intent("confirm_new_game",old)
	check(profile.data.extras.earned_after_dialog and profile.data.active_run.attempt_id==before.active_run.attempt_id,"profile change invalidates destructive confirmation")
	menu.view._activate("new_game");menu.name_input.text="Replacement explorer";profile.fail_commit=true
	var failed: Dictionary=profile.data.duplicate(true);menu._intent("confirm_new_game",payload())
	check(profile.data==failed and current_scene==menu and not menu.error_label.text.is_empty(),"failed New Game save rolls back and stays in confirmation")
	profile.fail_commit=false
	var context: String=profile.menu_context()
	check(profile.start_new_world(" ",context).is_empty() and profile.data==failed,"empty name never resets save")
	var old_namespace: String=profile.world_discovery_namespace();hash=FileAccess.get_sha256(profile.save_path)
	entered.clear();var observe:=func():entered.append(current_scene.scene_file_path)
	scene_changed.connect(observe)
	menu._intent("confirm_new_game",payload())
	check(not profile.world_entry_request.is_empty() and profile.data.completed.is_empty() and profile.data.active_run.level==1,"confirmed New Game button targets canonical world and fresh first attempt")
	check(profile.last_new_game_archive!="" and FileAccess.get_sha256(profile.last_new_game_archive)==hash,"whole prior profile archived byte-for-byte before successful replacement")
	check(profile.world_discovery_namespace()!=old_namespace,"New Game has independent discovery identity")
	await wait_transition();scene_changed.disconnect(observe)
	check(entered.has(WS.REGISTRY.WORLD_SCENE),"confirmed button visits canonical world root")
	check(not entered.has("res://UI/Menus/ZoneSelectionPanel.tscn") and not entered.has("res://UI/Menus/ZoneLevelsPanel.tscn"),"confirmed button bypasses selection screens")
	check(current_scene.scene_file_path=="res://Zone_1/Levels/wrld_lvl_1.tscn","world entry preserves actual existing L1 compatibility source")
	check(profile.campaign_source(current_scene,profile.ZONES[0],1),"legacy L1 authority preserved after new world entry")
	check(profile.next_world_region(current_scene).is_empty(),"unfinished source cannot skip to next region")
	# Explicit isolated completion fixture; no puzzle outcome is fabricated in a user profile.
	profile.data.completed["melting_and_freezing:1"]=true;profile.save_profile();current_scene.complete=true
	current_scene._show_world_journey()
	check(current_scene.has_node("GameplayHUD/JourneyCompletion") and profile.next_world_region(current_scene)=="Z1L2","earned L1 completion exposes a direct Mill journey without a picker")
	current_scene.get_node("GameplayHUD/JourneyCompletion").action_buttons.journey_next.pressed.emit();await wait_transition()
	check(current_scene.scene_file_path=="res://Zone_1/Levels/wrld_lvl_2.tscn" and profile.total_stars()==1,"completion journey reaches existing Mill without granting progress")
	profile.data.completed["melting_and_freezing:2"]=true;current_scene.complete=true
	check(profile.next_world_region(current_scene).is_empty(),"next unfinished region remains unavailable after Mill")
func wait_transition() -> void:
	var ticks:=0
	while root.get_node("SceneTransition").busy and ticks<100:
		await create_timer(.1).timeout;ticks+=1
	check(not root.get_node("SceneTransition").busy,"loading overlay releases after canonical/compatibility entry")
func enter_world(path: String) -> void:
	entered.clear()
	var observe:=func():entered.append(current_scene.scene_file_path)
	scene_changed.connect(observe)
	change_scene_to_file(path)
	await scene_changed;await create_timer(.4).timeout
	scene_changed.disconnect(observe)
	check(entered.has(WS.REGISTRY.WORLD_SCENE),"entry visits canonical world root")
	check(not entered.has("res://UI/Menus/ZoneSelectionPanel.tscn") and not entered.has("res://UI/Menus/ZoneLevelsPanel.tscn"),"world entry never traverses a selection screen")
func continue_checks() -> void:
	if current_scene:current_scene.queue_free();current_scene=null;await process_frame
	profile.data=earned("Z1L2");profile.readiness_probe=false;write_profile()
	var id: String=profile.data.active_run.attempt_id;var earned_extras: Dictionary=profile.data.extras.duplicate(true)
	var path: String=profile.request_world_continue()
	check(path==WS.REGISTRY.WORLD_SCENE and profile.data.active_run.attempt_id==id,"Continue preserves attempt while targeting world")
	await enter_world(path)
	check(current_scene.scene_file_path=="res://Zone_1/Levels/wrld_lvl_2.tscn" and profile.campaign_source(current_scene,profile.ZONES[0],2),"world Continue reaches unchanged authorized Mill source")
	check(profile.data.active_run.attempt_id==id and profile.data.extras.inventory==earned_extras.inventory and profile.data.extras.study==earned_extras.study,"Continue keeps item/study/attempt identity")
	var source=current_scene
	check(source.persistent_session,"Mill session persistent")
	source.return_to_main_menu();await scene_changed;await process_frame
	menu=current_scene
	check(menu.scene_file_path=="res://UI/Menus/MainMenuPanel.tscn" and menu.chosen_region=="gardens" and menu.view.buttons["continue"].visible,"actual Save & Menu reopens saved current-zone title")
	entered.clear();var observe:=func():entered.append(current_scene.scene_file_path)
	scene_changed.connect(observe)
	menu.view._activate("continue");await wait_transition();scene_changed.disconnect(observe)
	check(entered.has(WS.REGISTRY.WORLD_SCENE) and current_scene.scene_file_path=="res://Zone_1/Levels/wrld_lvl_2.tscn","actual Continue button traverses world entry to saved campaign source")
	# Old method remains compatible but exits to title, never to a picker.
	current_scene.open_level_selection();await scene_changed;await process_frame
	check(current_scene.scene_file_path=="res://UI/Menus/MainMenuPanel.tscn","legacy completion return bypasses level selection")
func preference_checks() -> void:
	var config:=ConfigFile.new();var path:="user://future-menu.cfg"
	config.set_value("menu","version",99);config.set_value("future","keep",42);config.save(path)
	var hash:=FileAccess.get_sha256(path);var future:=SESSION.new();future.path=path;future.load_preferences();future.choose()
	check(future.read_only and FileAccess.get_sha256(path)==hash,"future menu preferences retained without downgrade")
	path="user://known-menu.cfg";config.set_value("menu","version",1);config.set_value("menu","last_region","gardens");config.save(path)
	var known:=SESSION.new();known.path=path;known.load_preferences();check(known.choose()=="vale","known preference resumes deterministic no-repeat cycle")
	config.load(path);check(config.get_value("future","keep")==42,"unknown supported preference fields preserved")
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	profile=root.get_node("PlayerSave")
	check(ProjectSettings.globalize_path("user://").contains("r3-prompt021") and profile.save_path.begins_with("res://../fixtures/"),"entire project/profile/user storage isolated")
	var sentinel:="user://phasequest_profile.save";var file:=FileAccess.open(sentinel,FileAccess.WRITE);file.store_var({"sentinel":"unchanged"});file.close();var sentinel_hash:=FileAccess.get_sha256(sentinel)
	preference_checks();await menu_checks();await reset_checks();await continue_checks()
	check(FileAccess.get_sha256(sentinel)==sentinel_hash,"normal-profile sentinel untouched")
	FileAccess.open("res://../evidence/check-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"user_storage":ProjectSettings.globalize_path("user://"),"entry":"canonical world with guarded legacy L1/L2 compatibility"},"\t"))
	print("MENU021 ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
