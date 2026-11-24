extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var failures: Array=[];var checks:=0
	var archive:=ZIPReader.new()
	if archive.open(args[0])!=OK:quit(1);return
	var packaged:=archive.get_files();archive.close()
	if not ProjectSettings.load_resource_pack(args[0]):quit(1);return
	for path in ["res://UI/Menus/MainMenuPanel.tscn","res://World/PhaseWorld.tscn","res://Zone_1/Levels/wrld_lvl_1.tscn","res://Zone_1/Levels/wrld_lvl_2.tscn"]:
		checks+=1
		if not load(path) is PackedScene:failures.append(path)
	for path in ["res://UI/Menus/ZoneSelectionPanel.tscn","res://UI/Menus/ZoneLevelsPanel.tscn"]:
		checks+=1
		if ResourceLoader.exists(path):failures.append("selection scene exported "+path)
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/main_menu/world_v1/views.json"))
	checks+=1
	if not catalog is Dictionary or catalog.regions.size()!=3:failures.append("three geographic views")
	else:
		for key in catalog.regions:
			for part in ["static","painting","veil","atmosphere"]:
				checks+=1
				if not load(catalog.regions[key][part]) is Texture2D:failures.append(key+":"+part)
	for path in ["res://fixture_profile.gd","res://check.gd","res://capture.gd","res://manual.gd","res://manual_driver.gd","res://render.gd","res://relaunch.gd","res://legacy-check.gd","res://worldsave-check.gd"]:
		checks+=1
		var relative: String=path.trim_prefix("res://")
		if packaged.has(relative) or packaged.has(relative+".remap") or packaged.has(relative.get_basename()+".gdc"):failures.append("fixture exported "+path)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Android-preset resource ZIP mounted in empty project; normal menu/world/legacy scenes and all views load; no fixture scripts"}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("MENU PACKAGE ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
