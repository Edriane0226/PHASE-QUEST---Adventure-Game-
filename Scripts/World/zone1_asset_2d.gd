@tool
extends Node2D
## Opt-in art only. Texture state never grants interaction, progress or support.
const BASE := "res://assets/zones/zone_1/world_v1/"
@export var asset_id := "snow_tree_young":
	set(value):
		asset_id=value
		if is_inside_tree(): configure(value)
var definition: Dictionary={}

static func catalog_entries() -> Array:
	var file:=FileAccess.open(BASE+"kit_catalog.json",FileAccess.READ)
	if file==null: return []
	var parsed: Variant=JSON.parse_string(file.get_as_text())
	return parsed.get("entries",[]) if parsed is Dictionary else []

func _ready() -> void:
	configure(asset_id)

func configure(id: String) -> bool:
	var selected: Dictionary={}
	for row: Dictionary in catalog_entries():
		if row.id==id: selected=row; break
	if selected.is_empty(): return false
	var texture: Texture2D
	if ResourceLoader.exists(BASE+"kit_atlas.tres"):
		texture=load(BASE+"kit_atlas.tres").get_meta("tiles",{}).get(id)
	if texture==null: texture=load(str(selected.path)) as Texture2D
	if texture==null: return false
	var art:=get_node_or_null("Art") as Sprite2D
	if art==null: art=Sprite2D.new(); art.name="Art"; add_child(art)
	art.texture=texture; art.centered=false
	art.scale=Vector2.ONE*float(selected.world_scale)
	art.position=-Vector2(selected.pivot_px[0],selected.pivot_px[1])*float(selected.world_scale)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	definition=selected
	return true
