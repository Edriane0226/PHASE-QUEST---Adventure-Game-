extends Node2D
## Presentation only. No input bindings, target simulation, rewards or VFX.
signal phase_changed(phase: String)
signal animation_emission_changed(active: bool)
const LANDMARKS = preload("res://Actors/Player/device_pose_landmarks.gd")
const POSES = preload("res://assets/characters/cast/explorer/device_v1/poses.tres")
const GAIT = preload("res://assets/characters/cast/explorer/device_v1/gait_sockets.tres")
const DEVICE = preload("res://assets/devices/phase_device/v1/sprite_frames.tres")
const BODY_SHADER = preload("res://assets/shaders/world/player_device_pose.gdshader")
const CUTOUT = preload("res://assets/shaders/world/level1_flat_cutout.gdshader")
var phase := "hold"
var pose_frame := 0
var phase_elapsed := 0.0
var aiming := false
var aim_direction := Vector2.DOWN
var requires_release := false
var preview_enabled := false
var _pressed := false
var _emitting := false
var _mode := ""
var _available := false
var _syncing := false
var _landmarks := {}
var _pose_images := {}
var _player
var _store
var _material: ShaderMaterial
var _original_material: Material
var _held: Sprite2D
var _holstered: Sprite2D
var _head: Sprite2D
var _hand: Sprite2D
var _head_crop := AtlasTexture.new()
var _hand_crop := AtlasTexture.new()
var _muzzle: Marker2D
var _grip: Marker2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent()
	set_process(false)
	if _player.is_node_ready(): _bind_player()
	else: _player.ready.connect(_bind_player,CONNECT_ONE_SHOT)

func _bind_player() -> void:
	_store = get_node("/root/PlayerSave")
	_mode = _store.selected_device_mode()
	_original_material = _player.animated_sprite.material
	_material = ShaderMaterial.new()
	_material.shader = BODY_SHADER
	_player.animated_sprite.material = _material
	_held = Sprite2D.new()
	_holstered = Sprite2D.new()
	_head = Sprite2D.new()
	_hand = Sprite2D.new()
	_muzzle = Marker2D.new()
	_grip = Marker2D.new()
	var flat := ShaderMaterial.new()
	flat.shader = CUTOUT
	for sprite: Sprite2D in [_held,_holstered,_head,_hand]:
		sprite.material = flat
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	_held.name = "Held"
	_holstered.name = "Holstered"
	_head.name = "HeadOccluder"
	_hand.name = "GripHand"
	_held.centered = false
	_holstered.centered = false
	_held.scale = Vector2.ONE*0.34
	_holstered.scale = Vector2.ONE*0.34
	_held.z_index = 1
	_head.z_index = 2
	_hand.z_index = 3
	_muzzle.name = "Muzzle"
	_grip.name = "Grip"
	add_child(_muzzle)
	add_child(_grip)
	_store.changed.connect(_profile_changed)
	_store.restored.connect(_profile_changed)
	set_process(true)
	sync_pose()

func _exit_tree() -> void:
	_pressed = false
	_set_emitting(false)
	if _material != null and is_instance_valid(_player) and is_instance_valid(_player.animated_sprite):
		_player.animated_sprite.material = _original_material

func _profile_changed() -> void:
	var selected: String = _store.selected_device_mode()
	if selected != _mode:
		if _pressed: interrupt()
		_mode = selected
	# A save can emit changed inside an inherited level _ready(), before its
	# learning-support references exist. The normal next-frame sync renders it;
	# mode changes still interrupt emission immediately above.

func available() -> bool:
	return preview_enabled or (is_instance_valid(_store) and not _store.selected_device_mode().is_empty() and _store.is_device_mode_unlocked(_store.selected_device_mode()))

