extends "res://Scripts/Autoload/player_save.gd"
## Test-only autoload replacement; never reads/writes any profile or grants outcomes.
func _ready() -> void:
	set_meta("r3_015_fixture",true);set_meta("r3_019_permissions",true)
	save_path="user://r3-019-never-written.save"
	data={"version":1,"player_name":"Connected world review","completed":{},"active_run":{},"extras":{}}
	session_active=false
func save_profile() -> bool:return false
func begin_level(_zone: String,_number: int) -> bool:return false
func finish_level(_zone: String,_number: int,_events: Array=[],_source=null) -> bool:return false
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
func set_completed_prefix(count: int) -> void:
	data.completed={}
	for i in range(clampi(count,0,18)):data.completed["%s:%d"%[ZONES[i/6],i%6+1]]=true
	changed.emit()
