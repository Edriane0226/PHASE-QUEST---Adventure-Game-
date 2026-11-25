extends Node
## Drives the one gameplay camera so that a world unit is a whole number of screen pixels.
## Presentation only: it never moves the player or changes access, reach, support or saves.
const VIEW_HEIGHT := 360.0
const LEAD := 48.0
const LEAD_RATE := 4.0
const LEAD_MIN_SPEED := 20.0
const HOME := Vector2(0,-20)
const TELEPORT := 200.0
## Keeps edges at whole and half units away from the centre of a screen pixel, where rounding could flip.
const EDGE_BIAS := 0.25
## Nodes in this group ask for a wider view. The radius is in the node's "camera_radius" metadata.
const STEP_OUT_GROUP := &"camera_step_out"
const STEP_OUT_RADIUS := 140.0
const STEP_OUT_MARGIN := 32.0
var world: Node2D
var player: Node2D
var camera: Camera2D
var pixel_scale := 0
var stepped_out := false
var lead := Vector2.ZERO
var _lead_target := Vector2.ZERO
var _previous := Vector2.ZERO
var _previous_floor := 0.0

static func play_scale(screen_height: float) -> int:
	return maxi(1,roundi(screen_height/VIEW_HEIGHT))

static func overlook_scale(screen_height: float) -> int:
	var play := play_scale(screen_height)
	return maxi(mini(2,play),play-1)

func bind(host: Node2D) -> void:
	world = host
	player = host.player
	camera = player.get_node("Camera2D")
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	# Runs first in a tick, when the player still has the position the renderer blends from.
	process_physics_priority = -1000
	camera.position_smoothing_enabled = false
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	RenderingServer.canvas_item_set_interpolated(player.get_canvas_item(),false)
	_reset()

func _exit_tree() -> void:
	RenderingServer.canvas_item_set_interpolated(player.get_canvas_item(),player.is_physics_interpolated())

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION and world != null:
		if player.global_position.distance_to(_previous) > TELEPORT:
			_reset()
		_previous = player.global_position
		_previous_floor = player._display_floor

func _reset() -> void:
	_previous = player.global_position
	_previous_floor = player._display_floor
	lead = Vector2.ZERO
	_lead_target = Vector2.ZERO

func reduced_effects() -> bool:
	return world.get_node("/root/PlayerSave").data.extras.get("level1_reduced_effects",false)

func _physics_process(delta: float) -> void:
	if world == null or get_tree().paused:
		if world != null:
			_previous = player.global_position
			_previous_floor = player._display_floor
		return
	var heading: Vector2 = player.movement_input() if world.player_controls_allowed() else Vector2.ZERO
	var travelled := player.global_position-_previous
	if not heading.is_zero_approx():
		# A blocked step still turns the explorer and the device, so the view follows the intent.
		_lead_target = heading.normalized()*LEAD
	elif travelled.length() > LEAD_MIN_SPEED*delta and travelled.length() < TELEPORT:
		_lead_target = travelled.normalized()*LEAD
	else:
		var at := _working_at()
		if at.is_finite():
			# Standing at a control: never lead away from it.
			_lead_target = (at-player.global_position+Vector2(0,player._display_floor)).limit_length(LEAD)
	_previous = player.global_position
	_previous_floor = player._display_floor
	stepped_out = _wants_step_out()

func _working_at() -> Vector2:
	var record: Dictionary = world.input_adapter._context
	if record.is_empty(): return Vector2.INF
	var target: Variant = record.get("target")
	return target.global_position if is_instance_valid(target) and target is Node2D else Vector2.INF

func _wants_step_out() -> bool:
	for marker: Node2D in get_tree().get_nodes_in_group(STEP_OUT_GROUP):
		var radius: float = marker.get_meta("camera_radius",STEP_OUT_RADIUS)
		if stepped_out: radius += STEP_OUT_MARGIN
		if marker.global_position.distance_squared_to(player.global_position) <= radius*radius: return true
	return false

func _process(delta: float) -> void:
	if world != null: update_view(delta)

func update_view(delta: float) -> void:
	var screen := Vector2(get_window().size)
	var content := get_viewport().get_stretch_transform().get_scale()
	if screen.x < 1 or screen.y < 1 or is_zero_approx(content.x) or is_zero_approx(content.y): return
	pixel_scale = overlook_scale(screen.y) if stepped_out else play_scale(screen.y)
	var zoom := Vector2.ONE*pixel_scale/content
	if reduced_effects():
		# A view that swings at every turn is the motion this setting removes.
		lead = Vector2.ZERO
	elif not get_tree().paused:
		lead = lead.lerp(_lead_target,1.0-exp(-LEAD_RATE*delta))
	var blend := Engine.get_physics_interpolation_fraction()
	var ground := _previous.lerp(player.global_position,blend)
	var height := lerpf(_previous_floor,player._display_floor,blend)
	# The player is drawn on the same screen pixel grid as the view, so they cannot jitter apart.
	var drawn := player.transform
	drawn.origin = on_pixel(ground)
	RenderingServer.canvas_item_set_transform(player.get_canvas_item(),drawn)
	# Review tools detach the camera to look at the whole map.
	if camera.top_level: return
	if camera.zoom != zoom: camera.zoom = zoom
	camera.global_position = drawn.origin+HOME+on_pixel(lead)
	# Half a screen must also end on a pixel edge when the screen has an odd size.
	camera.offset = Vector2(0,-on_pixel(Vector2(0,height)).y)+(Vector2(Vector2i(screen)%2)*0.5+Vector2.ONE*EDGE_BIAS)/pixel_scale
	camera.force_update_scroll()

func on_pixel(value: Vector2) -> Vector2:
	return (value*pixel_scale+Vector2(0.5,0.5)).floor()/pixel_scale
