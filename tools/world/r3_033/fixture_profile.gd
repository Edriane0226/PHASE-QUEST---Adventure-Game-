extends "res://Scripts/Autoload/player_save.gd"

const SUNLIT = preload("res://Scripts/World/Zone2/sunlit_landing_world.gd")
const ORCHARD = preload("res://Scripts/World/Zone2/drying_orchard_world.gd")
const DEWGLASS = preload("res://Scripts/World/Zone2/dewglass_world.gd")
var fail_commit := false

func _ready() -> void:
	for flag in ["r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1","r3_031_sunlit","r3_032_orchard","r3_033_dewglass"]:
		set_meta(flag, true)
	var args := OS.get_cmdline_user_args()
	var token := "manual" if "--manual" in args and not "--smoke" in args else Crypto.new().generate_random_bytes(8).hex_encode()
	save_path = "res://../fixtures/" + token + ".save"
	var seed := "res://../fixtures/completed.save" if "--restore" in args else "res://../fixtures/arrival.save"
	if (not FileAccess.file_exists(save_path) or (token == "manual" and "--fresh" in args)) and DirAccess.copy_absolute(seed, save_path) != OK:
		push_error("Dewglass fixture requires earned Orchard or Greenhouse completion.")
		return
	load_profile()
	world_entry_request = {}

func world_navigation_source(source, id: String) -> bool:
	return _fixture(source) and source.access.allowed(id) and source.active_subregion_id == id and source.valid_landing(source.player.safe_save_position())

func campaign_source(source, zone: String, level: int) -> bool:
	if not _fixture(source) or not session_active or data.active_run.get("zone") != zone or data.active_run.get("level") != level:
		return false
	var chunk: Node = source.active_chunk()
	if chunk == null or not chunk.frame_valid() or not is_instance_valid(chunk.runtime_provider):
		return false
	if chunk.subregion_id == DEWGLASS.REGION:
		return chunk.runtime_provider is DEWGLASS and zone == ZONES[1] and level == 3
	if chunk.subregion_id == "Z2L2":
		return chunk.runtime_provider is ORCHARD and zone == ZONES[1] and level == 2
	if chunk.subregion_id == SUNLIT.REGION:
		return chunk.runtime_provider is SUNLIT and zone == ZONES[1] and level == 1
	var spec: Array = source._zone1_provider_spec(chunk.subregion_id)
	return (zone == ZONES[0] and chunk.subregion_id == "Z1L%d" % level and not spec.is_empty()
		and chunk.runtime_provider.get_script().resource_path == "res://Scripts/World/Zone1/%s.gd" % spec[0])

func _fixture(source) -> bool:
	return save_path.begins_with("res://../fixtures/") and ProjectSettings.globalize_path("res://").contains("/r3-prompt033/review/") \
		and is_instance_valid(source) and source == get_tree().current_scene and source.fixture_session() and not source.demonstration_mode

func _commit_save_file(from: String, to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from, to)
