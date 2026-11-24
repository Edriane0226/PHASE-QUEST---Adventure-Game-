extends SceneTree
const WORLD=preload("res://World/PhaseWorld.tscn")
const CHUNK=preload("res://Scripts/World/Runtime/world_chunk.gd")
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const AUTHORITY=preload("res://Scripts/Content/world_source_authority.gd")
const PROVIDER=preload("res://fixture_provider.gd")
const ANCHOR=preload("res://Scripts/World/Runtime/grounded_visual.gd")
var world: Node
var profile: Node
var checks: Array=[]
var failures: Array=[]
var captures: Array=[]
var output: String
var manual:=false
var west: Node
var east: Node
class Driver extends Node:
	var review: SceneTree
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode==KEY_1:review.extent(Vector2i(1280,720))
			elif event.physical_keycode==KEY_2:review.extent(Vector2i(640,360))
			elif event.physical_keycode==KEY_3:review.world.player.carrying=not review.world.player.carrying;review.world.input_adapter.refresh()
			elif event.physical_keycode==KEY_4:review.set_modes(false)
			elif event.physical_keycode==KEY_5:review.set_modes(true)
			elif event.physical_keycode==KEY_6:review.cross()
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);print("FAIL ",message)
func extent(value: Vector2i) -> void:
	root.size=value;root.content_scale_size=value
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"));captures.append(name+".png")
func tap(id: String,index:=1,cancel:=false) -> void:
	world.hud.route_touch(index,world.hud.rects[id].get_center(),true)
	world.hud.route_touch(index,world.hud.rects[id].get_center(),false,cancel)
func set_modes(all: bool) -> void:
	profile.data.extras.phase_device={"version":1,"unlocked_modes":{"thermal":true,"cryo":true,"vacuum":true,"pressure":true} if all else {"thermal":true},"learned_capabilities":{"melting":true,"freezing":true,"condensation":true,"vaporization":true,"sublimation":true,"deposition":true} if all else {"melting":true},"selected_mode":"thermal"}
	profile.changed.emit()
func make_chunk(id: String,region: String,origin: Vector2,height: float) -> Node:
	var chunk=CHUNK.new();chunk.name=id;chunk.chunk_id=id;chunk.subregion_id=region;chunk.ground_origin=origin;chunk.fixture_only=true
	var floor:=PackedVector2Array([Vector2(-300,-220),Vector2(200,-220),Vector2(200,220),Vector2(-300,220)])
	chunk.register_surface(floor,height)
	var ground:=Polygon2D.new();ground.name="FixtureGround";ground.polygon=floor;ground.color=Color("c9d7c1");ground.z_index=-100;ground.position.y=-height;chunk.add_child(ground)
	for p in [Vector2(-190,-100),Vector2(80,110),Vector2(110,-100)]:
		var anchor=ANCHOR.new();anchor.position=p;anchor.elevation=height;chunk.add_child(anchor)
		var tree=load("res://Actors/World/Zone1Asset.tscn").instantiate();anchor.visuals.add_child(tree)
	var provider=PROVIDER.new();provider.name="InteractionProvider";provider.world=world;provider.chunk=chunk;provider.position=Vector2(100,0);chunk.add_child(provider)
	var art:=Polygon2D.new();art.polygon=PackedVector2Array([Vector2(-7,0),Vector2(0,-12),Vector2(7,0),Vector2(0,5)]);art.color=Color("547d80");provider.add_child(art)
	chunk.context_provider=provider;chunk.checkpoint_provider=provider
	chunk.quests=[{"text":"Walk through the fixture seam","state":"active"},{"text":"Use approved controls","state":"pending"},{"text":"Retain one player and HUD","state":"pending"},{"text":"Full tasks remain in Pause","state":"pending"}]
	chunk.tutorial="Adapter fixture · move, select a learned mode, hold Fire. Not campaign geography."
	return chunk
func cross() -> void:
	world.activate("Z1L2" if world.active_subregion_id=="Z1L1" else "Z1L1",Vector2(1300,1000) if world.active_subregion_id=="Z1L1" else Vector2(1100,1000))
