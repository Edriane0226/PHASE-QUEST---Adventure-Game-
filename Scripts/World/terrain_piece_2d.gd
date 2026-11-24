@tool
extends Node2D
## Opt-in terrain asset + geometry. No campaign state, player ownership or unlock logic.
const PROFILES = preload("res://Scripts/World/terrain_support_profiles.gd")
const CATALOG := "res://assets/world/shared_terrain/v1/terrain_catalog.json"
const CAVE_CATALOG := "res://assets/world/shared_terrain/v1/cave_catalog.json"
const ATLAS := "res://assets/world/shared_terrain/v1/terrain_atlas.tres"
static var _atlas: Resource
@export var asset_id := "grass_tile_e0_h20"
@export var support_elevation := 0.0
@export var support_active := true
var entry: Dictionary = {}
var profile_id := ""
var geometry: Node2D
var visuals: Node2D
var _enabled := true

func _ready() -> void:
	configure(asset_id,support_elevation)

static func catalog_entries() -> Array:
	var entries: Array = []
	for path in [CATALOG,CAVE_CATALOG]:
		if not FileAccess.file_exists(path): continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary: entries.append_array(data.get("entries",[]))
	return entries

func configure(id: String, elevation := 0.0) -> bool:
	var candidate: Dictionary = {}
	for item: Dictionary in catalog_entries():
		if item.get("id") == id: candidate=item; break
	if candidate.is_empty() or PROFILES.definition(str(candidate.get("profile_id",""))).is_empty(): return false
	if _atlas==null and FileAccess.file_exists(ATLAS): _atlas=load(ATLAS)
	var texture: Texture2D = _atlas.get_meta("tiles",{}).get(id) if _atlas else null
	if texture==null: texture=load(str(candidate.path)) as Texture2D
	if texture == null: return false
	for owned in [visuals,geometry]:
		if is_instance_valid(owned): remove_child(owned); owned.free()
	asset_id=id; support_elevation=elevation; entry=candidate
	profile_id=str(entry.profile_id)
	visuals=Node2D.new(); visuals.name="Visuals"; visuals.position.y=-elevation; add_child(visuals)
	if entry.get("shadow_path","")!="":
		var shadow:=Sprite2D.new();shadow.texture=load(str(entry.shadow_path));shadow.position=Vector2(12,10);visuals.add_child(shadow)
	var sprite:=Sprite2D.new(); sprite.name="Artwork"; sprite.centered=false
	sprite.texture=texture; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale=Vector2.ONE*float(entry.world_scale)
	sprite.position=-Vector2(float(entry.pivot_px[0]),float(entry.pivot_px[1]))*sprite.scale
	if entry.get("material_shader","") != "":
		var material:=ShaderMaterial.new(); material.shader=load(str(entry.material_shader)); sprite.material=material
	visuals.add_child(sprite)
	geometry=Node2D.new(); geometry.name="Geometry"; add_child(geometry)
	var support:=Polygon2D.new(); support.name="WalkableSurface"; support.visible=false
	support.polygon=PROFILES.polygon_for(profile_id); support.set_meta("support_elevation",elevation); geometry.add_child(support)
	var spec:=PROFILES.definition(profile_id)
	var polygons:=PROFILES.collision_polygons(profile_id,int(entry.get("edge_mask",0)))
	if not polygons.is_empty():
		var body:=StaticBody2D.new(); body.name="BlockingBody"; body.collision_layer=int(spec.get("layer",1)); body.collision_mask=4; geometry.add_child(body)
		for polygon: PackedVector2Array in polygons:
			var shape:=CollisionPolygon2D.new(); shape.polygon=polygon; body.add_child(shape)
	_enabled=true
	return true

func surface_record() -> Dictionary:
	var record:=PROFILES.support_record(profile_id,position,support_elevation,_enabled)
	record.support_active=record.support_active and support_active
	return record

func height_at_local(point: Vector2) -> float:
	return PROFILES.height_at(profile_id,point,Vector2.ZERO,support_elevation)

func request_active(active: bool, occupied := false) -> bool:
	if not PROFILES.surface_change_allowed(profile_id,occupied,active,_enabled): return false
	_enabled=active
	if is_instance_valid(geometry):
		var body:=geometry.get_node_or_null("BlockingBody") as StaticBody2D
		if body: body.set_deferred("collision_layer",int(PROFILES.definition(profile_id).get("layer",1)) if active else 0)
	return true
