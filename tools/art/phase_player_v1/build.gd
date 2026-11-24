extends SceneTree
## New native animation clips assembled from existing authored upper-body frames.
## Original locomotion resources and raster artwork are read-only inputs.
const LANDMARKS = preload("res://Actors/Player/device_pose_landmarks.gd")
const DIRS := ["east","south_east","south","south_west","west","north_west","north","north_east"]
const SEQUENCES := {"hold":[0],"aim":[1],"fire_start":[0,1],"fire_loop":[1,2,1,3],"fire_release":[1,0]}
func _initialize() -> void:
	var original: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	var device: SpriteFrames = load("res://assets/devices/phase_device/v1/sprite_frames.tres")
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var manifest := {"version":1,"source_frames_hash":FileAccess.get_sha256("res://assets/characters/cast/explorer/frames.tres"),"clips":{}}
	for direction: String in DIRS:
		var index := DIRS.find(direction)
		var direction_vector := Vector2.RIGHT.rotated(index*PI/4)
		var device_texture := device.get_frame_texture("held_"+direction,0)
		for phase: String in SEQUENCES:
			var clip := phase+"_"+direction
			result.add_animation(clip)
			result.set_animation_loop(clip,phase in ["hold","aim","fire_loop"])
			result.set_animation_speed(clip,12 if phase == "fire_start" else (10 if phase == "fire_release" else 8))
			var entries: Array = []
			for pose_index in SEQUENCES[phase].size():
				var source_index: int = SEQUENCES[phase][pose_index]
				var texture := original.get_frame_texture("operate_"+direction,source_index).duplicate() as AtlasTexture
				var image := texture.get_image()
				var body := LANDMARKS.inspect(image)
				var hand := LANDMARKS.primary_hand(image,body.neck,direction)
				var recoil := Vector2.ZERO
				if phase == "fire_loop" and pose_index % 2 == 1: recoil = -direction_vector*1.5
				var extension: float = {"north_west":-6.0,"north":12.0,"north_east":6.0}.get(direction,0.0)
				var side := signf(extension)
				var outer: float = hand.hand_rect.position.x if side > 0 else hand.hand_rect.end.x
				var inner: float = minf(body.neck.x+13,outer-3) if side > 0 else maxf(body.neck.x-13,outer+3)
				var warp := Vector4(inner*side,outer*side,absf(extension),side)
				texture.set_meta("device_neck_px",body.neck)
				texture.set_meta("device_grip_px",hand.grip)
				texture.set_meta("device_hand_rect",hand.hand_rect)
				texture.set_meta("device_arm_warp",warp)
				texture.set_meta("device_recoil_px",recoil)
				texture.set_meta("device_muzzle_px",LANDMARKS.warp(hand.grip,warp)+(device_texture.get_meta("muzzle_px")-device_texture.get_meta("grip_px"))*(0.34/0.2923077))
				texture.set_meta("device_source_key","operate_%s:%d" % [direction,source_index])
				result.add_frame(clip,texture)
				entries.append({"source_frame":source_index,"grip":[hand.grip.x,hand.grip.y],"recoil":[recoil.x,recoil.y]})
				print(clip," ",pose_index," neck=",body.neck," grip=",hand.grip," hand=",hand.hand_rect)
			manifest.clips[clip] = entries
	assert(ResourceSaver.save(result,"res://assets/characters/cast/explorer/device_v1/poses.tres") == OK)
	var gait := Resource.new()
	var base_frames := {}
	for clip: StringName in original.get_animation_names():
		for frame in original.get_frame_count(clip):
			var texture := original.get_frame_texture(clip,frame)
			var image := texture.get_image()
			if (str(clip).begins_with("idle_") or str(clip).begins_with("walk_")) and texture.get_meta("mirror_walk",false): image.flip_x()
			base_frames["%s:%d" % [clip,frame]] = LANDMARKS.inspect(image)
	gait.set_meta("version",1)
	gait.set_meta("source_hash",manifest.source_frames_hash)
	gait.set_meta("base_frames",base_frames)
	assert(ResourceSaver.save(gait,"res://assets/characters/cast/explorer/device_v1/gait_sockets.tres") == OK)
	var file := FileAccess.open("res://assets/characters/cast/explorer/device_v1/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("R2 004 POSES BUILT: 40 clips / 80 pose sockets / ",base_frames.size()," base-frame landmarks; original art unchanged")
	quit()
