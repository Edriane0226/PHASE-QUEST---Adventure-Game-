@tool
extends Node2D
## Opt-in catalog art. No input, science predicates, permissions, saves or physics.
@export_file("*.json") var catalog_path: String
@export_file("*.tres") var atlas_path: String
@export var asset_id: String:
	set(value):
		asset_id=value
		if is_inside_tree(): configure(value)
var definition: Dictionary={}

static func read_catalog(path: String) -> Array:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return []
	var parsed: Variant=JSON.parse_string(file.get_as_text())
	return parsed.get("entries",[]) if parsed is Dictionary else []

func _ready() -> void: configure(asset_id)

func configure(id: String) -> bool:
	var selected: Dictionary={}
	for row: Dictionary in read_catalog(catalog_path):
		if row.id==id: selected=row;break
	if selected.is_empty(): return false
	var texture: Texture2D
	if not atlas_path.is_empty() and ResourceLoader.exists(atlas_path):
		texture=load(atlas_path).get_meta("tiles",{}).get(id)
	if texture==null:texture=load(str(selected.path)) as Texture2D
	if texture==null:return false
	var art:=get_node_or_null("Art") as Sprite2D
	if art==null:art=Sprite2D.new();art.name="Art";add_child(art)
	art.texture=texture;art.centered=false
	art.scale=Vector2.ONE*float(selected.world_scale)
	art.position=-Vector2(selected.pivot_px[0],selected.pivot_px[1])*float(selected.world_scale)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	definition=selected
	return true
