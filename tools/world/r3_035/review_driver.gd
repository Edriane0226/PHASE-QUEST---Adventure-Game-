extends Node

const STEAMWORKS = preload("res://Scripts/World/Zone2/steamworks_garden_world.gd")
const PARTS = STEAMWORKS.PARTS
const BEAMS := {"thaw":PARTS.INLET,"freeze":PARTS.FREEZER,"heat":PARTS.BOILER,"cool":PARTS.CONDENSER}
const KEYS := {KEY_P:"professor",KEY_1:"thaw",KEY_2:"spread",KEY_3:"fan",KEY_4:"sun",KEY_B:"lift_belt",
	KEY_5:"freeze",KEY_6:"heat",KEY_H:"fill",KEY_7:"route",KEY_8:"cool",KEY_9:"drain",KEY_0:"blueprint",KEY_X:"exit"}
var world: Node
var works: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	works = world.chunks[PARTS.REGION+".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(works):
		return false
	if world.active_subregion_id == "Z2L4" and world.access.allowed(PARTS.REGION):
		if not world.activate(PARTS.REGION,works.points.C0) or not profile.enter_world_subregion(world,PARTS.REGION):
			return false
		works.refresh_binding()
	return world.active_subregion_id == PARTS.REGION and works.active()

func pose(id: String, require_action := true) -> bool:
	var beam := BEAMS.has(id)
	var part: String = "professor" if id == "professor" else (
		works.contract.targets[BEAMS[id]].component.get_slice("/",0) if beam else works.contract.actions[id].component.get_slice("/",0))
	var at: Vector2 = works.points[part]
	for radius in ([62,68,75,56] if beam else [29,34,38,41,24]):
		for i in 16:
			var pos := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(PARTS.REGION,pos): continue
			if beam:
				var target: Node2D = works.targets[BEAMS[id]]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
					not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif works._near(part) and (not require_action or works.world_context().get("key") == PARTS.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	var target: Node2D = works.targets[BEAMS[id]]
	world.player.set_device_aim(target.get_meta("ground_xy")-world.player.position)
	emitter.facing = (target.global_position-world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		world.restore_saved_world(world.access)
	elif world.input_adapter.modal.is_empty():
		if event.physical_keycode == KEY_F5: profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if not world.player.carrying and world.active_subregion_id == PARTS.REGION and KEYS.has(event.physical_keycode):
			var id: String = KEYS[event.physical_keycode]
			if id == "freeze" and works.phase(works._state,"pack") == "solid":
				id = "lift_pack"
			pose(id,false)
