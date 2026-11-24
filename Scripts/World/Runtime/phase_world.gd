extends Node2D
## One projected-ground frame, one actor/HUD/camera; chunks contribute geometry/providers.
signal subregion_changed(id: String)
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const CHUNK=preload("res://Scripts/World/Runtime/world_chunk.gd")
const WORLD_SAVE=preload("res://Scripts/Content/world_save.gd")
var SAVE_ZONE:=""
var SAVE_LEVEL:=0
var demonstration_mode:=false
var development_preview:=false
var active_subregion_id:=""
var _active_chunk_id:=""
var chunks: Dictionary={}
var hp:=10.0
var warmth:=100.0
var dead:=false
var last_error:=""
var fall_count:=0
var safe_ground:=Vector2.ZERO
var _focused:=true
var _suspended:=false
var restoration_pending:=false
var room_cutaway: Node
var achievement_events:
	get:
		var provider:=learning_provider()
		return provider.achievement_events if provider else null
@onready var player=$GroundSort/Player
@onready var hud=$GameplayHUD/WorldHUD
@onready var panels=$GameplayHUD/SupportPanels
@onready var input_adapter=$WorldInput
func _ready() -> void:
	$GroundSort.y_sort_enabled=true
	room_cutaway=preload("res://Scripts/World/Runtime/room_cutaway.gd").new();room_cutaway.name="RoomCutaway";add_child(room_cutaway);room_cutaway.bind(self)
	player.get_node("Camera2D").position_smoothing_enabled=false
	player.get_node("Camera2D").zoom=Vector2.ONE*1.55
	var bounds:=REGISTRY.world_bounds();var camera: Camera2D=player.get_node("Camera2D")
	camera.limit_left=floori(bounds.position.x);camera.limit_top=floori(bounds.position.y)
	camera.limit_right=ceili(bounds.end.x);camera.limit_bottom=ceili(bounds.end.y)
	input_adapter.bind(self,get_node("/root/PlayerSave"),hud,panels)
	if not transform.is_equal_approx(Transform2D.IDENTITY):last_error="World root must retain the authored ground frame.";set_physics_process(false)
	if not development_preview and not get_node("/root/PlayerSave").world_entry_request.is_empty():_apply_menu_entry.call_deferred()
func _apply_menu_entry() -> void:
	_entry_unavailable()
func take_menu_entry() -> Dictionary:
	var profile := get_node("/root/PlayerSave")
	var request: Dictionary = profile.world_entry_request
	profile.world_entry_request = {}
	if request.get("context","") != profile.menu_context():return {}
	var resume: Dictionary = profile.menu_resume()
	if resume.get("subregion","") != request.get("subregion",""):return {}
	if not resume.is_empty():resume.continue_campaign = request.get("continue_campaign",false)
	return resume
