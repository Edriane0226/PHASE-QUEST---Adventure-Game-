extends SceneTree
## Writes assets/world/terrain_bake_v3 from CampaignWorld.tscn and the exported terrain sheets.
## Render pages only: the bake holds no support or collision.
## Run after changing floors, stations, routes, relief, the sheets or the painter. Needs a window
## and a disposable profile folder:
##   $env:APPDATA = "<empty folder>"
##   Godot --path <project> --resolution 640x360 -s res://tools/world/terrain_bake/bake.gd
const ENTRY := preload("res://tools/world/r3_052/title_entry.gd")
const SURFACE := preload("res://Scripts/World/cube_surface.gd")

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	if DisplayServer.get_name() == "headless":
		push_error("Terrain bake needs a window.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SURFACE.BAKE_DIR))
	var tiles: Resource = SURFACE.pack_tiles()
	if ResourceSaver.save(tiles,SURFACE.BAKE_DIR+"tiles.res",ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("Cannot save the tile pack.")
		quit(1)
		return
	SURFACE._tiles = tiles.get_meta("sheets")
	# A new game fixes the floors. Later puzzle changes repaint only their pages.
	var world: Node = await ENTRY.open(self,true)
	if world == null:return
	var surface: RefCounted = world.art_layers[0].surface
	surface.pages.clear()
	var started := Time.get_ticks_msec()
	var total := 0
	var count := 0
	# The Mill opens conditional floors for the rest of the story, so both states are baked.
	for open in [false,true]:
		world.models[0].science_open = open
		var wanted: Dictionary = surface.current_signatures()
		for page in wanted:
			if not surface.record(page,wanted[page]).is_empty():continue
			total += surface.bake_page(page,wanted[page]).image.size()
			count += 1
	world.models[0].science_open = false
	var path: String = surface.bake_path()
	if ResourceSaver.save(surface.bake_resource(),path,ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("Cannot save "+path)
		quit(1)
		return
	var stats := {"pages":count,"image_bytes":total,"build_ms":Time.get_ticks_msec()-started}
	print("BAKE ",path," ",stats)
	var outputs := [{"file":path.get_file(),"signature":surface.bake_signature(),"sha256":FileAccess.get_sha256(path),"stats":stats},
		{"file":"tiles.res","sha256":FileAccess.get_sha256(SURFACE.BAKE_DIR+"tiles.res")}]
	var file := FileAccess.open(SURFACE.BAKE_DIR+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":SURFACE.BAKE_VERSION,"source":"World/CampaignWorld.tscn","builder":"tools/world/terrain_bake/bake.gd","outputs":outputs},"\t"))
	file.close()
	quit()
