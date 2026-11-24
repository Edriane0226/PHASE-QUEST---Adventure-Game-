extends Node
const WS=preload("res://Scripts/Content/world_save.gd")
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var profile:=get_node("/root/PlayerSave")
	if event.physical_keycode==KEY_F1:get_window().size=Vector2i(1280,720)
	elif event.physical_keycode==KEY_F2:get_window().size=Vector2i(640,360)
	elif event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
		var n: int=event.physical_keycode-KEY_1+1;var row:=WS.REGISTRY.definition("Z%dL1"%n)
		profile.readiness_probe=true
		profile.data={"version":1,"player_name":"Manual menu fixture","completed":{},"active_run":{"zone":row.zone_id,"level":1,"state":{},"attempt_id":"manual-zone"+str(n)},"extras":{}}
		for r in WS.REGISTRY.definitions():profile.data.completed[r.completion_key]=true
		profile.save_profile();get_tree().change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn")
	elif event.physical_keycode==KEY_R:
		profile.readiness_probe=false;profile.data={"version":1,"player_name":"","completed":{},"active_run":{},"extras":{}};profile.save_profile();get_tree().change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn")
