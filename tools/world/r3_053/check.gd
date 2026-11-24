extends SceneTree

const TITLE := "res://UI/Menus/MainMenuPanel.tscn"
const CAMPAIGN := "res://World/CampaignWorld.tscn"
const ZONE := "melting_and_freezing"
const STANDARD := "user://phasequest_profile.save"
const MAP_KEY := "melting_and_freezing:1:waypoint0:map"
const FOREIGN_SCENES := [
	"res://Zone_1/Levels/wrld_lvl_1.tscn", "res://Zone_1/Levels/wrld_lvl_2.tscn",
	"res://World/Zone1/Z1L1Shell.tscn", "res://World/Zone1/Z1L2Shell.tscn",
	"res://World/Navigation/ConnectedWorld.tscn", "res://World/PhaseWorld.tscn"
]
var store: Node
var profile_path: String
var checks := 0
var failures := 0
var scenario := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ",description)
	return ok

func write_save(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_var(value)
	file.close()

func read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	return file.get_var(false) if file else {}

func garden() -> Dictionary:
	return {"position":Vector2(88888,88888),"circular_route_version":2,"melted":[0.6,0.0,0.0],
		"lit":[true,false,true],"collected":{0:true},"wood":false,"blades":false,
		"fan_installed":false,"vent":0,"mirror":3,"relays":[0,6],"receiver_lit":false,"ignition":0.0,
		"crystals":[1.0,0.0,0.0,0.0,0.0,0.0],"waypoints":[true,false,false],
		"module_state":"carried","carry_item":"module","local_unknown":{"retained":true}}

func seed_profile() -> void:
	var level := 2 if scenario.begins_with("mill-") else 1
	var payload := {"version":1,"player_name":"Legacy R3 053","future_root":{"token":[1,2,3]},
		"completed":{},"active_run":{"zone":ZONE,"level":level,"attempt_id":"attempt-053-"+scenario,
		"state":{"current":garden(),"health":6.0,"warmth":75.0,"future_state":true},"future_attempt":"keep"},
		"extras":{"future_extras":{"flag":true},"explained_puzzle_types":{"melt_direct":true},
		"achievement_unlocks":{"good_question":{"timestamp":42}},
		"guides_unlocked":{MAP_KEY:{"zone":ZONE,"level":1,"object":"waypoint0","topic":"map"}}}}
	if level == 2:payload.completed[ZONE+":1"]=true
	if scenario == "garden-r2" or scenario == "garden-receipt":
		payload.active_run.state.current.device_retrofit_version=1
		payload.active_run.state.current.legacy_first_heat=0.6
		payload.active_run.state.current.module_state="docked"
		payload.active_run.state.current.carry_item=""
		payload.extras.thermal_introduction_version=1
		payload.extras.lessons_seen={ZONE+":1:melting":true}
		payload.extras.guides_unlocked[ZONE+":1:lesson_melting:melting"]={"zone":ZONE,"level":1,"object":"lesson_melting","topic":"melting"}
	if scenario == "garden-receipt":
		var target := "garden_first_barrier"
		var receipt := {"version":1,"id":target,"process":"melting","material":"water","from_state":"solid",
			"to_state":"liquid","capability":"melting","puzzle_type":"melt_direct"}
		payload.active_run.state.current.melted[0]=1.0
		payload.active_run.state.device_outcomes={target:receipt}
		payload.extras.independent_phase_evidence={ZONE+":1:"+target:receipt}
		payload.extras.solved_puzzle_ids={ZONE+":1:puzzle0":"melt_direct"}
	if scenario == "garden-complete" or scenario == "mill-complete":
		payload.completed[ZONE+":"+str(level)]=true
		payload.active_run={}
	if scenario == "mill-held":
		payload.active_run.state={"route_version":2,"workshop_version":1,"part":"docked","clear":true,
			"bell_count":3,"workshop_parts":[2,1,0],"workshop_held":1,"checkpoint":"C1","future_state":true}
	if scenario == "mill-installed":
		payload.active_run.state={"part":"docked","clear":true,"gear_thawed":true,"latch_thawed":true,"cache_thawed":true,
			"walkback_open":true,"crank":"installed","checkpoint":"C2","future_state":true}
	if scenario in ["path","foreign-path"]:
		payload.active_run.erase("zone")
		payload.active_run.erase("level")
		payload.active_run.scene_path=FOREIGN_SCENES[0] if scenario=="path" else "res://World/NotACompatibilityAlias.tscn"
	if scenario == "future":payload.version=99
	if scenario == "future-world":payload.extras.world_state={"version":1,"campaign_layout_version":99}
	if scenario == "future-attempt":payload.active_run.state.current.device_retrofit_version=99
	if scenario == "backup":
		write_save(profile_path+".bak",payload)
		FileAccess.open(profile_path,FileAccess.WRITE).store_string("corrupt primary retained")
	elif scenario == "corrupt":
		FileAccess.open(profile_path,FileAccess.WRITE).store_string("corrupt primary retained")
	else:
		write_save(STANDARD if scenario=="garden-carried" else profile_path,payload)

func run() -> void:
	store=root.get_node("PlayerSave")
	profile_path=store.save_path
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
	if args.has("--seed"):
		seed_profile()
		quit()
		return
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	await resume_case(args.has("--second"), args.has("--retry"))
	print("CAMPAIGN053 ", "PASS" if failures==0 else "FAIL"," ",scenario," ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)

func resume_case(second: bool, retry: bool) -> void:
	var original_source := STANDARD if scenario=="garden-carried" else profile_path
	var source := profile_path if second else original_source
	var original_bytes := FileAccess.get_sha256(source)
	var backup_bytes := FileAccess.get_sha256(source+".bak") if FileAccess.file_exists(source+".bak") else ""
	var raw := read_save(source) if scenario not in ["corrupt","backup"] or second else {}
	var prior: Dictionary=store.data.duplicate(true)
	change_scene_to_file(TITLE)
	await scene_changed
	await process_frame
	var menu := current_scene
	if scenario in ["future","future-world","future-attempt","foreign-path","corrupt"]:
		check(store.read_only and not menu.view.buttons["continue"].visible and menu.view.dialog_id=="unsupported_save","unsupported/corrupt save shows the recovery dialog and has no Continue")
		check(not store.save_profile() and FileAccess.get_sha256(source)==original_bytes,"retained input is byte-identical")
		return
	if not check(not menu.view.buttons["continue"].disabled,"ordinary title offers Continue"):return
	if scenario == "rollback" and not second and not retry:
		check(DirAccess.make_dir_absolute(profile_path+".tmp")==OK,"block actual write after title")
	menu.view.buttons["continue"].pressed.emit()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 90000:
		await process_frame
		if current_scene and current_scene.scene_file_path==CAMPAIGN and not root.get_node("SceneTransition").busy:break
	var world := current_scene
	if not check(world!=null and world.scene_file_path==CAMPAIGN,"real title routes to CampaignWorld"):return
	if scenario=="rollback" and not second and not retry:
		check(not world.entry_authorized and world.restoration_pending,"safe entry panel after failed write")
		check(prior==store.data and not store.session_active,"failed write rolled back in-memory profile and session")
		check(FileAccess.get_sha256(source)==original_bytes,"failed write preserves original bytes")
		check(DirAccess.remove_absolute(profile_path+".tmp")==OK,"clear write obstruction for cold retry")
		return
	if not check(world.entry_authorized and not world.restoration_pending,"restored production ownership"):return
	var id: String = world.active_subregion_id
	var expected := str(prior.get("extras",{}).get("world_state",{}).get("active_subregion",""))
	if expected.is_empty():expected="Z1L2" if scenario.begins_with("mill-") else "Z1L1"
	check(id==expected and world.valid_landing(world.player.position),"same district and safe authored ground "+expected)
	check(store.world_record().campaign_layout_version==1,"campaign layout version committed")
	if not second:
		var archive_hash := backup_bytes if scenario=="backup" else original_bytes
		var archive := profile_path+".before-campaign-"+archive_hash+".save"
		check(FileAccess.file_exists(archive) and FileAccess.get_sha256(archive)==archive_hash,"original bytes preserved in immutable migration backup")
		if scenario=="garden-carried" and profile_path!=STANDARD:check(FileAccess.get_sha256(STANDARD)==original_bytes,"compatibility input remains untouched")
		if scenario=="backup":check(FileAccess.get_sha256(profile_path+".corrupt")==original_bytes and FileAccess.get_sha256(profile_path+".bak")==backup_bytes,"corrupt original and valid recovery file retained")
	else:
		check(FileAccess.get_sha256(profile_path)==original_bytes,"second cold Continue leaves profile bytes identical")
	if not scenario.begins_with("zone"):
		check(store.data.future_root.token==[1,2,3] and store.data.extras.future_extras.flag,"unknown profile fields retained")
		check(store.guide_records().has(MAP_KEY) and store.achievement_state().unlocks.has("good_question"),"earned Guide and achievement retained")
	var provider: Node=world.learning_provider()
	var props: Dictionary=provider._state.get("legacy",{})
	if scenario in ["garden-carried","garden-r2","path","rollback","backup"]:
		check(is_equal_approx(props.legacy_first_heat,0.6) and not world.player.carrying,"legacy first heat credit retained and obsolete heater module released")
		check(is_equal_approx(provider.targets[provider.FIRST_ID].definition().required_exposure,1.2) and provider.targets[provider.FIRST_ID].exposure()==0.0,"only remaining Thermal exposure is required")
		check(store.data.active_run.future_attempt=="keep" and store.data.active_run.state.future_state and props.local_unknown.retained,"unknown attempt and snapshot fields retained")
		check(world.hp==6.0 and world.warmth==75.0 and world.player.position==world.checkpoint_anchor(id,"C0"),"health/warmth retained and unsafe old local position falls back to C0")
	if scenario=="garden-r2":check(store.is_device_mode_unlocked("thermal") and not store.is_level_complete(ZONE,1),"partial R2 access retained without completion")
	if scenario=="garden-receipt":
		check(provider.targets.is_empty() and provider.bodies[0].collision_layer==0 and store.data.active_run.state.device_outcomes.size()==1,"completed R2 first thaw stays open with one receipt")
	if scenario=="garden-complete":
		check(store.total_stars()==1 and props.collected.size()==6 and provider.targets.is_empty(),"completion-only Garden retains all six crystals and one star")
		if not second:await verify_demonstrations(world)
	if scenario=="mill-held":
		check(props.workshop_parts==[2,1,0] and props.workshop_held==1 and world.player.carrying and provider._held.get_meta("unique_item_id")=="crank","exact installed gear and one carried crank")
	if scenario=="mill-installed":
		check(props.crank=="installed" and props.workshop_parts==[2,2,2] and not world.player.carrying and world.player.position==world.checkpoint_anchor(id,"C2"),"installed legacy lift and newest C2 preserved")
	if scenario=="mill-complete":
		check(store.total_stars()==2 and provider.PROGRESS.complete(props) and not world.player.carrying,"completion-only Mill remains completed")
	if scenario.begins_with("zone"):
		var archived: Dictionary = raw.extras.get("world_state",{}).get("attempts",{}).get(id,{}).get("attempt",{})
		var original_run: Dictionary = raw.active_run if not raw.active_run.is_empty() else archived
		check(not original_run.is_empty() and raw.completed==store.data.completed and original_run.get("attempt_id")==store.data.active_run.get("attempt_id") and original_run.get("state")==store.data.active_run.get("state"),"earned completions and full active or archived attempt restored")
	check(FOREIGN_SCENES.all(func(path):return not ResourceLoader.has_cached(path)),"no standalone or review world scene loaded by Continue or the map demo")
	for zone in range(1,4):
		for level in range(1,7):
			var path := "res://World/Zone%d/Z%dL%dShell.tscn" % [zone,zone,level]
			if ResourceLoader.has_cached(path):
				check(false,"unexpected loaded district shell "+path)

func verify_demonstrations(world: Node) -> void:
	var before: Dictionary = store.data.duplicate(true)
	var hash := FileAccess.get_sha256(profile_path)
	world.input_adapter.close_panel()
	world.input_adapter.open_panel("guides")
	world.input_adapter._open_guide(MAP_KEY)
	var demo: Node = world.input_adapter.guide_preview
	if check(is_instance_valid(demo) and demo.mode=="map" and demo.viewport.gui_disable_input,"campaign Guides open the isolated checkpoint demo"):
		demo.advance_dialogue()
		demo.advance_dialogue()
		check(demo.phase==2 and demo.checkpoint_ids.has("C1"),"sample marker reaches the attuned checkpoint")
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			var image: Image = demo.viewport.get_texture().get_image()
			check(image.save_png("res://output/world/r3-prompt053/evidence/checkpoint-demo.png")==OK,"rendered checkpoint illustration")
	world.input_adapter.close_panel()
	var guide: Node = load("res://UI/Guides/ProfessorGuide.tscn").instantiate()
	root.add_child(guide)
	guide._choose("play")
	guide.scene.advance_dialogue()
	guide.scene.advance_dialogue()
	guide.scene.advance_dialogue()
	check(guide.scene.viewport.gui_disable_input and guide.scene._map_visible(),"Professor How to Play uses the isolated map")
	guide.free()
	var journal: Node = load("res://UI/Dialogs/GardensJournal.tscn").instantiate()
	root.add_child(journal)
	journal._toggle_level(1,true)
	journal._replay()
	journal.demonstration.advance_dialogue()
	check(journal.demonstration.viewport.gui_disable_input and journal.demonstration.running,"Journal replays the illustrated melting lesson")
	journal.free()
	check(store.data==before and FileAccess.get_sha256(profile_path)==hash,"Guide and Journal leave live memory and disk unchanged")
