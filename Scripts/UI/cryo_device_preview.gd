extends Node2D
## Disposable science preview. No store/attempt binding, campaign grants or saves.
signal shot_started
signal shot_stopped(cause: String)
const SAVE_ZONE := "melting_and_freezing"
const SAVE_LEVEL := 0 # Never a registered campaign source.
const DEVICE := {"version":1,"unlocked_modes":{"cryo":true},"learned_capabilities":{"freezing":true},"selected_mode":"cryo"}
const SPEC := {"id":"cryo_preview_water","zone":"melting_and_freezing","level":3,"material":"water","process":"freezing","allowed_modes":["cryo"],"required_exposure":4.0,"max_range":100.0,"required_flags":["filled"]}
const TARGET = preload("res://Scripts/World/phase_device_target_2d.gd")
const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
const EFFECT = preload("res://Scripts/World/cryo_beam_effects.gd")
const CUE = preload("res://Scripts/World/phase_device_target_cue.gd")
const SAMPLE_ART = preload("res://assets/effects/cryo/v1/sample_frames.tres")
class PreviewSettings extends RefCounted:
	var data := {"extras":{"level1_reduced_effects":false}}
var store := PreviewSettings.new() # Only cosmetic settings, never PlayerSave.
var source: Node
var demonstration_mode := true
var preview_paused := false
var dead := false
var story := {"is_open":false}
var learning_support := {"opened":false}
var last_stop := ""
var held := false
var requires_release := false
var accepted := false
var facing := Vector2.RIGHT
var selected_mode := "cryo"
var sample := {"material":"water","state":"liquid","amount":1.0,"phase_region":"freezing","heat_flow":"out"}
var flags := {"filled":true}
var _focused := true
var _suspended := false
var _had_contact := false
var target: Node2D
var effects: Node2D
var cue: Node2D
var water: Sprite2D
var ice: Sprite2D
var blocker: StaticBody2D
@onready var player = $Actors/Player
@onready var hud = $GameplayHUD
@onready var controls = $GameplayHUD/HudRoot/MobileControls

# Narrow presentation/configuration seam shared with other disposable previews.
func device_definition() -> Dictionary: return DEVICE
func target_definition() -> Dictionary: return SPEC
func effect_script() -> Script: return EFFECT
func sample_art() -> SpriteFrames: return SAMPLE_ART
func preview_title() -> String: return "CRYO — HEAT REMOVAL PREVIEW"
func preview_summary(complete: bool) -> String:
	return "Water became solid. Preview result only." if complete else "Remove heat from liquid water. No rewards."

func _ready() -> void:
	source = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	player.device_rig.preview_enabled = true # Existing pose-only preview support.
	player.set_physics_process(true)
	# Shared HUD/player retained. Detach only this view's campaign adapters.
	controls.fire_pressed.disconnect(hud.fire_input.press)
	controls.fire_released.disconnect(hud.fire_input.release)
	hud.fire_input.set_process(false)
	hud.mode_selector.allowed = func(): return false
	controls.radial_input = null
	var profile := get_node("/root/PlayerSave")
	store.data.extras.level1_reduced_effects = bool(profile.data.get("extras",{}).get("level1_reduced_effects",false))
	profile.changed.disconnect(hud._refresh_device_view)
	profile.restored.disconnect(hud._profile_restored)
	profile.changed.connect(_profile_interrupted)
	profile.restored.connect(_profile_interrupted)
	controls.fire_pressed.connect(press)
	controls.fire_released.connect(release)
	controls.movement_changed.connect(player.set_touch_movement)
	controls.sprint_changed.connect(player.set_touch_sprinting)
	controls.pause_requested.connect(toggle_pause)
	controls.map_requested.connect(toggle_pause)
	controls.jump_requested.connect(player.request_jump)
	controls.preview_on_desktop = true
	controls.touch_mode = true
	controls.set_enabled(true)
	controls.get_node("Buttons/fire").modulate = Color.WHITE
	hud.get_node("HudRoot/GuideButton").hide()
	# Preview has no health/warmth simulation; leave the sample's south-facing
	# contact visible instead of covering it with unrelated campaign gauges.
	hud.get_node("HudRoot/ProfileFrame").hide()
	hud.get_node("HudRoot/PausePanel/Actions/ResumeButton").pressed.connect(toggle_pause)
	for id in ["RestartButton","SaveMenuButton","GuidesButton","SettingsButton"]:
		hud.get_node("HudRoot/PausePanel/Actions/"+id).hide()
	hud.get_node("HudRoot/PausePanel/Settings/ReducedEffects").toggled.connect(set_reduced)
	target = TARGET.new()
	target.name = "PreviewWaterSample"
	add_child(target)
	water = Sprite2D.new()
	water.texture = sample_art().get_frame_texture("sample",0)
	water.scale = Vector2.ONE*(55.0/128)
	target.add_child(water)
	ice = Sprite2D.new()
	ice.texture = sample_art().get_frame_texture("sample",3)
	ice.scale = water.scale
	target.add_child(ice)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	body.add_child(shape)
	target.add_child(body)
	target.hit_collider = body
	target.cue_radius = 22
	effects = effect_script().new()
	player.add_child(effects)
	effects.bind(self)
	cue = CUE.new()
	player.add_child(cue)
	cue.top_level = true
	cue.global_transform = Transform2D.IDENTITY
	cue.z_index = 4095
	cue.caption_layout = Callable(hud,"device_caption_position")
	reset_sample()
	set_heading(0)
	get_viewport().size_changed.connect(_frame_preview)
	_present()

