extends "res://Scripts/Autoload/player_save.gd"
## Disposable prior-zone credits and blueprint only. Dock outcomes come from play.
const DOCK = preload("res://Scripts/World/Zone1/frozen_dock_world.gd")
var fail_commit := false

func _ready() -> void:
	set_meta("r3_015_fixture", true)
	set_meta("r3_019_permissions", true)
	set_meta("r3_020_restore", true)
	set_meta("r3_029_frozen_dock", true)
	var args := OS.get_cmdline_user_args()
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	if "--manual" in args:
		token = "manual"
	elif "--restore" in args:
		token = "restore"
	save_path = "res://../fixtures/" + token + ".save"
	load_profile()
	if not has_player_name():
		data.player_name = "Disposable Frozen Dock"
		for level in range(1, 6):
			data.completed["melting_and_freezing:%d" % level] = true
		data.extras.independent_puzzle_ids = {"melting_and_freezing:5:boat_blueprint":"freeze_jig_release"}
		data.extras.explained_puzzle_types = {"melt_direct":true, "freeze_controlled":true}
		save_profile()

func world_navigation_source(source, id: String) -> bool:
	return _fixture(source) and source.access.allowed(id) and source.active_subregion_id == id and source.valid_landing(source.player.safe_save_position())

func campaign_source(source, zone: String, level: int) -> bool:
	if not _fixture(source) or not session_active or source.demonstration_mode or source.active_subregion_id != "Z1L6":
		return false
	var chunk = source.active_chunk()
	return chunk != null and chunk.frame_valid() and chunk.runtime_provider is DOCK and zone == ZONES[0] and level == 6 and data.active_run.get("zone") == zone and data.active_run.get("level") == level

func _fixture(source) -> bool:
	return save_path.begins_with("res://../fixtures/") and ProjectSettings.globalize_path("res://").contains("/r3-prompt029/review/") and is_instance_valid(source) and source == get_tree().current_scene and source.fixture_session()

func _commit_save_file(from: String, to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from, to)
