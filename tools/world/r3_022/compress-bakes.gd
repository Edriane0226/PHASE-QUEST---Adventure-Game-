extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/terrain-bakes.json"))
	for entry in index.outputs:
		var path: String="res://../evidence/"+entry.file;var resource=load(path)
		if ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
		entry.sha256=FileAccess.get_sha256(path)
	FileAccess.open("res://../evidence/terrain-bakes.json",FileAccess.WRITE).store_string(JSON.stringify(index,"\t"));quit()