func player_controls_allowed() -> bool: return not preview_paused and not dead and _focused and not _suspended
func _profile_interrupted() -> void:
	if is_instance_valid(target): reset_sample()
func raised_surface(_at: Vector2, _margin := 0.0) -> Dictionary: return {}
func unsupported_fall(_at: Vector2) -> bool: return false
func valid_landing(_at: Vector2) -> bool: return true
func footstep_surface(_at: Vector2) -> String: return "cement"
func cancel_thaw_operation() -> void: pass

func reset_sample() -> void:
	stop("reset")
	controls.reset_input()
	player.reset_touch_movement()
	release() # Reset/replay also clears a latch when no pointer owns Fire.
	assert(target.configure_preview(target_definition(),self))
	ice.modulate.a = 0
	water.visible = float(sample.amount) > 0
	_present()

func set_heading(index: int) -> void:
	stop("turn")
	controls.reset_input()
	facing = Vector2.RIGHT.rotated(posmod(index,8)*PI/4)
	player._facing = player._direction_from_vector(facing)
	player._play("idle")
	player.device_rig.sync_pose()
	# Use a closer prepared sample on compact screens at the same gameplay zoom;
	# a full 70-unit vertical span cannot fit below the existing objective card.
	var distance := 50.0 if get_viewport_rect().size.y < 440 else 70.0
	target.global_position = player.device_muzzle().global_position+facing*distance
	_frame_preview()

func _frame_preview() -> void:
	if not is_instance_valid(target): return
	var camera: Camera2D = player.get_node("Camera2D")
	var extent := get_viewport_rect().size
	var desired := Vector2(extent.x*0.5+30,extent.y-100 if extent.y < 440 else extent.y*0.5+60)
	var middle: Vector2 = (player.device_muzzle().global_position+target.global_position)*0.5
	camera.position = middle-player.global_position-(desired-extent*0.5)/camera.zoom
	camera.force_update_scroll()

func set_reduced(value: bool) -> void:
	store.data.extras.level1_reduced_effects = value
	_present()

func _reason() -> String:
	if not is_instance_valid(target) or target.is_queued_for_deletion(): return "target_lost"
	if not target.preview_outcome().is_empty(): return "complete"
	var offset: Vector2 = target.global_position-player.device_muzzle().global_position
	if offset.length() > 100: return "out_of_range"
	if absf(facing.angle_to(offset)) > PI/6: return "outside_cone"
	var invalid := RULES.eligibility(target_definition(),selected_mode,device_definition(),sample,flags)
	return invalid if not invalid.is_empty() else target.geometry_reason(player.device_muzzle())

func snapshot() -> Dictionary:
	if not is_node_ready() or not player_controls_allowed() or get_tree().paused: return {}
	var muzzle: Vector2 = player.device_muzzle().global_position
	var reason := _reason()
	var contact := reason.is_empty()
	var endpoint: Vector2 = target.global_position if contact else muzzle+facing*100
	var ray := PhysicsRayQueryParameters2D.create(muzzle,endpoint,TARGET.BLOCKER_MASK,[player.get_rid()])
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): endpoint = hit.position
	return {"origin":muzzle,"actor":player.global_position,"point":endpoint,"sample_point":target.global_position if is_instance_valid(target) else endpoint,"facing":facing,"range":100.0,"radius":22.0,
		"mode":selected_mode,"target":contact,"active":accepted and held and player.device_rig.emission_active(),"shot":accepted and held and not requires_release,"phase":player.device_rig.phase,
		"progress":target.exposure()/4.0 if is_instance_valid(target) else 0.0,"status":"RELEASE FIRE" if requires_release and held else {"empty_sample":"NO WATER","occluded":"PATH BLOCKED","out_of_range":"OUT OF RANGE","unsupported_mode":"WRONG MODE","complete":"PREVIEW COMPLETE"}.get(reason,"NO CLEAR TARGET")}