func run() -> void:
	manual="--manual" in OS.get_cmdline_user_args();output=ProjectSettings.globalize_path("res://../evidence")
	profile=root.get_node("PlayerSave");extent(Vector2i(1280,720))
	change_scene_to_packed(WORLD);await scene_changed;world=current_scene;world.development_preview=true
	west=make_chunk("WestFixture","Z1L1",Vector2(1000,1000),0);east=make_chunk("EastFixture","Z1L2",Vector2(1500,1000),20)
	check(world.mount_chunk(west) and world.mount_chunk(east),"two explicit fixture chunks mount")
	check(world.activate("Z1L1",Vector2(1100,1000)),"activate fixture without campaign registration")
	await process_frame;await physics_frame;world.input_adapter.refresh()
	check(world.player.controls_allowed(),"shared campaign actor controls bind to world host")
	check(world.input_adapter.emitter.available(),"actual emitter binds isolated profile and shared player")
	check(world.hud.preview_input,"single approved HUD touch router enabled")
	await capture("desktop")
	# Further regression assertions below intentionally exercise real nodes/providers.
	await checks_runtime()
	if manual:
		var driver:=Driver.new();driver.review=self;driver.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(driver)
		print("MANUAL:1desktop 2phone 3carry 4locks 5four modes 6cross fixture; WASD/Shift/Space/F/E/G/Esc. Fixture only; no profile writes.")
	else:finish()
