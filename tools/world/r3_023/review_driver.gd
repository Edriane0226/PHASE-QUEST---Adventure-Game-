extends Node
const FIXTURE=preload("res://fixtures.gd")
var world: Node
var provider: Node
var room: Node
func bind(host: Node) -> bool:
	process_mode=Node.PROCESS_MODE_ALWAYS;world=host
	var store=get_node("/root/PlayerSave");store.adapter_tests=true
	if not store.world_record().get("attempts",{}).has("Z1L5"):store.set_completed_prefix(4)
	room=world.room_cutaway.rooms.filter(func(r):return r.subregion_id=="Z1L5")[0]
	var at: Vector2=world.player.position if world.active_subregion_id=="Z1L5" else room.point(Vector2(6.8,4.2))
	if not world.activate("Z1L5",at) or not store.enter_world_subregion(world,"Z1L5"):return false
	provider=FIXTURE.mount(world,FIXTURE.definition(room.point(Vector2(1,1))))
	world.active_chunk().quests=[{"text":"Shared adapter review","state":"active"},{"text":"Isolated worksite fixture","state":"active"}]
	return provider!=null and provider.active()
func approach(action: String) -> Vector2:
	var key: String=provider.contract.actions[action].component;var anchor=provider.component(key)
	var assembly=provider.assemblies[key.get_slice("/",0)]
	for offset in [Vector2(-10,15),Vector2(0,27),Vector2(33,0),Vector2(-33,0),Vector2(0,-27),Vector2(40,25),Vector2(-40,25)]:
		var point: Vector2=anchor.position+offset
		if assembly.contains_interaction(key.get_slice("/",1),point) and world.valid_landing(point):return point
	return Vector2(INF,INF)
func position_for(action: String) -> bool:
	var point:=approach(action)
	if not point.is_finite():return false
	if not world.activate("Z1L5",point):return false
	provider.refresh_binding();world.input_adapter.refresh();return true
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or world==null:return
	var store=get_node("/root/PlayerSave")
	match event.physical_keycode:
		KEY_F1:get_window().size=Vector2i(1280,720);get_window().content_scale_size=get_window().size
		KEY_F2:get_window().size=Vector2i(640,360);get_window().content_scale_size=get_window().size
		KEY_1:position_for("power")
		KEY_2:position_for("flow")
		KEY_3:position_for("pickup")
		KEY_4:position_for("place")
		KEY_I:world.activate("Z1L5",room.point(Vector2(6.8,4.2)));provider.refresh_binding()
		KEY_O:world.activate("Z1L5",room.point(Vector2(10,3.5)));provider.refresh_binding()
		KEY_L:world.input_adapter.open_lesson("melting")
		KEY_F5:print("Fixture save: ",store.save_world_location(world))
		KEY_F9:
			if not world.input_adapter.modal.is_empty():world.input_adapter.close_panel()
			store.load_profile();print("Fixture Continue: ",world.restore_saved_world(world.access))
		KEY_K:world.dead=true;print("Fixture checkpoint recovery: ",world.recover_world_checkpoint(world.access))
		KEY_T:store.fail_commit=not store.fail_commit;print("Fixture save failure: ",store.fail_commit)
		KEY_C:print("Authored fixture completion: ",provider.finish())
		KEY_F8:store.set_completed_prefix(18);print("Isolated four-mode inspection; normal readiness remains empty")
