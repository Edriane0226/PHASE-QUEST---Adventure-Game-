extends "res://Scripts/Autoload/player_save.gd"
## Real writer, disposable paths only. No campaign/science authority override.
var fail_commit := false
func _ready() -> void:
	set_meta("r3_015_fixture",true)
	set_meta("r3_019_permissions",true)
	set_meta("r3_020_restore",true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../fixtures").simplify_path())
	save_path="res://../fixtures/manual.save" if "--manual" in OS.get_cmdline_user_args() else "res://../fixtures/"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	load_profile()
	if not has_player_name():
		data.player_name="Disposable world020"
		save_profile()
func world_navigation_source(source, id: String) -> bool:
	return save_path.begins_with("res://../fixtures/") and is_instance_valid(source) and source==get_tree().current_scene and source.fixture_session() and source.access.allowed(id) and source.active_subregion_id==id and source.valid_landing(source.player.safe_save_position())
func _commit_save_file(from: String,to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from,to)
func set_completed_prefix(count: int) -> void:
	data.completed={}
	for i in range(clampi(count,0,18)):data.completed["%s:%d"%[ZONES[i/6],i%6+1]]=true
	_stage_device_evidence()
	changed.emit()
var fire_probe:=false
var probe_mode:="thermal"
func campaign_source(source,_zone: String,_number: int) -> bool:
	return fire_probe and is_instance_valid(source) and source==get_tree().current_scene and source.get("development_preview")==true and source.has_method("world_contact_allowed")
func device_state() -> Dictionary:
	var state: Dictionary=super.device_state()
	if fire_probe:
		for mode in ["thermal","cryo","vacuum","pressure"]:state.unlocked_modes[mode]=true
		for entry in DEVICE.MILESTONES.values():state.learned_capabilities[entry.capability]=true
		state.selected_mode=probe_mode
	return state
func selected_device_mode() -> String:return probe_mode if fire_probe else super.selected_device_mode()