func checks_runtime() -> void:
	var player=world.player;var hud=world.hud;var adapter=world.input_adapter
	var player_id: int=player.get_instance_id();var hud_id: int=hud.get_instance_id();var camera_id: int=player.get_node("Camera2D").get_instance_id()
	for i in range(8):
		cross();await physics_frame
		check(player.get_instance_id()==player_id and hud.get_instance_id()==hud_id and player.get_node("Camera2D").get_instance_id()==camera_id,"persistent actor/HUD/camera crossing "+str(i))
	check(player.animated_sprite.scale.is_equal_approx(Vector2.ONE*.2923077),"original character scale preserved")
	check(player.get_node("Camera2D").zoom==Vector2.ONE*1.55,"camera zoom retained")
	check(player.get_node("Camera2D").limit_right==21000 and player.get_node("Camera2D").limit_bottom==10000,"shared camera uses accepted world envelope")
	var anchor=ANCHOR.new();anchor.position=Vector2(40,80);anchor.elevation=20;world.get_node("GroundSort").add_child(anchor)
	check(anchor.position==Vector2(40,80) and anchor.visuals.position==Vector2(0,-20) and anchor.scale==Vector2.ONE,"ground anchor separates elevation offset from sort/collision position")
	anchor.elevation=NAN;check(anchor.elevation==20,"invalid elevation cannot poison visual transforms");anchor.queue_free()
	check(world.get_node("GroundSort").y_sort_enabled and west.y_sort_enabled and east.y_sort_enabled,"one ground sorting plane across nested chunks")
	check(world.valid_landing(Vector2(1200,1000)),"full foot supported across chunk seam")
	check(not world.valid_landing(Vector2(1698,1000)),"foot cannot overhang outer support")
	check(not world.activate("Z1L3",Vector2(1300,1000)),"unmounted future area cannot activate")
	check(not world.activate("Z1L2",Vector2(1000,1000)),"activation anchor must belong to chosen chunk")
	check(not world.unmount_chunk(west.chunk_id),"active chunk cannot unload")
	check(world.unmount_chunk(east.chunk_id),"inactive chunk can unload")
	check(player.get_instance_id()==player_id and hud.get_instance_id()==hud_id,"unload preserves player and HUD")
	east=make_chunk("EastFixtureReload","Z1L2",Vector2(1500,1000),20);check(world.mount_chunk(east),"reload fixture chunk")
	var annex=make_chunk("AnnexFixture","Z1L1",Vector2(500,1000),0)
	check(world.mount_chunk(annex),"second streamed chunk of same subregion mounts")
	world.activate("Z1L1",Vector2(720,1000));adapter.refresh()
	hud.route_touch(7,hud.rects.joystick.get_center()-Vector2(30,0),true)
	for step in range(28):await physics_frame
	check(player.position.x<700 and world.active_chunk()==annex and hud.pointers.has(7) and player.touch_movement.x<0,"walking seam changes chunk owner without canceling movement")
	check(player.get_instance_id()==player_id and hud.get_instance_id()==hud_id,"walking seam preserves actual actor/HUD instances")
	hud.route_touch(7,Vector2.ZERO,false);world.activate("Z1L1",Vector2(1100,1000));adapter.refresh()
	var start: Vector2=player.position
	hud.route_touch(11,hud.rects.joystick.get_center()+Vector2(30,0),true)
	hud.route_touch(22,hud.rects.run.get_center(),true)
	hud.route_touch(33,hud.rects.fire.get_center(),true)
	check(hud.pointers.size()==3 and player.touch_sprinting and player.touch_movement.x>0 and adapter.emitter.held,"independent move/run/fire touch IDs")
	for step in range(24):await physics_frame
	check(player.position.x>start.x+10,"joystick moves actual shared actor")
	check(player.device_rig.phase in ["fire_start","fire_loop"],"Fire drives actual device rig")
	profile.data.player_name="Lin";world.hp=7;world.warmth=54;adapter.refresh()
	check(hud.labels.name.text=="Lin" and hud.labels.hp.text=="7/10" and hud.labels.warmth.text.contains("54"),"actual model updates dynamic name,HP,Warmth")
	check(hud.pointers.has(11) and hud.pointers.has(22) and hud.pointers.has(33),"ordinary status refresh preserves independent held touches")
	world.hp=10;world.warmth=100;adapter.refresh()
	hud.route_touch(11,Vector2.ZERO,false)
	check(player.touch_movement.is_zero_approx() and hud.pointers.has(22) and hud.pointers.has(33),"movement release preserves other fingers")
	hud.route_touch(22,Vector2.ZERO,false,true);hud.route_touch(33,Vector2.ZERO,false,true)
	check(not player.touch_sprinting and not adapter.emitter.held,"canceled run/fire release underlying actions")
	world.activate("Z1L1",Vector2(1100,1000));adapter.refresh()
	for pair in [[91,"joystick"],[92,"run"]]:
		var press:=InputEventScreenTouch.new();press.index=pair[0];press.position=hud.rects[pair[1]].get_center()+(Vector2(30,0) if pair[1]=="joystick" else Vector2.ZERO);press.pressed=true;Input.parse_input_event(press)
		Input.flush_buffered_events();await process_frame
	check(hud.pointers.has(91) and hud.pointers.has(92) and player.touch_sprinting,"raw screen events reach sole bound HUD input router")
	for id in [91,92]:
		var release:=InputEventScreenTouch.new();release.index=id;release.pressed=false;release.canceled=true;Input.parse_input_event(release)
		Input.flush_buffered_events();await process_frame
	check(not hud.pointers.has(91) and not hud.pointers.has(92) and player.touch_movement.is_zero_approx() and not player.touch_sprinting,"raw canceled touches stop movement/run")
	await collision_checks()
	var writes: int=profile.selection_writes
	tap("pressure")
	check(profile.selected_device_mode()=="thermal" and profile.selection_writes==writes,"locked mode cannot select or save")
	adapter.select_mode("plasma");check(profile.selected_device_mode()=="thermal" and profile.selection_writes==writes,"unknown fifth power rejected")
	# Use the actual target adapter and rules; selecting Thermal cannot grant vaporization.
	var target=load("res://Scripts/World/phase_device_target_2d.gd").new();west.add_child(target)
	check(target.configure({"id":"fixture_boiling","zone":"melting_and_freezing","level":1,"material":"water","process":"boiling","required_exposure":99.0,"max_range":100.0,"allowed_modes":["thermal"],"required_flags":[]},world,profile),"fixture target uses existing scientific contract")
	target.global_position=player.device_muzzle().global_position+Vector2.RIGHT*40
	check(target.bind_live_context(func():return {"material":"water","state":"liquid","amount":1.0,"phase_region":"boiling_bulk","heat_flow":"in"},func():return {}),"fixture target binds read-only sample conditions")
	check(target.targeting_reason(world,profile)=="locked_capability","Thermal mode does not grant boiling/vaporization capability")
	hud.route_touch(39,hud.rects.fire.get_center(),true)
	for step in range(8):await physics_frame
	check(is_zero_approx(target.exposure()),"Fire cannot advance a locked scientific capability")
	hud.route_touch(39,Vector2.ZERO,false);target.queue_free();await process_frame
	set_modes(true);writes=profile.selection_writes;tap("cryo")
	check(profile.selected_device_mode()=="cryo" and profile.selection_writes==writes+1,"unlocked mode saves through existing PlayerSave transaction")
	profile.fail_save=true;tap("vacuum");profile.fail_save=false
	check(profile.selected_device_mode()=="cryo" and hud.device.selected_mode=="cryo" and adapter.feedback=="Fixture save failed.","failed selection save rolls back committed HUD/profile state")
	var selection: String=profile.selected_device_mode();writes=profile.selection_writes
	hud.route_touch(41,hud.rects.pressure.get_center(),true);tap("selected",42);hud.route_touch(41,hud.rects.pressure.get_center(),false)
	check(profile.selected_device_mode()==selection and profile.selection_writes==writes,"center cancels pending outer mode touch; no fifth mode")
	tap("vacuum",43,true);check(profile.selected_device_mode()==selection,"canceled selection cannot commit")
	player.carrying=true;adapter.refresh();tap("jump");hud.route_touch(51,hud.rects.fire.get_center(),true)
	check(player.jump_elapsed<0 and not adapter.emitter.held,"carrying blocks Jump and Fire")
	player.carrying=false;adapter.refresh();hud.route_drag(51,hud.rects.fire.get_center())
	check(not adapter.emitter.held,"blocked finger never auto-rearms after carry release")
	hud.route_touch(51,Vector2.ZERO,false);tap("jump")
	check(player.jump_elapsed>=0,"Jump invokes existing grounded jump")
	adapter.stop_all("test_recovery",true);check(player.jump_elapsed<0,"interruption returns jump to grounded origin")
	world.activate("Z1L1",Vector2(1100,1000));adapter.refresh()
	var provider=west.context_provider
	tap("context");check(provider.uses==1,"context release invokes active provider after live eligibility")
	hud.route_touch(61,hud.rects.context.get_center(),true);provider.key="fixture.use.2";adapter.refresh();hud.route_touch(61,hud.rects.context.get_center(),false)
	check(provider.uses==1,"stale context press cannot activate replacement identity")
	hud.route_touch(62,hud.rects.context.get_center(),true)
	var replacement=PROVIDER.new();replacement.world=world;replacement.chunk=west;replacement.position=Vector2(100,0);replacement.key=provider.key;west.add_child(replacement);west.context_provider=replacement;adapter.refresh()
	hud.route_touch(62,hud.rects.context.get_center(),false)
	check(replacement.uses==0,"same string key on different target cannot inherit a held context touch")
	west.context_provider=provider;replacement.queue_free();adapter.refresh()
	provider.enabled=false;adapter.refresh();tap("context");check(provider.uses==1,"domain predicate disables context")
	provider.enabled=true;adapter.refresh()
	hud.route_touch(70,hud.rects.joystick.get_center()+Vector2(30,0),true);hud.route_touch(71,hud.rects.fire.get_center(),true)
	adapter.open_panel("pause")
	check(paused and player.touch_movement.is_zero_approx() and not adapter.emitter.held and hud.pointers.is_empty(),"Pause clears all held inputs")
	await capture("pause")
	adapter.open_panel("objectives");check(world.panels.model.rows.size()==4,"full objective list available beyond compact HUD overflow")
	adapter.open_panel("travel");check(world.panels.model.rows.size()==2 and not world.panels.model.rows[1].enabled,"Pause checkpoint map retains attuned/unattuned distinction")
	check(world.panels.body.get_child(1).has_signal("checkpoint_requested"),"Pause contains rendered local checkpoint map")
	await capture("checkpoint-map")
	check(not adapter._travel("C1") and provider.travels==0,"unattuned checkpoint travel rejected")
	var checkpoint_map: Control=world.panels.body.get_child(1)
	checkpoint_map.pins[0].pressed.emit()
	check(not paused and provider.travels==1,"actual checkpoint-map pin executes attuned travel and resumes")
	checkpoint_map.pins[0].pressed.emit();check(provider.travels==1,"closed checkpoint map cannot replay a stale travel callback")
	profile.data.extras.guides_unlocked={"fixture":{"zone":"melting_and_freezing","level":1,"object":"marker","topic":"map"}}
	adapter.open_panel("guides");check(world.panels.visible and world.panels.title.text=="Guides","Guides opens existing shared support shell")
	check(world.panels.model.rows.size()==1,"Guides lists actual discovered references")
	var guide_key: String=profile.guide_records().keys()[0]
	var before_guide: Dictionary=profile.data.duplicate(true);var before_writes: int=profile.selection_writes
	adapter._open_guide(guide_key);check(world.panels.model.body.contains("Pause") and world.panels.model.body.contains("Checkpoint map"),"retained map guidance adapted to approved Pause entry")
	check(is_instance_valid(adapter.guide_preview) and adapter.guide_preview.world.demonstration_mode,"actual retained demonstration opens as disposable copy")
	for step in range(8):await process_frame
	check(profile.data==before_guide and profile.selection_writes==before_writes,"viewing demonstration grants no progress or profile write")
	adapter.guide_preview.replay();adapter.guide_preview.toggle_playback()
	await capture("guides")
	adapter.close_panel();check(not paused and not adapter.emitter.held,"closing modal cannot resume held Fire")
	world.activate("Z1L1",Vector2(1100,1000));adapter.refresh();hud.route_touch(80,hud.rects.fire.get_center(),true)
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);adapter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not adapter.emitter.held and player.touch_movement.is_zero_approx() and not adapter.allowed(),"focus loss clears and blocks world controls")
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);adapter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);adapter.refresh()
	check(not adapter.emitter.held,"focus return requires a fresh press")
	root.get_node("SceneTransition").busy=true;adapter._process(.1)
	check(not adapter.allowed() and player.touch_movement.is_zero_approx(),"scene transition blocks movement and actions")
	root.get_node("SceneTransition").busy=false
	world._notification(Node.NOTIFICATION_APPLICATION_PAUSED);adapter._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not adapter.allowed() and not adapter.emitter.held,"background suspension stops controls")
	world._notification(Node.NOTIFICATION_APPLICATION_RESUMED);adapter._notification(Node.NOTIFICATION_APPLICATION_RESUMED);adapter.refresh()
	tap("jump");adapter._was_allowed=true;world.dead=true;adapter._process(.1)
	check(player.jump_elapsed<0 and not adapter.allowed(),"death gate cancels jump back to grounded origin")
	world.dead=false;adapter.refresh();hud.hide();adapter._process(.1)
	check(not player.controls_allowed() and not adapter.allowed(),"hidden HUD cannot leave keyboard/touch gameplay active")
	hud.show();adapter.refresh()
	for row in REGISTRY.definitions():
		var definition:=REGISTRY.definition(row.id)
		check(not definition.world_ready and not REGISTRY.can_enter(profile,row.id),"world readiness closed "+row.id)
		var p:=Vector2(121.25,-19.5)
		check(REGISTRY.ground_to_local(row.id,REGISTRY.local_to_ground(row.id,p)).is_equal_approx(p),"translation round trip "+row.id)
	check(REGISTRY.legacy_scene("Z1L1")=="res://Zone_1/Levels/wrld_lvl_1.tscn" and REGISTRY.legacy_scene("Z1L2")=="res://Zone_1/Levels/wrld_lvl_2.tscn","two existing legacy scenes remain recoverable")
	check(REGISTRY.legacy_scene("Z1L3").is_empty(),"unfinished legacy scene not exposed as ready")
	check(not AUTHORITY.matches(world,world.SAVE_ZONE,world.SAVE_LEVEL,profile),"real authority rejects disposable world fixtures")
	world.development_preview=false
	check(not AUTHORITY.matches(world,world.SAVE_ZONE,world.SAVE_LEVEL,profile),"removing fixture flag cannot make unfinished world ready")
	world.development_preview=true
	world.activate("Z1L2",Vector2(1300,1000));await process_frame;await physics_frame
	check(is_equal_approx(player._floor_height,20) and player.position.y==1000,"elevation changes visual support without changing ground Y")
	check(REGISTRY.projected(Vector2(1300,1000),20)==Vector2(1300,980),"visual elevation subtracts Y once; ground sort remains unchanged")
	await capture("elevation")
	await sorting_checks()
	extent(Vector2i(640,360));await process_frame;adapter.refresh();await capture("phone")
	check(hud.supported and hud.visible_quest_count==2,"phone HUD retains compact overflow rules")
	check(hud.controls.size()==11 and not hud.controls.has("map"),"approved controls only; no Map HUD button")
	for id in ["thermal","cryo","vacuum","pressure","selected"]:check(hud.controls.has(id),"five-slot control "+id)
	check(profile.data.completed.is_empty(),"fixture traversal and inputs award no campaign progress")
	extent(Vector2i(1280,720));world.activate("Z1L1",Vector2(1100,1000));set_modes(false);adapter.refresh()
