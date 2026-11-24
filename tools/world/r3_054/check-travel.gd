extends SceneTree
## Uses ordinary Continue and live HUD gestures for both directions.
const ENTRY = preload("res://tools/world/r3_052/title_entry.gd")
const WALK = preload("res://tools/world/r3_054/walking.gd")
const TOUCH = preload("res://tools/world/r3_030/touch_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ",label)
	return ok

func run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	var world := await ENTRY.open(self)
	if check(is_instance_valid(world),"ordinary title opened the saved campaign"):
		await exercise(world)
	print("TRAVEL054 ","PASS" if failures == 0 else "FAIL"," ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)

func exercise(world: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var profile := root.get_node("PlayerSave")
	var earned: Dictionary = profile.data.completed.duplicate(true)
	var modes: Dictionary = profile.device_state().learned_capabilities.duplicate(true)
	var original: String = world.active_subregion_id
	var actor: Node = world.player
	var hud: Node = world.hud
	var camera: Node = actor.get_node("Camera2D")
	check(profile.save_path == "user://phasequest_profile.save","ordinary standard profile")
	var touch := TOUCH.new(self,world)
	if args.has("--trail"):
		var neighbor := "Z2L2"
		if not check(original == "Z2L3" and await WALK.cross(self,world,neighbor),"walk Dewglass west to Orchard"):return
		if not check(await WALK.cross(self,world,original),"walk Orchard east to Dewglass"):return
	elif args.has("--finale"):
		if not check(original == "Z3L6" and profile.total_stars() == 18 and world.player_controls_allowed(),"completed Core remains explorable"):return
		var moved: bool = await touch.go(world.checkpoint_anchor(original,"C0"))
		check(moved and touch.walked > 1.0,"walk through Core after the saved finale")
	else:
		var connection := "Z1L6--Z2L1" if args.has("--boat") else "Z2L6--Z3L1"
		var route: Dictionary = world.connection(connection)
		if not check(original == route.destination and await WALK.board(self,world,connection,true),"walk to return Hand action "+connection):return
		await touch.wait(2.2)
		if not check(world.active_subregion_id == route.source and await WALK.board(self,world,connection),"return arrival and walk to forward Hand action"):return
		await touch.wait(2.2)
		check(world.active_subregion_id == original,"return to original zone through the same connection")
	check(world.player == actor and world.hud == hud and actor.get_node("Camera2D") == camera and current_scene == world,"same campaign, player, camera and HUD")
	check(profile.data.completed == earned and profile.device_state().learned_capabilities == modes,"travel preserves earned stars and learning")
	check(profile.world_record().active_subregion == original,"world resume location follows geographic travel")
	check(world.save_and_menu(),"save from grounded return")
	await scene_changed