func _entry_unavailable() -> void:
	restoration_pending=true;input_adapter.stop_all("entry_unavailable",true)
	panels.open_panel("pause.open",{"title":"Adventure unavailable","body":"Your saved adventure is retained. Return safely and try again.","actions":[{"id":"entry_menu","label":"Main menu","enabled":true}]})
	panels.intent_requested.connect(func(_panel,action,_payload):
		if action=="entry_menu":get_tree().paused=false;get_tree().change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn"))
func save_and_menu() -> bool:
	input_adapter.stop_all("save_menu",true)
	var profile:=get_node("/root/PlayerSave")
	if not profile.save_world_location(self):
		input_adapter.feedback="Saving could not finish. Stay here and try again.";input_adapter.refresh();return false
	get_tree().paused=false
	return get_tree().change_scene_to_file("res://UI/Menus/MainMenuPanel.tscn")==OK
func active_chunk() -> Node:
	var chunk=chunks.get(_active_chunk_id)
	return chunk if is_instance_valid(chunk) and chunk.is_inside_tree() and not chunk.is_queued_for_deletion() else null
func fixture_session() -> bool:
	var profile:=get_node("/root/PlayerSave")
	return development_preview and profile.has_meta("r3_015_fixture") and profile.get_meta("r3_015_fixture")==true
func has_mounted_region(id: String) -> bool:
	for chunk in chunks.values():
		if is_instance_valid(chunk) and chunk.is_inside_tree() and not chunk.is_queued_for_deletion() and chunk.subregion_id==id and chunk.frame_valid():return true
	return false
func restore_saved_world(policy: RefCounted, checkpoint_only:=false, expected_region:="") -> bool:
	# Stop live Fire/Jump/context state before any fallback, even when no chunk survives.
	restoration_pending=true
	input_adapter.close_panel()
	input_adapter.stop_all("world_restore",true)
	var profile:=get_node("/root/PlayerSave")
	var record: Dictionary=profile.world_record()
	var location: Variant=record.get("location",{})
	var attempts: Variant=record.get("attempts",{})
	var wanted: Variant=attempts.get(location.get("subregion",""),{}) if attempts is Dictionary and location is Dictionary else {}
	var attempt: Variant=wanted.get("attempt",{}) if wanted is Dictionary else {}
	var state: Variant=attempt.get("state",{}) if attempt is Dictionary else {}
	var death_pending: bool=state is Dictionary and WORLD_SAVE.truth(state.get("death_pending"))
	if checkpoint_only or death_pending:
		record.location={"subregion":active_subregion_id if checkpoint_only else location.get("subregion",""),"grounded":false}
	var result: Dictionary=WORLD_SAVE.recovery(record,policy,valid_landing,has_mounted_region,checkpoint_anchor)
	if result.is_empty() or (not expected_region.is_empty() and result.subregion != expected_region):
		active_subregion_id="";_active_chunk_id="";return false
	if not activate(result.subregion,result.position):return false
	var saved: Variant=attempts.get(result.subregion,{}) if attempts is Dictionary else {}
	attempt=saved.get("attempt",{}) if saved is Dictionary else {}
	state=attempt.get("state",{}) if attempt is Dictionary else {}
	if state is Dictionary:
		var health: Variant=state.get("health",10.0)
		var heat: Variant=state.get("warmth",100.0)
		hp=clampf(float(health),0,10) if (health is int or health is float) and is_finite(float(health)) else 10.0
		warmth=clampf(float(heat),0,100) if (heat is int or heat is float) and is_finite(float(heat)) else 100.0
		if checkpoint_only or WORLD_SAVE.truth(state.get("death_pending")):hp=10;warmth=100
	dead=false
	var chunk:=active_chunk()
	# Providers restore their own unique item IDs; world layer never spawns copies.
	if chunk and is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.has_method("restore_world_attempt"):
		chunk.runtime_provider.restore_world_attempt(saved.duplicate(true) if saved is Dictionary else {})
	else:player.carrying=false
	if (not development_preview or profile.get_meta("r3_020_restore",false)) and not profile.enter_world_subregion(self,result.subregion):
		input_adapter.feedback="Restored location could not be saved; retry restoration."
		return false
	restoration_pending=false
	if has_method("refresh_room_presentation"):call("refresh_room_presentation")
	input_adapter.refresh()
	return true
func checkpoint_anchor(id: String, checkpoint: String) -> Vector2:
	return WORLD_SAVE.anchor(id,checkpoint)
func district_art_parent(_district: Node) -> Node2D:
	return $GroundSort
func recover_world_checkpoint(policy: RefCounted) -> bool:
	return restore_saved_world(policy,true)
func mount_chunk(chunk: Node2D) -> bool:
	if not chunk is CHUNK or chunk.get_parent()!=null or chunks.has(chunk.chunk_id) or chunk.chunk_id.is_empty():return false
	var row:=REGISTRY.definition(chunk.subregion_id)
	if row.is_empty():return false
	if chunk.fixture_only:
		if not fixture_session():return false
	elif not REGISTRY.can_enter(get_node("/root/PlayerSave"),chunk.subregion_id) or chunk.scene_file_path!=row.world_scene or chunk.ground_origin!=Vector2(row.origin[0],row.origin[1]):return false
	# Reject nested copies rather than hiding an extra input/camera consumer.
	for node in chunk.find_children("*","",true,false):
		if node is Camera2D or node is CanvasLayer or node.has_method("device_muzzle") or node.get_script()==hud.get_script():return false
	chunk.position=chunk.ground_origin
	if not chunk.frame_valid():return false
	$GroundSort.add_child(chunk);chunks[chunk.chunk_id]=chunk
	return true
func unmount_chunk(id: String) -> bool:
	var chunk: Node=chunks.get(id)
	if not is_instance_valid(chunk) or chunk==active_chunk():return false
	input_adapter.stop_all("chunk_unload",true)
	chunks.erase(id);chunk.get_parent().remove_child(chunk);chunk.queue_free();return true
func activate(id: String,at: Vector2) -> bool:
	var row:=REGISTRY.definition(id)
	if row.is_empty() or not at.is_finite():return false
	var chosen: Node
	for chunk in chunks.values():
		if chunk.subregion_id==id and chunk.frame_valid() and not chunk.height_record(at-chunk.ground_origin).is_empty():chosen=chunk;break
	if chosen==null or (chosen.fixture_only and not fixture_session()):return false
	if not chosen.fixture_only and not registered_district(id):return false
	if not valid_landing(at):return false
	input_adapter.stop_all("subregion_change",true)
	_active_chunk_id=chosen.chunk_id;active_subregion_id=id;SAVE_ZONE=row.zone_id;SAVE_LEVEL=row.level
	player.position=at;safe_ground=at;player.reset_physics_interpolation()
	player._sync_ground_support();player._display_floor=player._floor_height
	subregion_changed.emit(id);input_adapter.refresh();return true
func registered_district(id: String) -> bool:
	return REGISTRY.can_enter(get_node("/root/PlayerSave"),id)
func player_controls_allowed() -> bool:
	var transition:=get_node_or_null("/root/SceneTransition")
	return not restoration_pending and not active_subregion_id.is_empty() and active_chunk()!=null and input_adapter.modal.is_empty() and hud.is_visible_in_tree() and hud.supported and not dead and hp>0 and _focused and not _suspended and not get_tree().paused and (transition==null or not transition.busy) and transform.is_equal_approx(Transform2D.IDENTITY)
func learning_provider() -> Node:
	var chunk:=active_chunk()
	var provider: Node=chunk.runtime_provider if chunk else null
	return provider if is_instance_valid(provider) and provider.has_method("owns_target") and provider.has_method("completion_authorized") else null
func world_target_allowed(target: Node) -> bool:
	var provider:=learning_provider();return provider!=null and provider.owns_target(target)
func world_introduction_authorized(target: Node,id: String) -> bool:
	var provider:=learning_provider();return provider!=null and provider.introduction_authorized(target,id)
func world_intro_receipt(target: Node) -> String:
	var provider:=learning_provider();return provider.intro_receipt(target) if provider else ""
func world_completion_allowed() -> bool:
	var provider:=learning_provider();return provider!=null and provider.completion_authorized()
func world_target_contact_allowed(target: Node2D) -> bool:
	return world_contact_allowed(player.global_position,target.get_meta("ground_xy",target.global_position))
func world_device_ray(from: Vector2,to: Vector2,target: Node2D=null) -> Dictionary:
	var provider:=learning_provider()
	if provider==null or not provider.active():return {}
	var offset:=Vector2(0,player._display_floor)
	var exclusions: Array[RID]=[player.get_rid()]
	var support:=raised_surface(player.position)
	if is_instance_valid(support.get("body")):exclusions.append(support.body.get_rid())
	return {"from":from+offset,"to":target.get_meta("ground_xy",to+offset) if is_instance_valid(target) and world_target_allowed(target) else to+offset,"offset":offset,"exclude":exclusions}
func world_contact_allowed(from: Vector2,to: Vector2) -> bool:
	if room_cutaway!=null and room_cutaway.ray_fraction(from,to)<.999:return false
	var query:=PhysicsRayQueryParameters2D.create(from,to,1|8,[player.get_rid()]);query.hit_from_inside=true
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func raised_surface(point: Vector2,margin:=0.0) -> Dictionary:
	var result: Dictionary={}
	for chunk in chunks.values():
		if not is_instance_valid(chunk) or not chunk.frame_valid():continue
		var record: Dictionary=chunk.height_record(point-chunk.ground_origin,margin)
		if not record.is_empty() and (result.is_empty() or float(record.height)>float(result.height)):result=record
	return result
func valid_landing(point: Vector2) -> bool:
	if not point.is_finite():return false
	var half:=Vector2(10,11)
	var uncovered: Array=[PackedVector2Array([point-half,point+Vector2(half.x,-half.y),point+half,point+Vector2(-half.x,half.y)])]
	for chunk in chunks.values():
		if not is_instance_valid(chunk) or not chunk.frame_valid():continue
		for support in chunk.ground_polygons():
			var next: Array=[]
			for fragment in uncovered:next.append_array(Geometry2D.clip_polygons(fragment,support))
			uncovered=next
	return uncovered.is_empty()
func unsupported_fall(point: Vector2) -> bool:return raised_surface(point).is_empty()
func traversal_fall() -> void:
	fall_count+=1
	var chunk:=active_chunk()
	if chunk and is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.has_method("recover_world_fall"):
		if chunk.runtime_provider.recover_world_fall():return
	input_adapter.stop_all("fall",true);player.position=safe_ground;player.reset_physics_interpolation()
func cancel_thaw_operation() -> void:
	var chunk:=active_chunk()
	if chunk and is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.has_method("cancel_thaw_operation"):chunk.runtime_provider.cancel_thaw_operation()
func footstep_surface(_point: Vector2) -> String:
	var chunk:=active_chunk();return chunk.surface_name if chunk else "snow"
func _physics_process(_delta: float) -> void:
	# Streaming within one identity needs no teleport, respawn, profile write or input reset.
	var current:=active_chunk()
	if current==null or not current.height_record(player.position-current.ground_origin).is_empty():return
	for chunk in chunks.values():
		if chunk.subregion_id==active_subregion_id and chunk.frame_valid() and not chunk.height_record(player.position-chunk.ground_origin).is_empty():
			_active_chunk_id=chunk.chunk_id;return
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_focused=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:_suspended=true
	elif what==NOTIFICATION_APPLICATION_RESUMED:_suspended=false
	if is_instance_valid(input_adapter) and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:input_adapter.stop_all("interrupted",true)
func _exit_tree() -> void:
	if is_instance_valid(input_adapter):input_adapter.stop_all("world_exit",true)
