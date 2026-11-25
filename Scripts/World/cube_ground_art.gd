extends Node2D
## Shows the painted ground around the camera: open water, shore water and page images.
## Pages come from the bake. A page whose floors changed is painted again, a little per frame.
const SURFACE = preload("res://Scripts/World/cube_surface.gd")
const WATER_SHADER = preload("res://assets/shaders/world/pixel_water.gdshader")
const BIOMES := ["snow","grass","lab"]
const FRAME_SECONDS := 0.18
const KEEP := 600.0
const AHEAD := 300.0
const PAINT_USEC := 6000
var biome := "grass"
var surface = SURFACE.new()
var routes: Array = []:
	set(value):
		routes = value
		if not surface.models.is_empty():
			surface.set_routes(0,value)
			queue_refresh()
var _wanted: Dictionary = {}
var _shown: Dictionary = {}
var _job: Dictionary = {}
var _sea: Sprite2D
var _sea_textures: Array = []
var _water_material: ShaderMaterial
var _water_texture: ImageTexture
var _clock := 0.0
var _frame := -1
var _refresh_due := false
## Reduced Effects: the water holds its first frame.
var still := false
var _profile: Node

func configure(value: RefCounted, _mainland: Array = []) -> void:
	configure_all([value],[biome],[routes])

## All zones in one painter, so borders blend and nearer ground covers farther ground.
func configure_all(models: Array, biomes: Array, all_routes: Array) -> void:
	z_index = -100
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.configure(models,biomes)
	for i in models.size(): surface.set_routes(i,all_routes[i])
	for child in get_children(): child.free()
	_shown.clear(); _job.clear()
	_sea_textures.clear()
	for image in SURFACE.sea_frames(): _sea_textures.append(ImageTexture.create_from_image(image))
	_sea = Sprite2D.new(); _sea.name = "Sea"; _sea.centered = false; _sea.region_enabled = true
	_sea.texture = _sea_textures[0]; _sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED; _sea.z_index = -1
	add_child(_sea)
	_water_texture = ImageTexture.create_from_image(SURFACE.water_atlas())
	_water_material = ShaderMaterial.new(); _water_material.shader = WATER_SHADER
	# Districts still change their floors while they bind, so the first look waits for the first frame.
	_wanted.clear()
	queue_refresh()

## The world asks for a redraw after it applied permissions, so floors may have changed.
func _draw() -> void:
	queue_refresh()

func queue_refresh() -> void:
	_refresh_due = true

## Called when floors may have changed. Only pages with other floors are dropped.
func refresh_now() -> void:
	_refresh_due = false
	_wanted = surface.refresh()
	_job.clear()
	# A changed page stays on screen until its new painting is ready.
	for page in _shown.keys():
		if not _wanted.has(page): _hide(page)
		else: _shown[page].stale = _shown[page].signature != _wanted[page]

func follow_effects(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(_read_effects)
	profile.restored.connect(_read_effects)
	_read_effects()

func _read_effects() -> void:
	still = bool(_profile.data.extras.get("level1_reduced_effects",false))
	if still: _clock = 0.0

func view() -> Rect2:
	var inverse := get_canvas_transform().affine_inverse()
	return inverse*Rect2(Vector2.ZERO,get_viewport_rect().size)

func _process(delta: float) -> void:
	if surface.models.is_empty() or not is_visible_in_tree(): return
	if _refresh_due: refresh_now()
	var seen := view()
	_show_pages(seen)
	if not still: _clock += delta
	var frame := int(_clock/FRAME_SECONDS)%4
	if frame != _frame:
		_frame = frame
		_sea.texture = _sea_textures[frame]
		_water_material.set_shader_parameter("frame",frame)
	var start := Vector2(floorf(seen.position.x/320.0)*320.0,floorf(seen.position.y/160.0)*160.0)
	_sea.position = start
	_sea.region_rect = Rect2(Vector2.ZERO,Vector2(ceilf((seen.end.x-start.x)/320.0)*320.0,ceilf((seen.end.y-start.y)/160.0)*160.0))

func _pages_in(area: Rect2) -> Array:
	var result: Array = []
	for x in range(floori(area.position.x/SURFACE.PAGE.x),floori(area.end.x/SURFACE.PAGE.x)+1):
		for y in range(floori(area.position.y/SURFACE.PAGE.y),floori(area.end.y/SURFACE.PAGE.y)+1):
			if _wanted.has(Vector2i(x,y)): result.append(Vector2i(x,y))
	return result

func _show_pages(seen: Rect2) -> void:
	# On screen now: must be there this frame.
	for page in _pages_in(seen):
		if not _shown.has(page): _show(page,true)
	# Just outside: at most one step per frame.
	for page in _pages_in(seen)+_pages_in(seen.grow(AHEAD)):
		if not _shown.has(page) or _shown[page].stale: _show(page,false); break
	if _job.has("page") and not _wanted.has(_job.page): _job = {}
	var far := seen.grow(KEEP)
	for page in _shown.keys():
		if not far.intersects(Rect2(Vector2(page*SURFACE.PAGE),Vector2(SURFACE.PAGE))): _hide(page)

func _show(page: Vector2i, now: bool) -> void:
	var record: Dictionary = surface.record(page,_wanted[page])
	if record.is_empty():
		# No bake for these floors. A page painted here lives only while it is near.
		if _job.get("page") != page: _job = surface.begin(page)
		if not surface.advance(_job,60000000 if now else PAINT_USEC): return
		record = _job
		_job = {}
	var node := Node2D.new()
	node.name = "Page_%d_%d" % [page.x,page.y]
	if not record.water.is_empty(): node.add_child(_water_mesh(record.water))
	var image: Image = record.image if record.image is Image else Image.new()
	if record.image is PackedByteArray and not record.image.is_empty(): image.load_webp_from_buffer(record.image)
	if not image.is_empty():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.position = Vector2(page*SURFACE.PAGE)
		sprite.z_index = 1
		node.add_child(sprite)
	add_child(node)
	if _shown.has(page): _hide(page)
	_shown[page] = {"node":node,"signature":_wanted[page],"stale":false}

func _hide(page: Vector2i) -> void:
	_shown[page].node.queue_free()
	_shown.erase(page)

func _water_mesh(list: PackedInt32Array) -> MeshInstance2D:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var phase := PackedColorArray()
	var indices := PackedInt32Array()
	var size := Vector2(160,400)
	for i in range(0,list.size(),4):
		var n := points.size()
		var at := Vector2(list[i],list[i+1])
		var uv := Vector2(0,list[i+2]*20)
		for c in [Vector2(0,0),Vector2(40,0),Vector2(40,20),Vector2(0,20)]:
			points.append(at+c); uvs.append((uv+c)/size); phase.append(Color(list[i+3]/4.0,0,0,1))
		indices.append_array(PackedInt32Array([n,n+1,n+2,n,n+2,n+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = phase
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance2D.new()
	node.mesh = mesh
	node.texture = _water_texture
	node.material = _water_material
	return node
