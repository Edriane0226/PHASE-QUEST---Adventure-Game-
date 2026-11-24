extends "res://Scripts/Autoload/player_save.gd"
## Seeds prerequisite credit and known types only in the staged test project.
var fail_commit := false

func _ready() -> void:
	set_meta("r3_015_fixture", true)
	set_meta("r3_019_permissions", true)
	set_meta("r3_020_restore", true)
	var args := OS.get_cmdline_user_args()
	var file := Crypto.new().generate_random_bytes(8).hex_encode()
	if "--manual" in args:
		file = "manual"
	elif "--restore" in args:
		file = "restore"
	save_path = "res://../fixtures/" + file + ".save"
	load_profile()
	if not has_player_name():
		data.player_name = "Disposable Workshop"
		for level in range(1, 5):
			data.completed["melting_and_freezing:%d" % level] = true
		data.extras.explained_puzzle_types = {"melt_direct":true, "freeze_controlled":true, "melt_solar_relay":true}
		save_profile()

func world_navigation_source(source, id: String) -> bool:
	return _fixture(source) and source.access.allowed(id) and source.active_subregion_id == id and source.valid_landing(source.player.safe_save_position())

func campaign_source(source, zone: String, number: int) -> bool:
	if not _fixture(source) or not session_active or source.demonstration_mode or source.active_subregion_id != "Z1L5":
		return false
	var chunk = source.active_chunk()
	return chunk != null and chunk.frame_valid() and is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.get_script().resource_path == "res://Scripts/World/Zone1/workshop_world.gd" and zone == ZONES[0] and number == 5 and data.active_run.get("zone") == zone and data.active_run.get("level") == number

func _fixture(source) -> bool:
	return save_path.begins_with("res://../fixtures/") and ProjectSettings.globalize_path("res://").contains("/r3-prompt028/review/") and is_instance_valid(source) and source == get_tree().current_scene and source.fixture_session()

func _commit_save_file(from: String, to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from, to)
