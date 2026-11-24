extends RefCounted
## Additional strict source form; legacy scene/attempt checks stay authoritative.
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const CAMPAIGN_SCRIPT="res://Scripts/World/Runtime/campaign_world.gd"

static func campaign_district(source: Node, id: String, profile: Node) -> bool:
	if source == null or not source.is_inside_tree() or source != profile.get_tree().current_scene: return false
	if source.scene_file_path != REGISTRY.CAMPAIGN_SCENE or source.get_script() == null or source.get_script().resource_path != CAMPAIGN_SCRIPT: return false
	if source.development_preview or source.demonstration_mode or not source.entry_authorized or not profile.has_player_name(): return false
	if not REGISTRY.can_enter_campaign(profile, id) or source.active_subregion_id != id: return false
	var chunk: Node = source.active_chunk()
	var path: NodePath = REGISTRY.CAMPAIGN_DISTRICTS[id]
	return is_instance_valid(chunk) and chunk == source.get_node_or_null(path) and chunk.owner == source and not chunk.fixture_only and chunk.scene_file_path.is_empty() and chunk.frame_valid() and chunk.subregion_id == id

static func navigation_matches(source, id: String, profile: Node) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree() or source != profile.get_tree().current_scene: return false
	if source.scene_file_path == REGISTRY.CAMPAIGN_SCENE:
		if not campaign_district(source, id, profile): return false
		var at: Vector2 = source.player.safe_save_position()
		return source.access.region_at(at) == id and source.valid_landing(at)
	if source.scene_file_path != REGISTRY.WORLD_SCENE or source.get_script() == null or source.get_script().resource_path != "res://Scripts/World/Runtime/phase_world.gd": return false
	if source.get("development_preview") != false or source.get("demonstration_mode") != false or not profile.has_player_name(): return false
	var row := REGISTRY.definition(id)
	if row.is_empty() or not REGISTRY.can_enter(profile, id) or source.active_subregion_id != id: return false
	var polygon := PackedVector2Array()
	for xy in row.permission_polygon: polygon.append(Vector2(xy[0], xy[1]))
	if not Geometry2D.is_point_in_polygon(source.player.safe_save_position(), polygon): return false
	var chunk: Node = source.active_chunk()
	return is_instance_valid(chunk) and not chunk.fixture_only and chunk.frame_valid() and chunk.scene_file_path == row.world_scene and chunk.get_parent() == source.get_node("GroundSort") and chunk.subregion_id == id and chunk.ground_origin == Vector2(row.origin[0], row.origin[1]) and source.valid_landing(source.player.safe_save_position())
static func matches(source,zone: String,number: int,profile: Node) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree():return false
	if source.scene_file_path == REGISTRY.CAMPAIGN_SCENE:
		var id := str(source.get("active_subregion_id"))
		var district := REGISTRY.definition(id)
		return not district.is_empty() and district.zone_id == zone and district.level == number and profile.session_active and profile.data.active_run.get("zone","") == zone and profile.data.active_run.get("level",0) == number and not str(profile.data.active_run.get("attempt_id","")).is_empty() and campaign_district(source, id, profile)
	if source!=profile.get_tree().current_scene or source.scene_file_path!=REGISTRY.WORLD_SCENE:return false
	if source.get_script()==null or source.get_script().resource_path!="res://Scripts/World/Runtime/phase_world.gd":return false
	if source.get("development_preview")!=false or source.get("demonstration_mode")!=false:return false
	if not profile.session_active or profile.data.active_run.get("zone","")!=zone or profile.data.active_run.get("level",0)!=number:return false
	if str(profile.data.active_run.get("attempt_id","")).is_empty():return false
	var row:=REGISTRY.definition(str(source.active_subregion_id))
	if row.is_empty() or row.zone_id!=zone or row.level!=number or not REGISTRY.can_enter(profile,row.id):return false
	var chunk: Node=source.active_chunk()
	return is_instance_valid(chunk) and not chunk.fixture_only and chunk.frame_valid() and chunk.scene_file_path==row.world_scene and chunk.get_parent()==source.get_node("GroundSort") and chunk.subregion_id==row.id and chunk.ground_origin==Vector2(row.origin[0],row.origin[1])
