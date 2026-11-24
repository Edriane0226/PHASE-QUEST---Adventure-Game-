extends Node
## Developer review controls only; excluded from shipping resources.
var review: SceneTree
var overview:=false
var navigating:=false
var camera_home:=Vector2.ZERO
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var world: Node=review.world
	if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_6:
		if overview:toggle_overview()
		var index: int=event.physical_keycode-KEY_1;var r: Dictionary=world.geometry.data.regions[index]
		world.set_fixture_permissions(6,true);review.planner.set_prefix(6);review.planner.refresh_gate_cells()
		world.activate(r.id,review.planner.safe_at(world.geometry.v(r.entry)));print("INSPECT ",r.name)
	elif event.physical_keycode==KEY_F1:extent(Vector2i(1280,720))
	elif event.physical_keycode==KEY_F2:extent(Vector2i(640,360))
	elif event.physical_keycode in [KEY_B,KEY_L]:
		if overview:toggle_overview()
		var index:=0 if event.physical_keycode==KEY_B else 1
		var reserve: Dictionary=world.geometry.data.travel_reserves[index]
		world.set_fixture_permissions(6,true);review.planner.set_prefix(6)
		world.activate("Z2L1" if index==0 else "Z2L6",world.geometry.v(reserve.local_anchor))
		print("GEOGRAPHIC RESERVE ",reserve.id,"; travel awaits later integration")
	elif event.physical_keycode==KEY_C:world.player.carrying=not world.player.carrying;world.input_adapter.refresh()
	elif event.physical_keycode==KEY_7:world.set_fixture_permissions(1,false);review.planner.set_prefix(1);print("ONLY LANDING OPEN; later geometry blocked. No campaign progress changed")
	elif event.physical_keycode==KEY_8:world.set_fixture_permissions(6,true);review.planner.set_prefix(6);print("ALL SIX AREAS OPEN IN ISOLATED FIXTURE ONLY")
	elif event.physical_keycode==KEY_M:toggle_overview()
	elif event.physical_keycode==KEY_N and not navigating:next_route()
	else:return
	get_viewport().set_input_as_handled()
func extent(size: Vector2i) -> void:
	get_tree().root.size=size;get_tree().root.content_scale_size=size
func toggle_overview() -> void:
	var world: Node=review.world;var camera: Camera2D=world.player.get_node("Camera2D")
	overview=not overview;world.input_adapter.stop_all("overview",true)
	if overview:
		camera_home=camera.position;camera.top_level=true;camera.position=Vector2(11600,4900);camera.zoom=Vector2.ONE*.072;world.hud.hide();world.player.set_physics_process(false)
	else:camera.top_level=false;camera.position=camera_home;camera.zoom=Vector2.ONE*1.55;world.hud.show();world.player.set_physics_process(true);world.input_adapter.refresh()
func next_route() -> void:
	if overview:return
	var world: Node=review.world;var index:=int(world.active_subregion_id.right(1))-1
	if index>=5:print("Engine is final Zone2 shell; lift travel awaits 019/036.");return
	navigating=true;world.player.carrying=false;world.set_fixture_permissions(6,true);review.planner.set_prefix(6);review.planner.refresh_gate_cells()
	var r: Dictionary=world.geometry.data.regions[index];var dest: Dictionary=world.geometry.data.regions[index+1]
	world.activate(r.id,review.planner.safe_at(world.geometry.v(r.exit)))
	var steps: Array=review.planner.plan(world.player.position,world.geometry.v(dest.entry))
	await review.walk_steps(steps,"manual "+r.id+" to "+dest.id)
	navigating=false
