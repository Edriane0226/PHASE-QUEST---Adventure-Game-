extends SceneTree
## Render actual final terrain/scenery off-tree; no live world, actors, HUD, fog or save service calls.
var catalog:={"version":1,"source":"R3 021 fixed exterior captures of current shared terrain", "regions":{}}
var before: Dictionary
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("79a9b8"))
	before=root.get_node("PlayerSave").data.duplicate(true)
	var ids:=["gardens","vale","laboratory"]
	var labels:=["Melting Gardens","Sunpetal Vale","Phaseworks Laboratory"]
	var zones: Array=Array(root.get_node("PlayerSave").ZONES)
	for n in range(1,4):
		var scene:=Node2D.new();root.add_child(scene)
		var model=load("res://Scripts/World/Zone%d/zone%d_geometry.gd"%[n,n]).new()
		if not model.load_data():quit(1);return
		var ground=load("res://Scripts/World/Zone%d/zone%d_ground_art.gd"%[n,n]).new();scene.add_child(ground);ground.configure(model)
		# Reuse actual authored decoration records, excluding all station/puzzle/route/actor markers.
		var contributor=load("res://Scripts/World/Zone%d/zone%d_shell_world.gd"%[n,n]).new()
		var sort:=Node2D.new();sort.name="GroundSort";sort.y_sort_enabled=true;contributor.add_child(sort);contributor.geometry=model
		var kit=load("res://assets/zones/zone_%d/world_v1/kit_atlas.tres"%n);contributor.set("_kit",kit)
		var entries: Dictionary={};var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_%d/world_v1/kit_catalog.json"%n))
		for entry in definitions.entries:entries[entry.id]=entry
		contributor.set("_kit_entries",entries)
		for decoration in model.data.decorations:contributor.sprite_asset(decoration.asset,model.v(decoration.at),"Scenery")
		for decoration in model.relief.clustered_decorations(model):contributor.sprite_asset(decoration.asset,decoration.at,"NaturalCluster")
		if n==1:
			for source in model.data.sources:
				for decoration in source.scenery:contributor.sprite_asset(decoration.asset,model.v(decoration.at)+model.v(source.origin),"OriginalScenery")
		sort.reparent(scene);contributor.free()
		var camera:=Camera2D.new();scene.add_child(camera)
		# Exterior landmarks: snow coast/Garden, sunny riverbank, pale laboratory coast.
		var centers:=[Vector2(2200,3350),Vector2(9400,5500),Vector2(14850,4000)]
		camera.position=centers[n-1];camera.zoom=Vector2.ONE*.8;camera.make_current()
		await frame()
		var key: String=ids[n-1]
		var painting:=root.get_texture().get_image();painting.save_png("res://../evidence/"+key+"-painting.png")
		var overlay:=CanvasLayer.new();scene.add_child(overlay)
		for part in ["veil","atmosphere"]:
			var texture:=TextureRect.new();texture.texture=load("res://assets/ui/main_menu/r3_v1/"+key+"_"+part+".png");texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;overlay.add_child(texture);texture.size=Vector2(root.size)
		await frame();root.get_texture().get_image().save_png("res://../evidence/"+key+"-static.png")
		catalog.regions[key]={"zone_id":zones[n-1],"label":labels[n-1],"static":"res://assets/ui/main_menu/world_v1/"+key+"-static.png","painting":"res://assets/ui/main_menu/world_v1/"+key+"-painting.png","veil":"res://assets/ui/main_menu/r3_v1/"+key+"_veil.png","atmosphere":"res://assets/ui/main_menu/r3_v1/"+key+"_atmosphere.png","camera":{"ground_xy":[camera.position.x,camera.position.y],"zoom":camera.zoom.x,"viewport":[1280,720]},"terrain_sha256":FileAccess.get_sha256("res://World/Data/zone%d-shells.json"%n),"relief_sha256":FileAccess.get_sha256("res://Scripts/World/stacked_ground.gd"),"surface_sha256":FileAccess.get_sha256("res://Scripts/World/cube_ground_art.gd"),"spoilers":"Exterior only; no live actors, stations, objectives, routes or discovery"}
		scene.queue_free();await process_frame
	if root.get_node("PlayerSave").data!=before:quit(1);return
	FileAccess.open("res://../evidence/views.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	print("CAPTURE PASS: three actual geographic exteriors; profile unchanged; no world/discovery instantiated")
	quit()