func sorting_checks() -> void:
	world.activate("Z1L1",Vector2(1100,1000))
	var red:=Node2D.new();red.position=Vector2(900,1160);world.get_node("GroundSort").add_child(red)
	var blue:=Node2D.new();east.add_child(blue);blue.global_position=Vector2(900,1170)
	for pair in [[red,Color.RED],[blue,Color.BLUE]]:
		var shape:=Polygon2D.new();shape.polygon=PackedVector2Array([Vector2(-20,-80),Vector2(20,-80),Vector2(20,0),Vector2(-20,0)]);shape.color=pair[1];pair[0].add_child(shape)
	await capture("sorting-front")
	var screen: Vector2=world.get_canvas_transform()*Vector2(900,1130)
	var pixel:=root.get_texture().get_image().get_pixelv(Vector2i(screen))
	check(pixel.b>.9 and pixel.r<.1,"rendered nested-chunk prop sorts in front by ground Y")
	red.position.y=1180;await capture("sorting-back")
	pixel=root.get_texture().get_image().get_pixelv(Vector2i(screen))
	check(pixel.r>.9 and pixel.b<.1,"rendered direct actor layer sorts in front after ground crossing")
	red.queue_free();blue.queue_free();await process_frame
func collision_checks() -> void:
	world.activate("Z1L1",Vector2(1100,1000));world.input_adapter.refresh()
	var wall:=StaticBody2D.new();wall.position=Vector2(1140,1000);wall.collision_layer=1;wall.collision_mask=4
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(8,80);collider.shape=shape;wall.add_child(collider);world.get_node("GroundSort").add_child(wall)
	await physics_frame
	world.player.set_touch_movement(Vector2.RIGHT)
	for step in range(30):await physics_frame
	check(world.player.position.x>1110 and world.player.position.x<1130,"shared actor retains real solid-layer collision")
	world.input_adapter.stop_all("wall_test");wall.queue_free();await process_frame
	world.activate("Z1L1",Vector2(1100,1000));world.input_adapter.refresh()
func finish() -> void:
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"assertions":checks,"captures":captures,"scope":"real shared player/HUD/emitter with isolated in-memory profile and fixture geometry; not campaign readiness or Android certification"}
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("R3 015 REVIEW ",result.status," / ",checks.size()," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
