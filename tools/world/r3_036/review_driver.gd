extends Node

const ENGINE = preload("res://Scripts/World/Zone2/skybridge_engine_world.gd")
const PARTS = ENGINE.PARTS
const BEAMS := {"thaw":PARTS.INLET,"freeze":PARTS.PACK,"heat":PARTS.BOILER,"cool":PARTS.CONDENSER}
const KEYS := {KEY_P:"professor",KEY_1:"take_boiler_shell",KEY_2:"take_turbine_cartridge",
	KEY_3:"take_condenser_coil",KEY_4:"take_return_tank",KEY_5:"take_drive_belt",KEY_M:"recipe",
	KEY_6:"thaw",KEY_7:"freeze",KEY_H:"feed",KEY_8:"heat",KEY_9:"wheel",KEY_E:"exhaust",KEY_0:"cool",
	KEY_T:"drain",KEY_F:"finn",KEY_X:"exit"}
var world: Node
var engine: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	engine = world.chunks[PARTS.REGION+".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(engine):
		return false
	if world.active_subregion_id == "Z2L5" and world.access.allowed(PARTS.REGION):
		if not world.activate(PARTS.REGION,engine.points.C0) or not profile.enter_world_subregion(world,PARTS.REGION):
			return false
		engine.refresh_binding()
	return (world.active_subregion_id == PARTS.REGION and engine.active()) or world.active_subregion_id == "Z3L1"

func pose(id: String, require_action := true) -> bool:
	var beam := BEAMS.has(id)
	var part := id
	if beam:
		part = engine.contract.targets[BEAMS[id]].component.get_slice("/",0)
	elif engine.contract.actions.has(id):
		part = engine.contract.actions[id].component.get_slice("/",0)
	var at: Vector2 = engine.points[part]
	for radius in ([62,68,75,56] if beam else [24,30,36,41,19]):
		for i in 16:
			var pos := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(PARTS.REGION,pos): continue
			if beam:
				var target: Node2D = engine.targets[BEAMS[id]]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
						not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif engine._near(part) and (not require_action or engine.world_context().get("key") == PARTS.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	var target: Node2D = engine.targets[BEAMS[id]]
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
		if event.physical_keycode == KEY_F5 and world._transit.is_empty(): profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if not world.player.carrying and world.active_subregion_id == PARTS.REGION and KEYS.has(event.physical_keycode):
			pose(KEYS[event.physical_keycode],false)
