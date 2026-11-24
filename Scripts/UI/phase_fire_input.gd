extends Node
## Raw input adapter. Shared emitter owns aiming/contact; target owns science.
const EMITTER = preload("res://Scripts/World/phase_device_emitter.gd")
var player: Node
var controls: Control
var allowed: Callable
var held := false
var accepted := false
var emitter: Node

func bind(actor: Node, router: Control, permission: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = actor
	controls = router
	allowed = permission
	controls.fire_pressed.connect(press)
	controls.fire_released.connect(release)
	emitter = EMITTER.new()
	emitter.name = "Emitter"
	add_child(emitter)
	emitter.bind(player,get_node("/root/PlayerSave"),permission)

func available() -> bool:
	return is_instance_valid(player) and player.is_node_ready() and allowed.is_valid() and allowed.call() and player.device_rig.available() and not player.device_rig.blocked() and not player.device_rig.requires_release

func press() -> void:
	if held: return
	held = true
	accepted = available() and emitter.press()

func release() -> void:
	held = false
	accepted = false
	if is_instance_valid(emitter): emitter.release()

func _process(_delta: float) -> void:
	var enabled: bool = available() and is_instance_valid(emitter) and emitter.available() and not emitter.requires_release
	if accepted and not enabled:
		emitter.interrupt("input_blocked")
		accepted = false
	# A blocked press never arms itself when hands/controls later become free.
	if is_instance_valid(controls):
		controls.get_node("Buttons/fire").modulate = Color.WHITE if enabled else Color(1,1,1,0.45)
	if not is_instance_valid(controls) or not controls.controls_enabled or get_tree().paused:
		if held: release()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]: release()
