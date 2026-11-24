extends Node
## Developer review controls only; excluded from shipping resources.
var review: SceneTree
var overview:=false
var navigating:=false
var camera_home:=Vector2.ZERO
var chamber_index:=0
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
	elif event.physical_keycode in [KEY_O,KEY_L,KEY_P]:
		if overview:toggle_overview()
		world.set_fixture_permissions(6,true);review.planner.set_prefix(6)
		if event.physical_keycode==KEY_O:
			var choices: Array=world.geometry.data.chambers.filter(func(c):return not c.asset.begins_with("lab_") and c.asset!="glass_boundary" and not c.asset.begins_with("final_exit"))
			var chamber: Dictionary=choices[chamber_index%choices.size()];chamber_index+=1
			world.activate(chamber.subregion,world.geometry.v(chamber.observation));print("SEALED OBSERVATION ",chamber.id)
		elif event.physical_keycode==KEY_L:
			for e in world.geometry.data.equipment:
				if e.group=="exit_scanner":world.activate(e.subregion,world.geometry.v(e.observation));print("SCANNER reserve; no live scan or completion")
		else:
			var platform: Dictionary=world.geometry.data.platforms[0]
			world.activate(platform.subregion,world.geometry.box_of(world.geometry.polygon(platform.polygon)).get_center());print("PERMANENT METAL support; frost is not floor")
	elif event.physical_keycode==KEY_C:world.player.carrying=not world.player.carrying;world.input_adapter.refresh()
	elif event.physical_keycode==KEY_7:world.set_fixture_permissions(1,false);review.planner.set_prefix(1);print("ONLY VANISHING LAB OPEN; later geometry blocked. No campaign progress changed")
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
		camera_home=camera.position;camera.top_level=true;camera.offset=Vector2.ZERO;camera.position=Vector2(16200,4600);camera.zoom=Vector2.ONE*.075;world.hud.hide();world.player.set_physics_process(false)
	else:camera.top_level=false;camera.position=camera_home;camera.zoom=Vector2.ONE*1.55;world.hud.show();world.player.set_physics_process(true);world.input_adapter.refresh()
func next_route() -> void:
	if overview:return
	var world: Node=review.world;var index:=int(world.active_subregion_id.right(1))-1
	if index>=5:print("Core is final campaign region; scanner integration remains 043.");return
	navigating=true;world.player.carrying=false;world.set_fixture_permissions(6,true);review.planner.set_prefix(6);review.planner.refresh_gate_cells()
	var r: Dictionary=world.geometry.data.regions[index];var dest: Dictionary=world.geometry.data.regions[index+1]
	world.activate(r.id,review.planner.safe_at(world.geometry.v(r.exit)))
	var steps: Array=review.planner.plan(world.player.position,world.geometry.v(dest.entry))
	await review.walk_steps(steps,"manual "+r.id+" to "+dest.id)
	navigating=false
