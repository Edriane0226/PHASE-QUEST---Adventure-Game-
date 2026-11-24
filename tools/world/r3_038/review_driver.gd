extends Node

const LAB = preload("res://Scripts/World/Zone3/vanishing_ice_lab_world.gd")
const PARTS = LAB.PARTS
const BEAMS := {"observe":PARTS.OBSERVATION,"clear_plug":PARTS.PLUG,"dry":PARTS.SEAL,
	"boil":PARTS.BOILER,"cool":PARTS.CONDENSER}
const KEYS := {KEY_P:"professor",KEY_1:"seal_chamber",KEY_2:"pressure",KEY_3:"heat",KEY_4:"observe",
	KEY_5:"clear_plug",KEY_Q:"question",KEY_6:"spread",KEY_7:"dry",KEY_H:"guard",
	KEY_8:"boil",KEY_9:"route",KEY_0:"cool",KEY_T:"collect",KEY_X:"exit"}
var world: Node
var lab: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	lab = world.chunks[LAB.REGION+".shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	return world.active_subregion_id == LAB.REGION and is_instance_valid(lab) and lab.active()

func pose(id: String, require_action := true) -> bool:
	var beam := BEAMS.has(id)
	var part := id
	if beam:
		part = lab.contract.targets[BEAMS[id]].component.get_slice("/",0)
	elif lab.contract.actions.has(id):
		part = lab.contract.actions[id].component.get_slice("/",0)
	var at: Vector2 = lab.points[part]
	for radius in ([60,68,77,54] if beam else [25,31,38,41,20]):
		for i in 16:
			var position := at+Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if not world.activate(LAB.REGION,position): continue
			if beam:
				var target: Node2D = lab.targets[BEAMS[id]]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
						not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif lab._near(part) and (not require_action or lab.world_context().get("key") == LAB.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var target: Node2D = lab.targets[BEAMS[id]]
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
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
		if world.active_subregion_id != LAB.REGION: return
		if event.physical_keycode == KEY_R:
			var room: Node = world.active_chunk().get_node("lab-service-room")
			world.activate(LAB.REGION,room.point(Vector2(10,3.5)))
		elif KEYS.has(event.physical_keycode):
			pose(KEYS[event.physical_keycode],false)
