extends "res://Scripts/Autoload/player_save.gd"
## Disposable real writer. Does not override campaign/science or world-source authority.
var fail_commit:=false
var readiness_probe:=false
func _ready() -> void:
	save_path="res://../fixtures/manual.save" if "--manual" in OS.get_cmdline_user_args() else "res://../fixtures/"+Crypto.new().generate_random_bytes(8).hex_encode()+".save"
	load_profile()
func menu_world_ready(id: String) -> bool:
	return readiness_probe or super.menu_world_ready(id)
func _commit_save_file(from: String,to: String) -> Error:
	return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from,to)
