extends Node2D
## Read-only atmosphere/minimap projection. Neither texture nor discovery can authorize access.
const DISCOVERY=preload("res://Scripts/World/Navigation/world_discovery.gd")
var world: Node
var owners: Array=[]
var permission_image: Image
var discovery_image: Image
var permission_texture: ImageTexture
var discovery_texture: ImageTexture
var height_texture: ImageTexture
var elapsed:=0.0
var policy_revision:=-1
var discovery_revision:=-1
var map_position:=Vector2(INF,INF)
var map_revision:=-1
var map_texture: ImageTexture
var map_fog: ImageTexture
var markers: Array=[]
var clock:=0.0
func bind(host: Node) -> void:
	world=host;z_index=1000;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	permission_image=Image.create(DISCOVERY.SIZE.x,DISCOVERY.SIZE.y,false,Image.FORMAT_RGBA8)
	discovery_image=Image.create(DISCOVERY.SIZE.x,DISCOVERY.SIZE.y,false,Image.FORMAT_RGBA8)
	var heights:=Image.create(DISCOVERY.SIZE.x,DISCOVERY.SIZE.y,false,Image.FORMAT_RGBA8)
	for y in range(DISCOVERY.SIZE.y):
		for x in range(DISCOVERY.SIZE.x):
			var at: Vector2=world.discovery.center(Vector2i(x,y));owners.append(world.access.region_at(at))
			heights.set_pixel(x,y,Color(world.geometry.height_mainland(at)/400.0,0,0,1))
	permission_texture=ImageTexture.create_from_image(permission_image);discovery_texture=ImageTexture.create_from_image(discovery_image);height_texture=ImageTexture.create_from_image(heights)
	var shader:=ShaderMaterial.new();shader.shader=preload("res://assets/shaders/world/navigation_fog.gdshader")
	shader.set_shader_parameter("permissions",permission_texture);shader.set_shader_parameter("discovered",discovery_texture);shader.set_shader_parameter("heights",height_texture)
	shader.set_shader_parameter("clouds",preload("res://assets/zones/zone_1/storybook/map_cloud.png"));material=shader
	refresh_masks();queue_redraw()
func refresh_masks() -> void:
	if world==null or policy_revision==world.access.revision and discovery_revision==world.discovery.revision:return
	for y in range(DISCOVERY.SIZE.y):
		for x in range(DISCOVERY.SIZE.x):
			var owner: String=owners[y*DISCOVERY.SIZE.x+x];var allowed: bool=world.access.allowed(owner)
			permission_image.set_pixel(x,y,Color(1 if allowed else 0,0 if owner.is_empty() else 1,0,1))
			discovery_image.set_pixel(x,y,Color.WHITE if allowed and world.discovery.cells.has(Vector2i(x,y)) else Color.BLACK)
	permission_texture.update(permission_image);discovery_texture.update(discovery_image)
	policy_revision=world.access.revision;discovery_revision=world.discovery.revision;map_revision=-1
func _draw() -> void:
	if world!=null:draw_rect(Rect2(0,-256,21120,10336),Color.WHITE)
func _process(delta: float) -> void:
	if world==null:return
	if not world.get_node("/root/PlayerSave").data.extras.get("level1_reduced_effects",false):clock+=delta
	material.set_shader_parameter("clock",clock)
	material.set_shader_parameter("player_ground",world.player.position)
	material.set_shader_parameter("reduced_effects",world.get_node("/root/PlayerSave").data.extras.get("level1_reduced_effects",false))
	elapsed+=delta
	if elapsed>=.25:elapsed=0;refresh_masks()
func minimap_state() -> Dictionary:
	var center: Vector2=world.player.position;var radius:=720.0
	if map_revision!=discovery_revision+policy_revision*100000 or center.distance_to(map_position)>16:
		var colors:={"Z1":preload("res://Scripts/World/terrain_palette.gd").top("snow"),"Z2":preload("res://Scripts/World/terrain_palette.gd").top("grass"),"Z3":preload("res://Scripts/World/terrain_palette.gd").top("lab")}
		var map:=Image.create(96,96,false,Image.FORMAT_RGBA8);var fog:=Image.create(96,96,false,Image.FORMAT_RGBA8)
		for y in range(96):
			for x in range(96):
				var at:=center+(Vector2(x+.5,y+.5)/96-Vector2.ONE*.5)*radius*2
				var id: String=world.access.region_at(at);var known: bool=world.access.allowed(id) and world.discovery.known(at)
				var color:=Color("21362e")
				if known:color=colors.get(id.left(2),Color("21362e")) if not world.geometry.height_record(at).is_empty() else Color("749da5")
				map.set_pixel(x,y,color);fog.set_pixel(x,y,Color.WHITE if known else Color.BLACK)
		# Roads are drawn only through independently discovered, currently permitted samples.
		for model in world.models:
			for line in model.data.trails+model.data.local_branches:
				var points: Array=line.get("sampled_points",line.get("points",[]))
				for p in points:
					var at:=Vector2(p[0],p[1]);var pixel:=Vector2i(((at-center)/(radius*2)+Vector2.ONE*.5)*96)
					if pixel.x<0 or pixel.y<0 or pixel.x>=96 or pixel.y>=96:continue
					if world.access.point_allowed(at) and world.discovery.known(at):map.set_pixelv(pixel,Color("c7b890"))
		map_texture=ImageTexture.create_from_image(map);map_fog=ImageTexture.create_from_image(fog);map_position=center
		markers=[]
		for m in world.geometry.models:
			for station in m.data.stations:
				if station.kind not in ["professor","checkpoint","entry","exit"]:continue
				var at: Vector2=m.v(station.ground_xy);var p: Vector2=(at-center)/radius
				if world.access.allowed(station.subregion) and world.discovery.known(at) and p.length()<=.8:markers.append({"id":station.id,"position":p,"discovered":true})
		map_revision=discovery_revision+policy_revision*100000
	var heading: Vector2=world.input_adapter.emitter.FACINGS.get(world.player._facing,Vector2.DOWN)
	return {"texture":map_texture,"fog":map_fog,"markers":markers,"heading":Vector2.UP.angle_to(heading)}
