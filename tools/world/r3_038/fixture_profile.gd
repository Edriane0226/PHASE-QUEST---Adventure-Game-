extends "res://zone2_authority.gd"

const LAB = preload("res://Scripts/World/Zone3/vanishing_ice_lab_world.gd")

func _ready() -> void:
	for flag in ["r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1",
			"r3_031_sunlit","r3_032_orchard","r3_033_dewglass","r3_034_stream",
			"r3_035_steamworks","r3_036_skybridge","r3_038_vanishing_lab"]:
		set_meta(flag,true)
	var args := OS.get_cmdline_user_args()
	var token := "manual" if "--manual" in args and not "--smoke" in args else Crypto.new().generate_random_bytes(8).hex_encode()
	save_path = "res://../fixtures/" + token + ".save"
	var seed := "res://../fixtures/completed.save" if "--restore" in args else "res://../fixtures/arrival.save"
	if (not FileAccess.file_exists(save_path) or (token == "manual" and "--fresh" in args)) and DirAccess.copy_absolute(seed,save_path) != OK:
		push_error("Vanishing Ice Lab fixture needs an earned 037 arrival or 038 completion.")
		return
	load_profile()
	world_entry_request = {}

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/")
		and ProjectSettings.globalize_path("res://").contains("/r3-prompt038/review/")
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func campaign_source(source, zone: String, level: int) -> bool:
	if zone != ZONES[2]:
		return super.campaign_source(source,zone,level)
	if not _fixture(source) or not session_active or level != 1 or WORLD_SAVE.region_for_run(data.active_run) != LAB.REGION:
		return false
	var chunk: Node = source.active_chunk()
	return (source.access.allowed(LAB.REGION) and is_instance_valid(chunk) and chunk.subregion_id == LAB.REGION
		and chunk.frame_valid() and chunk.runtime_provider is LAB)
