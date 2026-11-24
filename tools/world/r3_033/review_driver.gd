extends Node

const PARTS = preload("res://Scripts/World/Zone2/dewglass_assembly.gd")
const KEYS := {KEY_P:"professor",KEY_1:"source",KEY_2:"pane",KEY_3:"gutter",KEY_4:"elbow",KEY_5:"seat",KEY_Q:"observe",
	KEY_6:"fill",KEY_7:"pack",KEY_8:"lift",KEY_9:"fit",KEY_0:"collect",KEY_X:"exit",KEY_R:"workroom"}
var world: Node
var greenhouse: Node
var profile: Node

func bind(host: Node) -> bool:
	world = host
	profile = get_node("/root/PlayerSave")
	greenhouse = world.chunks["Z2L3.shell"].runtime_provider
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(greenhouse):
		return false
	if world.active_subregion_id == "Z2L2" and world.access.allowed(PARTS.REGION):
		if not world.activate(PARTS.REGION,greenhouse.points.C0) or not profile.enter_world_subregion(world,PARTS.REGION):
			return false
		greenhouse.refresh_binding()
	return world.active_subregion_id == PARTS.REGION and greenhouse.active()

func pose(id: String, require_action := true) -> bool:
	var beam := id in ["pane","pack"]
	var part: String = id if beam or id == "professor" else greenhouse.contract.actions[id].component.get_slice("/",0)
	var at: Vector2 = greenhouse.points[part]
	var room: Node2D = greenhouse.get_parent().get_node("dewglass-workroom")
	var indoors := part == "pack"
	for radius in ([64,71,56] if id == "pane" else ([49,44,39,33] if beam else [33,39,43,29])):
		for i in 16:
			var pos := at + Vector2.DOWN.rotated(i*TAU/16.0)*float(radius)
			if indoors and not room.contains_ground(pos,room.elevation):
				continue
			if not world.activate(PARTS.REGION,pos):
				continue
			if beam:
				var target: Node2D = greenhouse.targets[PARTS.PANE if id == "pane" else PARTS.PACK]
				aim(id)
				if target.geometry_reason(world.player.device_muzzle()).is_empty() and (
					not target.targeting_reason(world,profile).is_empty() or world.input_adapter.emitter.selected == target):
					return true
			elif greenhouse._near(part) and (not require_action or greenhouse.world_context().get("key") == PARTS.REGION+":"+id):
				return true
	return false

func aim(id: String) -> void:
	var emitter: Node = world.input_adapter.emitter
	emitter.release()
	var target: Node2D = greenhouse.targets[PARTS.PANE if id == "pane" else PARTS.PACK]
	var grounded_direction: Vector2 = target.get_meta("ground_xy")-world.player.position
	world.player.set_device_aim(grounded_direction)
	emitter.facing = (target.global_position-world.player.device_muzzle().global_position).normalized()
	emitter._aim()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F9:
		world.input_adapter.close_panel()
		profile.load_profile()
		world.restore_saved_world(world.access)
	elif world.input_adapter.modal.is_empty():
		if event.physical_keycode == KEY_F5: profile.save_world_location(world)
		if event.physical_keycode == KEY_K: world.traversal_fall()
		if KEYS.has(event.physical_keycode) and not world.player.carrying:
			var id: String = KEYS[event.physical_keycode]
			if id == "workroom":
				var room: Node2D = greenhouse.get_parent().get_node("dewglass-workroom")
				world.activate(PARTS.REGION,room.point(Vector2(7.6,3.5)))
			else: pose(id,false)
