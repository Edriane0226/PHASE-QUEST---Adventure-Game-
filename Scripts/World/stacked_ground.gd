extends Node2D
## Filled isometric columns. Each physical height level owns one TileMapLayer.
const RELIEF = preload("res://Scripts/World/terrain_relief.gd")
const PALETTE = preload("res://Scripts/World/terrain_palette.gd")
var layers: Array[TileMapLayer] = []
var field: RefCounted
var region_id := ""
var max_height := 0
static var _tilesets: Dictionary = {}

func configure(value: RefCounted, id: String, biome: String, base: float) -> void:
	for child in get_children(): child.free()
	layers.clear(); field = value; region_id = id
	# Godot's diamond grid begins at half a tile; align artwork to logical XY.
	position = -Vector2(RELIEF.TILE_SIZE)/2
	max_height=0
	for cell: Vector2i in field.regions.get(id,[]):
		var column: Dictionary=field.columns[cell]
		max_height=maxi(max_height,roundi(float(column.base)/RELIEF.CUBE_STEP_PX)+int(column.height))
	var tiles: TileSet = _tilesets.get(biome)
	if tiles == null:
		tiles = _make_tileset(biome)
		_tilesets[biome] = tiles
	for z in range(max_height+1):
		var layer := TileMapLayer.new()
		layer.name = "Cubes_z%d" % z
		layer.tile_set = tiles
		layer.position.y = -z*RELIEF.CUBE_STEP_PX
		layer.collision_enabled = false
		layer.navigation_enabled = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(layer); layers.append(layer)
	for cell: Vector2i in field.regions.get(id,[]):
		var column: Dictionary = field.columns[cell]
		var base_steps:=roundi(float(column.base)/RELIEF.CUBE_STEP_PX)
		for z in range(base_steps+int(column.height)+1):
			var mask := 0
			for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
				var neighbor: Dictionary = field.columns.get(cell+direction,{})
				var top := roundi(float(neighbor.get("base",field.foundations.get(cell+direction,-20.0)))/RELIEF.CUBE_STEP_PX)+int(neighbor.get("height",0))
				if top < z: mask |= 2 if direction==Vector2i.RIGHT else 4
			layers[z].set_cell(cell,mask,Vector2i.ZERO)

func _make_tileset(biome: String) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = RELIEF.TILE_SIZE
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	# One 20px cube unit: 40x20 isometric cap, exactly 20px side height. No strokes.
	for mask in range(16):
		var faces:=""
		if mask&4:faces+='<polygon points="12,32 32,42 32,62 12,52" fill="#%s"/>'%PALETTE.LEFT[biome].to_html(false)
		if mask&2:faces+='<polygon points="52,32 32,42 32,62 52,52" fill="#%s"/>'%PALETTE.RIGHT[biome].to_html(false)
		# Same-color subpixel bleed closes raster seams; no contrasting edge/stroke.
		faces+='<polygon points="32,21.5 52.5,32 32,42.5 11.5,32" fill="#%s"/>'%PALETTE.top(biome).to_html(false)
		var image:=Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">%s</svg>'%faces)
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(image)
		source.texture_region_size = Vector2i(64,64)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source,mask)
	return tiles
