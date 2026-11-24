extends Node
var review: SceneTree
var overview:=false
var navigating:=false
var home:=Vector2.ZERO
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var world: Node=review.world;var profile=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_EQUAL,KEY_KP_ADD:profile.set_completed_prefix(mini(18,profile.data.completed.size()+1));print("FIXTURE completions ",profile.data.completed.size(),"; no real save/reward")
		KEY_MINUS,KEY_KP_SUBTRACT:profile.set_completed_prefix(maxi(0,profile.data.completed.size()-1));print("FIXTURE completions ",profile.data.completed.size())
		KEY_F8:profile.set_completed_prefix(18);print("ISOLATED all-completed inspection fixture; normal profile unchanged")
		KEY_R:profile.set_completed_prefix(0);print("ISOLATED completions reset; independent discovery history retained")
		KEY_1,KEY_2,KEY_3:
			if overview:toggle_overview()
			var id:="Z%dL1"%(event.physical_keycode-KEY_1+1);var r: Dictionary=world.REGISTRY.definition(id)
			if not world.activate(id,Vector2(r.entry[0],r.entry[1])):world.input_adapter.feedback=world.access.missing(id);world.input_adapter.refresh()
		KEY_C:world.player.carrying=not world.player.carrying;world.input_adapter.refresh()
		KEY_M:toggle_overview()
		KEY_F1:extent(Vector2i(1280,720))
		KEY_F2:extent(Vector2i(640,360))
		KEY_B,KEY_L:
			if overview:toggle_overview()
			var c: Dictionary=world.connection("Z1L6--Z2L1" if event.physical_keycode==KEY_B else "Z2L6--Z3L1")
			if not world.activate(c.source,Vector2(c.source_anchor[0],c.source_anchor[1])):world.input_adapter.feedback=world.access.missing(c.source)
			elif not world.access.allowed(c.destination):world.input_adapter.feedback=world.access.missing(c.destination)
			world.input_adapter.refresh()
		KEY_N:
			if not navigating and not overview:next_connection()
		_:return
	get_viewport().set_input_as_handled()
func extent(size: Vector2i) -> void:get_tree().root.size=size;get_tree().root.content_scale_size=size
func toggle_overview() -> void:
	var world: Node=review.world;var camera: Camera2D=world.player.get_node("Camera2D")
	overview=not overview;world.input_adapter.stop_all("overview",true)
	if overview:
		home=camera.position;camera.top_level=true;camera.offset=Vector2.ZERO;camera.position=Vector2(10500,5000);camera.zoom=Vector2.ONE*.057;world.player.set_physics_process(false);world.hud.hide()
	else:camera.top_level=false;camera.position=home;camera.zoom=Vector2.ONE*1.55;world.player.set_physics_process(true);world.hud.show();world.input_adapter.refresh()
func next_connection() -> void:
	var world: Node=review.world
	for c in world.connections:
		if c.source!=world.active_subregion_id:continue
		if not world.access.allowed(c.destination):world.input_adapter.feedback=world.access.missing(c.destination);world.input_adapter.refresh();return
		if c.kind!="walk":world.activate(c.source,Vector2(c.source_anchor[0],c.source_anchor[1]));world.input_adapter.refresh();print("Use geographic ",c.kind," action; no menu");return
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
		for route in data.routes:
			if route.id!=c.id:continue
			var points:=PackedVector2Array()
			for p in route.points:points.append(Vector2(p[0],p[1]))
			if world.player.carrying:world.input_adapter.feedback="Place carried cargo on its local return pad before crossing.";world.input_adapter.refresh();return
			navigating=true;world.activate(c.source,points[0]);await review.walk(points,c.id+" manual");navigating=false;return
	print("Final campaign region; no Zone4 or science grants.")
