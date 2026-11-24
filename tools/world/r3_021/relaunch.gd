extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var index:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--index="):index=int(arg.trim_prefix("--index="))
	var session=load("res://Scripts/UI/Title/menu_session.gd").new();session.load_preferences();var before: String=session.last_region
	var selected: String=session.choose()
	if selected==before:quit(1);return
	FileAccess.open("res://../evidence/relaunch-"+str(index)+".json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS","process":OS.get_process_id(),"before":before,"selected":selected}))
	print("RELAUNCH ",index," ",before," -> ",selected);quit()
