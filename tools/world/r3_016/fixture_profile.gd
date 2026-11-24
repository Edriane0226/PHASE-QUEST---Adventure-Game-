extends "res://Scripts/Autoload/player_save.gd"
## Test-only autoload replacement; never reads/writes any profile or grants outcomes.
func _ready() -> void:
	set_meta("r3_015_fixture",true);set_meta("r3_016_permissions",true)
	save_path="user://r3-016-never-written.save"
	data={"version":1,"player_name":"Zone 1 review","completed":{},"active_run":{},"extras":{}}
	session_active=false
func save_profile() -> bool:return false
func begin_level(_zone: String,_number: int) -> bool:return false
func finish_level(_zone: String,_number: int,_events: Array=[],_source=null) -> bool:return false
func campaign_source(_source,_zone: String,_number: int) -> bool:return false
