extends SceneTree
const ENTRY = preload("title_entry.gd")
const PATH = preload("res://tools/world/r3_030/touch_route.gd")
const REGISTRY = preload("res://Scripts/Content/world_subregions.gd")
const BOAT := "Z1L6--Z2L1"
const LIFT := "Z2L6--Z3L1"
var checks := 0
var failures := 0
var world: Node2D
var profile: Node
var counts := {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:failures += 1
	print("PASS " if value else "FAIL ",label)
	return value

func run() -> void:
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	profile=root.get_node("PlayerSave")
	var args := OS.get_cmdline_user_args()
	if args.has("--layout"):
		layout()
	else:
		var fresh := not args.has("--earned")
		var start := Time.get_ticks_msec()
		world=await ENTRY.open(self,fresh)
		if world==null:return
		print("ENTRY052 milliseconds=",Time.get_ticks_msec()-start)
		if fresh:await locked()
		else:await earned()
	print("CAMPAIGN052 ", "PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," districts=",counts)
	quit(0 if failures==0 else 1)

func layout() -> void:
	var packed := load(ENTRY.CAMPAIGN) as PackedScene
	var scene := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var zones := scene.get_node("GroundSort")
	for zone in range(1,4):
		check(zones.has_node("Zone%d" % zone),"zone group %d" % zone)
		var professor := zones.get_node("Zone%d/SharedProfessorZ%d/Visuals/CastActor" % [zone,zone])
		check(professor.cast_id=="professor_z%d" % zone,"original Professor %d" % zone)
	for id in REGISTRY.CAMPAIGN_DISTRICTS:
		var district := scene.get_node_or_null(REGISTRY.CAMPAIGN_DISTRICTS[id])
		if not check(district!=null and district.owner==scene and district.scene_file_path.is_empty(),"inline district "+id):continue
		var layout_node := district.get_node("Layout")
		check(layout_node.get_node("Floors").get_child_count()>0 and layout_node.get_node("Boundary").owner==scene,"editable terrain and boundary "+id)
		check(layout_node.get_node("Stations").get_child_count()>0 and layout_node.get_node("Checkpoints/C0").owner==scene,"editable stations and checkpoints "+id)
		check(district.get_node("Collision").get_child_count()>0,"editable collision "+id)
		if id.ends_with("L6"):
			var finn := district.get_node("Scenery/FinnCapstone/Visuals/CastActor")
			check(finn.cast_id=="finn","original Finn capstone "+id)
	var connections := scene.get_node("Connections")
	check(connections.get_child_count()==17,"17 serialized crossings")
	for connection in connections.get_children():
		check(connection is Line2D and connection.owner==scene and connection.has_node("Source") and connection.has_node("Destination"),"editable route "+str(connection.name))
	for dependency: String in ResourceLoader.get_dependencies(ENTRY.CAMPAIGN):
		if ".tscn" in dependency:
			check("res://Actors/" in dependency or "res://UI/" in dependency,"allowed component scene "+dependency)
		check(not "World/Data/" in dependency,"no external layout resource")
	var floor_node: Polygon2D = scene.get_node(REGISTRY.CAMPAIGN_DISTRICTS.Z3L6).get_node("Layout/Floors").get_child(0)
	var points := floor_node.polygon
	points[0] += Vector2(2,0)
	floor_node.polygon=points
	var edited := PackedScene.new()
	check(edited.pack(scene)==OK,"repack external editor-style change")
	var reopened := edited.instantiate()
	check(reopened.get_node(REGISTRY.CAMPAIGN_DISTRICTS.Z3L6).get_node("Layout/Floors").get_child(0).polygon==points,"edited Core polygon survives reopen")
	reopened.free()
	scene.free()

func locked() -> void:
	check(store_has_real_authority(),"real PlayerSave and mounted provider")
	check(world.access.allowed("Z1L1") and not world.access.allowed("Z1L2") and not world.access.allowed("Z2L1") and not world.access.allowed("Z3L1"),"only Garden initially authorized")
	check(world.nearby_districts.Z1L1 and not world.nearby_districts.Z3L6,"far Core remains inactive")
	var original_hash := FileAccess.get_sha256(profile.save_path)
	profile.set_meta("r3_015_fixture",true)
	profile.set_meta("r3_019_permissions",true)
	profile.set_meta("r3_036_skybridge",true)
	world.access.refresh()
	check(not world.fixture_session() and not world.access.allowed("Z2L1") and not world.can_transit(LIFT),"fixture metadata cannot enable access or travel")
	var mill: Vector2 = world.checkpoint_anchor("Z1L2","C0")
	check(not world.activate("Z1L2",mill) and not profile.enter_world_subregion(world,"Z1L2"),"unearned direct activation and save rejected")
	check(not world.unmount_chunk("Z1L2.shell") and world.has_mounted_region("Z1L2"),"installed authored district cannot be removed by a shell helper")
	check(not world.world_contact_allowed(world.player.position,mill) and world.permissions.Z1L2.all(func(body):return body.collision_layer==8),"physical and Fire barriers remain")
	var locked_plots := ["Z1L2","Z2L1","Z3L1"]
	for id in locked_plots:
		var polygon: PackedVector2Array = world.access.polygons[id]
		var center: Vector2 = world.district_bounds[id].get_center()
		var blocked := 0
		for point in polygon:
			var inside := point.lerp(center,0.08)
			if world.access.region_at(inside)==id and not world.access.point_allowed(inside):blocked += 1
		check(blocked>=3,"alternate approaches remain forbidden "+id)
	check(not profile.select_device_mode("cryo") and not profile.select_device_mode("vacuum") and not profile.select_device_mode("pressure"),"mode grants rejected before learning")
	check(FileAccess.get_sha256(profile.save_path)==original_hash,"fixture attempts preserve staged save")
	await process_frame

func store_has_real_authority() -> bool:
	return profile.get_script().resource_path=="res://Scripts/Autoload/player_save.gd" and world.learning_provider().active() and profile.world_navigation_source(world,world.active_subregion_id)

func place(id: String, at := Vector2(INF,INF)) -> bool:
	world.input_adapter.close_panel()
	var target: Vector2 = world.checkpoint_anchor(id,"C0") if not at.is_finite() else at
	return world.activate(id,target) and profile.enter_world_subregion(world,id)

func identity() -> Array:
	return [world.get_instance_id(),world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]

func earned() -> void:
	if not check(profile.total_stars()==18 and store_has_real_authority(),"cold title loads genuine earned 18-star save"):return
	var retained := identity()
	var attempts: Dictionary = profile.world_record().attempts
	var optionals := 0
	for id in REGISTRY.CAMPAIGN_DISTRICTS:
		if not check(place(id),"real authored checkpoint and save "+id):continue
		var provider: Node = world.learning_provider()
		var old_attempt: Dictionary = attempts[id].attempt
		check(provider.active() and profile.campaign_source(world,provider.world.SAVE_ZONE,provider.world.SAVE_LEVEL)
			and profile.data.active_run.attempt_id==old_attempt.attempt_id,"active provider and retained attempt "+id)
		check(profile.data.active_run.state==old_attempt.state and not provider.world_checkpoints().is_empty(),"apparatus, cargo, evidence and checkpoints restored "+id)
		check(identity()==retained,"same root, player, HUD and camera "+id)
		if is_instance_valid(world.active_chunk().optional_activity):optionals += 1
		counts[id]=profile.data.active_run.state.get("device_outcomes",{}).size()
	check(optionals==8,"eight optional stations mounted")
	for mode in ["thermal","cryo","vacuum","pressure"]:
		world.input_adapter.close_panel()
		var touch := PATH.new(self,world)
		touch.tap(world.hud.rects[mode].get_center())
		await touch.ticks()
		check(profile.selected_device_mode()==mode,"real HUD selects earned "+mode)
	for room in world.room_cutaway.rooms:
		await inspect_room(room, retained)
	await walk_connection("Z2L2","Z2L3",retained)
	await walk_connection("Z2L3","Z2L2",retained)
	await ride(LIFT,true,retained)
	await ride(LIFT,false,retained)
	await ride(BOAT,true,retained)
	await ride(BOAT,false,retained)
	check(profile.total_stars()==18,"travel and repeated visits cannot duplicate stars")
	check(profile.world_record().attempts.size()==18,"all eighteen saved attempts retained")
	check(not ResourceLoader.has_cached("res://World/Navigation/ConnectedWorld.tscn") and not ResourceLoader.has_cached("res://World/Zone3/Z3L1Shell.tscn"),"no legacy map scenes loaded")

func walk_connection(from: String, to: String, retained: Array) -> void:
	var handoff := load("res://tools/world/r3_052/walk_review.gd")
	var touch := PATH.new(self,world)
	var direction := from+"--"+to
	if not check(await handoff.walk(touch,from,to),"HUD backtracking "+direction):return
	check(profile.world_record().active_subregion==to and identity()==retained,"walking writes destination in the same scene "+direction)

func ride(id: String, reverse: bool, retained: Array) -> void:
	var route: Dictionary = world.connection(id)
	var from: String = route.destination if reverse else route.source
	var to: String = route.source if reverse else route.destination
	var xy: Array = route.destination_anchor if reverse else route.source_anchor
	if not check(place(from,Vector2(xy[0],xy[1])),"supported departure "+from):return
	var touch := PATH.new(self,world)
	await touch.ticks()
	world.input_adapter.refresh()
	var context: Dictionary = world.active_chunk().context_record()
	if not check(context.get("enabled",false) and world.can_transit(id,reverse),"earned Hand transport "+id+" from "+from):return
	touch.tap(world.hud.controls.context.get_global_rect().get_center())
	await touch.wait(2.3)
	check(world.active_subregion_id==to and profile.world_record().active_subregion==to and identity()==retained,"real saved arrival and same actor "+to)

func inspect_room(room: Node2D, retained: Array) -> void:
	var inside: Vector2 = room.point(room.size_cubes*.5)
	if not check(place(room.subregion_id,inside),"supported live room interior "+room.room_id):return
	for frame in 3:await process_frame
	check(room.occupied and room.pieces.any(func(piece):return not piece.visible and piece.get_meta("cutaway"))
		and room.pieces.any(func(piece):return piece.visible and not piece.get_meta("cutaway")),"roof cuts away and rear faces remain "+room.room_id)
	var wall_point: Vector2 = (room.walls[0][0]+room.walls[0][1]+room.walls[0][2]+room.walls[0][3])*.25
	check(room.bodies.all(func(body):return body.collision_layer==1) and
		not world.world_contact_allowed(inside,wall_point),"hidden wall still blocks Fire and movement "+room.room_id)
	check(place(room.subregion_id),"leave room to local grounded checkpoint "+room.room_id)
	await process_frame
	check(not room.occupied and identity()==retained,"room exterior restored in same scene "+room.room_id)
