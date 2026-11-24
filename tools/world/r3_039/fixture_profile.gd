extends "res://zone3_authority.gd"

const SORTING = preload("res://Scripts/World/Zone3/sample_sorting_world.gd")

func _ready() -> void:
	for flag in ["r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1",
			"r3_031_sunlit","r3_032_orchard","r3_033_dewglass","r3_034_stream","r3_035_steamworks",
			"r3_036_skybridge","r3_038_vanishing_lab","r3_039_sorting_room"]:
		set_meta(flag,true)
	var args := OS.get_cmdline_user_args()
	var token := "manual" if "--manual" in args and not "--smoke" in args else Crypto.new().generate_random_bytes(8).hex_encode()
	save_path = "res://../fixtures/"+token+".save"
	var seed := "res://../fixtures/completed.save" if "--restore" in args else "res://../fixtures/arrival.save"
	if (not FileAccess.file_exists(save_path) or (token == "manual" and "--fresh" in args)) and DirAccess.copy_absolute(seed,save_path) != OK:
		push_error("Sorting Room fixture needs an earned 038 Lab completion or 039 Sorting Room completion.")
		return
	load_profile()
	world_entry_request = {}

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/")
		and ProjectSettings.globalize_path("res://").contains("/r3-prompt039/review/")
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func campaign_source(source, zone: String, level: int) -> bool:
	if zone != ZONES[2] or level == 1:
		return super.campaign_source(source,zone,level)
	if level != 2 or not _fixture(source) or not session_active or WORLD_SAVE.region_for_run(data.active_run) != SORTING.REGION:
		return false
	var chunk: Node = source.active_chunk()
	return (source.access.allowed(SORTING.REGION) and is_instance_valid(chunk) and chunk.subregion_id == SORTING.REGION
		and chunk.frame_valid() and chunk.runtime_provider is SORTING)