func press() -> void:
	if held: return
	held = true
	if requires_release or not player_controls_allowed() or player.device_rig.blocked(): requires_release = true; return
	var reason := _reason()
	_had_contact = reason.is_empty()
	if _had_contact: player.set_device_aim(target.global_position-player.device_muzzle().global_position)
	accepted = player.set_device_firing(true)
	if accepted: shot_started.emit()

func release() -> void:
	var running := accepted
	held = false
	accepted = false
	requires_release = false
	_had_contact = false
	if is_instance_valid(player): player.set_device_firing(false)
	if running: shot_stopped.emit("release")

func stop(reason: String) -> void:
	last_stop = reason
	var running := accepted
	requires_release = requires_release or held
	accepted = false
	_had_contact = false
	if is_instance_valid(player) and player.is_node_ready():
		player.device_rig.interrupt()
		player.set_device_aim(facing,false)
	if running: shot_stopped.emit(reason)

func toggle_pause() -> void:
	preview_paused = not preview_paused
	stop("pause")
	controls.set_enabled(not preview_paused)
	player.reset_touch_movement()
	hud.get_node("HudRoot/PausePanel").visible = preview_paused
	hud.get_node("HudRoot/PauseShade").visible = preview_paused
	_present()

func _present() -> void:
	if not is_instance_valid(hud): return
	var complete: bool = is_instance_valid(target) and not target.preview_outcome().is_empty()
	hud.present({"name":"Device preview","title":preview_title(),"warmth":100.0,"quest_title":"CONTROLLED PREVIEW — NO REWARDS","quest":preview_summary(complete),"modal":preview_paused})
	hud.get_node("HudRoot/LevelTitle").text = preview_title()
	hud.get_node("HudRoot/PhaseModeDial").present(device_definition(),"",bool(store.data.extras.level1_reduced_effects))
	hud.get_node("HudRoot/GuideButton").hide()

func _physics_process(delta: float) -> void:
	if not is_node_ready(): return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		stop("target_lost")
		cue.present({})
		return
	if not player_controls_allowed() or get_tree().paused or player.device_rig.blocked():
		stop("inactive_preview")
		cue.present({})
		return
	var movement: Vector2 = player.movement_input()
	if not movement.is_zero_approx(): facing = movement.normalized()
	var reason := _reason()
	if accepted and held and _had_contact and not reason.is_empty(): stop("target_lost")
	if not requires_release:
		if reason.is_empty():
			player.set_device_aim(target.global_position-player.device_muzzle().global_position)
			if held: _had_contact = true
		else:
			player._facing = player._direction_from_vector(facing)
			player._play(player.locomotion)
			player.set_device_aim(facing,false)
	if accepted and held and player.device_rig.emission_active() and reason.is_empty():
		var result: Dictionary = target.apply_preview_exposure(delta,player.device_muzzle(),selected_mode,device_definition(),sample,flags,true)
		if result.new_outcome:
			stop("verified")
			_present()
	var progress: float = target.exposure()/4.0
	_present_sample(progress)
	cue.present(snapshot())

func _present_sample(progress: float) -> void:
	ice.texture = sample_art().get_frame_texture("sample",mini(3,floori(progress*4)))
	ice.modulate.a = clampf((progress-0.25)/0.75,0,1)
	water.visible = float(sample.amount) > 0

func toggle_blocker() -> void:
	if is_instance_valid(blocker): blocker.free(); return
	blocker = StaticBody2D.new()
	blocker.collision_layer = 8
	blocker.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10,40)
	shape.shape = rectangle
	blocker.add_child(shape)
	add_child(blocker)
	blocker.global_position = player.device_muzzle().global_position+facing*35

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8: set_heading(event.physical_keycode-KEY_1)
	match event.physical_keycode:
		KEY_R: reset_sample()
		KEY_P,KEY_ESCAPE: toggle_pause()
		KEY_U:
			sample.amount = 0.0 if float(sample.amount) > 0 else 1.0
			reset_sample()
		KEY_G: toggle_blocker()
		KEY_F: set_reduced(not store.data.extras.level1_reduced_effects)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _focused = false; stop("background")
	elif what == NOTIFICATION_APPLICATION_PAUSED: _suspended = true; stop("background")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _focused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _suspended = false
	elif what == NOTIFICATION_EXIT_TREE: stop("exit")