func blocked() -> bool:
	if not _player.is_node_ready(): return true
	var owning_level: Node = _player.level()
	if not is_instance_valid(owning_level) or not owning_level.is_node_ready(): return true
	# Embedded Guides animate inside a paused tree. This pose-only exception is
	# restricted to the disposable demo; the live emitter always rejects demos.
	if preview_enabled and owning_level.get("demonstration_mode") == true and owning_level.get_meta("thermal_guide_playback",false) == true:
		return _player.carrying or _player.jump_elapsed >= 0 or _player.action_elapsed >= 0
	return not _player.controls_allowed() or _player.carrying or _player.jump_elapsed >= 0 or _player.action_elapsed >= 0 or _player.context_progress >= 0 or _player.get_node("WarmingTool").visible

func aim(direction: Vector2, enabled := true) -> bool:
	if not enabled:
		aiming = false
		if not _pressed and phase not in ["fire_start","fire_loop","fire_release"]: _set_phase("hold")
		sync_pose()
		return true
	if not direction.is_finite() or direction.is_zero_approx() or not available() or blocked(): return false
	aim_direction = direction.normalized()
	aiming = true
	if not _pressed and phase != "fire_release": _set_phase("aim")
	_player._facing = _player._direction_from_vector(aim_direction)
	_player._play(_player.locomotion)
	if _player.locomotion in ["walk","run"]: _player._advance_grounded_gait(_player.locomotion,0)
	sync_pose()
	return true

func fire(pressed: bool) -> bool:
	if not pressed:
		requires_release = false
		_pressed = false
		if phase in ["fire_start","fire_loop"]: _set_phase("fire_release")
		sync_pose()
		return true
	if requires_release or not available() or blocked():
		if _pressed: interrupt()
		return false
	if _pressed: return true
	_pressed = true
	_set_phase("fire_start")
	sync_pose()
	return true

func interrupt() -> void:
	requires_release = requires_release or _pressed
	_pressed = false
	aiming = false
	_set_phase("hold")
	_set_emitting(false)

func _set_phase(value: String) -> void:
	if phase == value: return
	phase = value
	phase_elapsed = 0
	pose_frame = 0
	if phase != "fire_loop": _set_emitting(false)
	phase_changed.emit(phase)

func _set_emitting(value: bool) -> void:
	if value == _emitting: return
	_emitting = value
	animation_emission_changed.emit(value)

func emission_active() -> bool:
	return _emitting and available() and not blocked() and _held.visible

func visual_state() -> String:
	if not _available: return "hidden"
	if _holstered.visible: return "holstered"
	return phase

func muzzle() -> Marker2D:
	return _muzzle

func grip() -> Marker2D:
	return _grip

func aim_facing() -> String:
	return _player._direction_from_vector(aim_direction) if aiming else _player._facing

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_node_ready(): return
	if blocked() or not available():
		if _pressed or aiming or phase != "hold": interrupt()
	else:
		phase_elapsed += maxf(delta,0)
		var clip := phase+"_"+aim_facing()
		var duration := POSES.get_frame_count(clip)/POSES.get_animation_speed(clip)
		if phase == "fire_start" and phase_elapsed >= duration: _set_phase("fire_loop")
		elif phase == "fire_release" and phase_elapsed >= duration: _set_phase("aim" if aiming else "hold")
	sync_pose()

func _inspect(texture: Texture2D, mirrored: bool) -> Dictionary:
	var key := str(texture.get_instance_id())+str(mirrored)
	if not _landmarks.has(key):
		var authored_key := "%s:%d" % [_player.animated_sprite.animation,_player.animated_sprite.frame]
		var catalog: Dictionary = GAIT.get_meta("base_frames")
		if catalog.has(authored_key): _landmarks[key] = catalog[authored_key]
		else:
			var image := texture.get_image()
			if mirrored: image.flip_x()
			_landmarks[key] = LANDMARKS.inspect(image)
	return _landmarks[key]

