extends SceneTree
const WS=preload("res://Scripts/Content/world_save.gd")
var checks:=0
var failures: Array=[]
var captures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/"+name+".png");captures.append(name+".png")
func run() -> void:
	var profile=root.get_node("PlayerSave");profile.readiness_probe=true
	for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
		root.size=dimensions;root.content_scale_size=root.size
		for n in range(1,4):
			var row:=WS.REGISTRY.definition("Z%dL1"%n)
			profile.data={"version":1,"player_name":"Render fixture","completed":{},"active_run":{"zone":row.zone_id,"level":1,"state":{},"attempt_id":"render"},"extras":{}}
			for r in WS.REGISTRY.definitions():profile.data.completed[r.completion_key]=true
			profile.data=WS.migrate(profile.data);var before: Dictionary=profile.data.duplicate(true)
			change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn");await scene_changed
			var menu=current_scene
			await shot("menu-%d-zone%d"%[dimensions.x,n])
			check(not menu.view.backdrop.fallback and menu.view.supported,"actual geographic view at "+str(dimensions)+" zone"+str(n))
			for id in menu.view.buttons:
				var button: Button=menu.view.buttons[id]
				if button.visible:
					check(menu.view.safe.encloses(Rect2(button.global_position,button.size)),"safe action target "+id)
			check(menu.view.logo.position.y>=menu.view.safe.position.y and menu.view.logo.get_rect().end.y<menu.view.menu.position.y,"original title above quiet actions")
			check(profile.data==before,"rendered view writes no gameplay/discovery")
	var menu=current_scene
	menu.view._activate("new_game");await shot("menu-new-game-confirm")
	check(is_instance_valid(menu.name_input) and menu.view.dialog.visible,"rendered named confirmation")
	menu.view._dialog_intent("pause.open","menu_back",{})
	menu.preferences.reduced_motion=false;menu._refresh();await process_frame;await process_frame
	check(menu.view.backdrop.variant=="layered" and menu.view.backdrop.clock>0,"opt-in subtle atmosphere advances")
	menu._settings();var frozen: float=menu.view.backdrop.clock;await shot("menu-settings")
	check(menu.view.backdrop.reduced_motion and menu.view.backdrop.clock==frozen,"options freeze atmosphere")
	menu.view._dialog_intent("pause.open","menu_back",{})
	menu.view.backdrop._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);frozen=menu.view.backdrop.clock
	await process_frame;await process_frame
	check(menu.view.backdrop.clock==frozen,"focus loss freezes atmosphere")
	menu.view.backdrop._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	menu.preferences.reduced_motion=true;menu._refresh();frozen=menu.view.backdrop.clock
	await shot("menu-reduced-motion")
	check(menu.view.backdrop.variant=="static" and menu.view.backdrop.clock==frozen,"reduced motion uses static geographic capture")
	var missing: Dictionary=menu.view.model.duplicate(true);missing.force_missing_background=true;menu.view.present(missing)
	await shot("menu-missing-background")
	check(menu.view.backdrop.fallback and menu.view.region_label.text.is_empty(),"neutral missing-art fallback")
	profile.readiness_probe=false
	profile.data={"version":1,"player_name":"","completed":{},"active_run":{},"extras":{}}
	change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn");await scene_changed
	menu=current_scene;menu.view._activate("new_game")
	await shot("menu-name-entry")
	check(menu.name_input.get_theme_color("font_placeholder_color")==Color("546255"),"name placeholder uses dark text on paper")
	menu.name_input.text="GPU journey fixture"
	menu._intent("confirm_new_game",{"menu_revision":menu.view.revision,"context_key":menu.context})
	var ticks:=0
	while root.get_node("SceneTransition").busy and ticks<100:await create_timer(.1).timeout;ticks+=1
	check(not root.get_node("SceneTransition").busy and current_scene.scene_file_path=="res://Zone_1/Levels/wrld_lvl_1.tscn","GPU New Game button reaches retained campaign through canonical world entry")
	check(profile.campaign_source(current_scene,profile.ZONES[0],1),"GPU entry retains real source authority")
	await shot("legacy-world-entry")
	profile.data.completed["melting_and_freezing:1"]=true;profile.save_profile()
	var legacy=current_scene;legacy.complete=true;legacy.story.hide();legacy.end_panel.show();legacy._show_world_journey()
	await shot("legacy-completion-journey")
	var button: Button=legacy.get_node("GameplayHUD/JourneyCompletion").action_buttons.journey_next
	check(button.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"direct earned journey action fits compact viewport")
	FileAccess.open("res://../evidence/render-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures},"\t"))
	print("MENU RENDER ",checks," checks / ",failures.size()," failures / ",captures.size()," captures")
	quit(0 if failures.is_empty() else 1)
