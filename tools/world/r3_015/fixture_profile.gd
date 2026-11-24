extends "res://Scripts/Autoload/player_save.gd"
## Isolated runner replaces its autoload only. Never installed into the normal project.
var selection_writes:=0
var fail_save:=false
func _ready() -> void:
	set_meta("r3_015_fixture",true)
	save_path="user://r3-015-fixture.save"
	data={"version":1,"player_name":"Mira","completed":{},"active_run":{"zone":"melting_and_freezing","level":1,"attempt_id":"r3-015-only","state":{}},"extras":{"phase_device":{"version":1,"unlocked_modes":{"thermal":true},"learned_capabilities":{"melting":true},"selected_mode":"thermal"}}}
	session_active=true
func save_profile() -> bool:
	selection_writes+=1
	if fail_save:last_error="Fixture save failed.";return false
	return true # Fixture memory only; no physical profile is read or written.
func campaign_source(source,zone: String,number: int) -> bool:
	return is_instance_valid(source) and source==get_tree().current_scene and source.get("development_preview")==true and source.get_script().resource_path=="res://Scripts/World/Runtime/phase_world.gd" and zone==source.SAVE_ZONE and number==source.SAVE_LEVEL
func commit_device_outcome(_target,_state: Dictionary,_source,_successes: Array=[],_events: Array=[]) -> bool:return false
func begin_level(_zone: String,_level: int) -> bool:return false
func finish_level(_zone: String,_level: int,_events: Array=[],_source=null) -> bool:return false