func sync_pose() -> void:
	if _syncing or _material == null or not is_instance_valid(_player) or not _player.is_node_ready(): return
	_syncing = true
	_available = available()
	var sprite: AnimatedSprite2D = _player.animated_sprite
	var original: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	_material.set_shader_parameter("frame_size",original.get_size())
	_material.set_shader_parameter("frame_offset",sprite.offset)
	var enabled := _available and not blocked()
	_held.visible = enabled
	_holstered.visible = _available and not enabled
	_head.visible = enabled
	_hand.visible = enabled
	_material.set_shader_parameter("device_pose",enabled)
	if not enabled:
		_set_emitting(false)
		if _available: _sync_holster(original)
		_syncing = false
		return
	_player.get_node("IdleBreathing").stop()
	_material.set_shader_parameter("breath",0.0)
	var direction: String = _player._facing
	var clip := phase+"_"+direction
	pose_frame = floori(phase_elapsed*POSES.get_animation_speed(clip)) % POSES.get_frame_count(clip)
	var pose: Texture2D = POSES.get_frame_texture(clip,pose_frame)
	var body := _inspect(original,sprite.flip_h)
	var warp: Vector4 = pose.get_meta("device_arm_warp")
	var offset: Vector2 = body.neck-pose.get_meta("device_neck_px")+pose.get_meta("device_recoil_px")
	var source_key: String = pose.get_meta("device_source_key")
	if not _pose_images.has(source_key): _pose_images[source_key] = ImageTexture.create_from_image(pose.get_image())
	_material.set_shader_parameter("upper_body",_pose_images[source_key])
	_material.set_shader_parameter("torso_band",Vector2(body.band_top,body.band_bottom))
	_material.set_shader_parameter("pose_offset",offset)
	_material.set_shader_parameter("arm_warp",warp)
	_head_crop.atlas = original
	_head_crop.region = Rect2(0,0,original.get_width(),body.band_top)
	_head.texture = _head_crop
	_head.scale = sprite.scale
	_head.flip_h = sprite.flip_h
	_head.position = sprite.transform*(Vector2(0,-original.get_height()*0.5+body.band_top*0.5)+sprite.offset)
	var hand_rect: Rect2 = pose.get_meta("device_hand_rect")
	_hand_crop.atlas = pose
	_hand_crop.region = hand_rect
	_hand.texture = _hand_crop
	_hand.scale = sprite.scale
	_hand.position = sprite.transform*(LANDMARKS.warp(hand_rect.get_center(),warp)+offset-original.get_size()*0.5+sprite.offset)
	var palm: Vector2 = LANDMARKS.warp(pose.get_meta("device_grip_px"),warp)+offset
	_grip.position = sprite.transform*(palm-original.get_size()*0.5+sprite.offset)
	_held.texture = DEVICE.get_frame_texture("held_"+direction,0)
	_held.position = _grip.position-_held.texture.get_meta("grip_px")*_held.scale
	_muzzle.position = _held.position+_held.texture.get_meta("muzzle_px")*_held.scale
	_set_emitting(_pressed and phase == "fire_loop")
	_syncing = false

func _sync_holster(texture: Texture2D) -> void:
	var sprite: AnimatedSprite2D = _player.animated_sprite
	var direction: String = _player._facing
	var body := _inspect(texture,sprite.flip_h)
	var side := Vector2.RIGHT.rotated(_player.DIRECTIONS.find(direction)*PI/4+PI/2)
	var belt: Vector2 = body.neck+Vector2(side.x*14,29+side.y*3)
	_holstered.texture = DEVICE.get_frame_texture("holstered_"+direction,0)
	_holstered.z_index = _holstered.texture.get_meta("body_layer")
	_holstered.position = sprite.transform*(belt-texture.get_size()*0.5+sprite.offset)-_holstered.texture.get_meta("belt_px")*_holstered.scale
	_grip.position = _holstered.position+_holstered.texture.get_meta("grip_px")*_holstered.scale
	_muzzle.position = _holstered.position+_holstered.texture.get_meta("muzzle_px")*_holstered.scale
