extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var world=current_scene;var outputs: Array=[];var sources: Dictionary={}
	for path in ["Scripts/World/cube_surface.gd","Scripts/World/stacked_ground.gd","Scripts/World/terrain_relief.gd","Scripts/World/terrain_palette.gd","Scripts/World/puzzle_terraces.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for layer in world.art_layers:
		var surface=layer.surface
		for state in [false,true]:
			layer.geometry.science_open=state
			surface.build() # Exact accepted mesher, deliberately bypass cache.
			var resource:=Resource.new();resource.set_meta("signature",surface.bake_signature());resource.set_meta("surface",{"meshes":surface.meshes,"tiles":surface.tiles,"stats":surface.stats})
			var path: String="res://../evidence/"+surface.biome+("-open" if state else "-closed")+".res"
			if ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
			outputs.append({"file":path.get_file(),"signature":surface.bake_signature(),"sha256":FileAccess.get_sha256(path),"stats":surface.stats.duplicate(true)})
			print("BAKE022 ",path.get_file()," ",surface.stats)
	FileAccess.open("res://../evidence/terrain-bakes.json",FileAccess.WRITE).store_string(JSON.stringify({"version":1,"source_hashes":sources,"outputs":outputs,"contract":"Render-only exact generated meshes; source geometry signature; runtime fallback rebuilds stale/missing bakes; physical support remains live"},"\t"))
	quit()
