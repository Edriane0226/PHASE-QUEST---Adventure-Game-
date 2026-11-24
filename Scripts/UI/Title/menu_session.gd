extends RefCounted
## Presentation preferences only. Never stores gameplay, permissions or discovery.
const REGIONS=["gardens","vale","laboratory"]
var path:="user://phasequest_menu.cfg"
var last_region:=""
var reduced_motion:=true
var read_only:=false
var last_error:=""
var document:=ConfigFile.new()
func load_preferences() -> void:
	var config:=document
	if config.load(path)!=OK:return
	var version: Variant=config.get_value("menu","version",0)
	if not version is int or version!=1:read_only=true;return
	var last: Variant=config.get_value("menu","last_region","")
	last_region=last if last is String and last in REGIONS else ""
	var reduce: Variant=config.get_value("menu","reduced_motion",true)
	reduced_motion=reduce if reduce is bool else true
func save_preferences() -> bool:
	if read_only:last_error="Menu preferences need a newer version.";return false
	var config:=document
	config.set_value("menu","version",1);config.set_value("menu","last_region",last_region);config.set_value("menu","reduced_motion",reduced_motion)
	if config.save(path+".tmp")!=OK:last_error="Menu preferences could not be saved.";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:return false
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:
		if FileAccess.file_exists(path+".bak"):DirAccess.copy_absolute(path+".bak",path)
		last_error="Menu preferences could not be committed.";return false
	return true
func choose(saved_region:="") -> String:
	var selected: String=saved_region if saved_region in REGIONS else REGIONS[(REGIONS.find(last_region)+1)%REGIONS.size()]
	last_region=selected;save_preferences();return selected
