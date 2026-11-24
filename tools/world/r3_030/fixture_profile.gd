extends "res://Scripts/Autoload/player_save.gd"

const PROVIDERS := ["melting_garden_world","frozen_mill_world","stillwater_world","canal_world","workshop_world","frozen_dock_world"]
var fail_commit := false

func _ready() -> void:
	for flag in ["r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1"]:
		set_meta(flag,true)
	var args := Array(OS.get_cmdline_user_args())
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	if "--manual" in args:token="manual"
	save_path="res://../fixtures/"+token+".save"
	if "--restore" in args or ("--render" in args and not args.any(func(arg):return arg.begins_with("--resume-after="))):
		DirAccess.copy_absolute("res://../fixtures/restore.save",save_path)
	for arg: String in args:
		if arg.begins_with("--resume-after="):
			var level:=arg.trim_prefix("--resume-after=").to_int()
			if level>=1 and level<=5:
				DirAccess.copy_absolute("res://../fixtures/after-l%d.save"%level,save_path)
	load_profile()
	if not has_player_name():
		start_new_world("Zone 1 Acceptance",menu_context())
	world_entry_request={}

func world_navigation_source(source, id: String) -> bool:
	return _fixture(source) and source.access.allowed(id) and source.active_subregion_id==id and source.valid_landing(source.player.safe_save_position())

func campaign_source(source,zone: String,number: int) -> bool:
	if not _fixture(source) or not session_active or zone!=ZONES[0] or number<1 or number>PROVIDERS.size():
		return false
	var chunk: Node=source.active_chunk()
	return chunk!=null and chunk.subregion_id=="Z1L%d"%number and chunk.frame_valid() and is_instance_valid(chunk.runtime_provider) and chunk.runtime_provider.get_script().resource_path=="res://Scripts/World/Zone1/"+PROVIDERS[number-1]+".gd" and data.active_run.get("zone")==zone and data.active_run.get("level")==number

func _fixture(source) -> bool:
	return save_path.begins_with("res://../fixtures/") and ProjectSettings.globalize_path("res://").contains("/r3-prompt030/review/") and is_instance_valid(source) and source==get_tree().current_scene and source.fixture_session() and not source.demonstration_mode

func _commit_save_file(from: String,to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from,to)
