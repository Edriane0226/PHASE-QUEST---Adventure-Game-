extends SceneTree
const HOST=preload("res://Scripts/World/Navigation/connected_world.gd")
var world: Node
var driver: Node
var checks:=0
var failures: Array=[]
var captures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func shot(label: String) -> void:
	# Modal creation and native Container layout can straddle the paused frame boundary.
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	if world.panels.visible:
		for id in world.panels.action_buttons:
			var button: Control=world.panels.action_buttons[id]
			print("PANEL023 ",label," button=",id," visible=",button.is_visible_in_tree()," rect=",button.get_global_rect()," footer=",world.panels.footer.get_global_rect()," panel=",world.panels.card.get_global_rect())
			check(button.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"Professor action visible inside phone viewport "+id)
	root.get_texture().get_image().save_png("res://../evidence/"+label+".png");captures.append(label+".png")
func touch_context(action: String) -> bool:
	if not driver.position_for(action):return false
	await process_frame;await physics_frame;world.input_adapter.refresh()
	var button: Control=world.hud.controls.context
	if not button.is_visible_in_tree():return false
	var at: Vector2=button.get_global_rect().get_center()
	world.hud.route_touch(901,at,true);world.hud.route_touch(901,at,false)
	return true
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame;world=current_scene
	driver=load("res://review_driver.gd").new();root.add_child(driver);check(driver.bind(world),"actual world/assembly fixture binds")
	if driver.provider==null:finish();return
	var provider=driver.provider;var store=root.get_node("PlayerSave")
	FileAccess.open("res://../evidence/assembly-contract.json",FileAccess.WRITE).store_string(JSON.stringify(provider.contract,"\t"))
	for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
		root.size=dimensions;root.content_scale_size=root.size
		world.activate("Z1L5",driver.room.point(Vector2(10,3.5)));await shot("exterior-"+str(dimensions.x))
		check(not driver.room.occupied,"exterior restores roof at "+str(dimensions.x))
		world.activate("Z1L5",driver.room.point(Vector2(6.8,4.2)));provider.refresh_binding();await shot("independent-pieces-"+str(dimensions.x))
		check(driver.room.occupied and provider.assemblies.work.parts.size()==10,"inside roof cuts over independently sorted components")
		check(world.hud.supported and world.hud.is_visible_in_tree(),"approved HUD at "+str(dimensions.x))
	root.size=Vector2i(640,360);root.content_scale_size=root.size
	check(await touch_context("power"),"real shared touch contextual control")
	check(provider._state.components["work/control"].enabled and provider._state.components["work/sample"].phase=="solid","touch control changes no sample mastery")
	check(await touch_context("flow"),"real shared touch pipe action");await shot("control-pipe-independent-640")
	check(provider._state.components["work/pipe"].open,"pipe independent committed state")
	check(world.input_adapter.open_lesson("melting"),"existing Professor content panel")
	check(world.panels.search==null and world.panels.model.rows.is_empty() and world.panels.action_buttons.has("lesson_ack"),"lesson shows real content and acknowledgment without default Guide widgets")
	await shot("professor-lesson-640");check(world.panels.model.speaker=="professor_z1","existing Scaldwell portrait/name")
	world.input_adapter._panel_intent("guides.library","lesson_ack",{"view_revision":world.panels.revision})
	var target=provider.targets["review-water"];var anchor=provider.component("work/sample")
	check(world.activate("Z1L5",anchor.position+Vector2(42,30)),"supported Fire approach")
	provider.refresh_binding();store.select_device_mode("thermal");await physics_frame
	var emitter=world.input_adapter.emitter;emitter.facing=(target.global_position-world.player.device_muzzle().global_position).normalized();emitter.release()
	check(emitter.press(),"native Fire starts on real fixture target")
	for tick in range(3):await physics_frame
	await shot("native-thermal-contact-640")
	for tick in range(80):
		await physics_frame
		if target.is_committed():break
	emitter.release();await process_frame;await process_frame
	check(target.is_committed() and provider._state.components["work/sample"].phase=="liquid","native receipt drives separate sample effect")
	check(world.input_adapter.modal=="explanation","once-only first-success panel shown")
	check(world.panels.search==null and world.panels.model.rows.is_empty() and world.panels.action_buttons.has("explanation_ack"),"explanation presents acknowledgment without default Guide widgets")
	await shot("first-success-explanation-640")
	world.input_adapter._panel_intent("guides.library","explanation_ack",{"view_revision":world.panels.revision})
	check(await touch_context("pickup") and world.player.carrying,"real touch pickup renders one held part")
	await shot("single-carried-part-640")
	check(store.save_world_location(world),"rendered carried state saves")
	store.load_profile();check(world.restore_saved_world(world.access),"rendered Continue restores part and cutaway")
	await shot("carry-continue-640")
	check(await touch_context("place") and not world.player.carrying,"real touch placement consumes held owner once")
	world.activate("Z1L5",driver.room.point(Vector2(6.8,4.2)));await shot("restored-assembled-worksite-640")
	world.activate("Z1L5",driver.room.point(Vector2(10,3.5)));await shot("exit-roof-restored-640")
	check(not driver.room.occupied and provider._state.items["review-part"]=="installed:work/socket","exit restores roof while preserving unique installed part")
	finish()
func finish() -> void:
	FileAccess.open("res://../evidence/render-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"captures":captures,"scope":"Desktop gl_compatibility1280/640 shared HUD touch, native device and separate-piece/cutaway review; no physical Android claim"},"\t"))
	print("RENDER023 ",checks," checks / ",failures.size()," failures / ",captures.size()," captures");quit(0 if failures.is_empty() else 1)
