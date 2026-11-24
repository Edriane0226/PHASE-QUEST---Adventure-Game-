extends Control
## Provider chooses one region. No saved-zone lookup, rotation, discovery or simulation here.
var entries: Dictionary={}
var current_region:=""
var variant:="static"
var reduced_motion:=true
var clock:=0.0
var textures: Dictionary={}
var fallback:=true
var _focused:=true
var _suspended:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var path:="res://assets/ui/main_menu/r3_v1/regions.json"
	if FileAccess.file_exists(path):
		var record: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if record is Dictionary and record.get("regions") is Dictionary:entries=record.regions
	resized.connect(queue_redraw)

func present(region: String,reduce:=true,mode:="static",missing:=false) -> void:
	current_region=region if entries.has(region) else "";reduced_motion=reduce;variant=mode if mode in ["static","layered"] else "static";clock=0
	textures.clear();fallback=current_region.is_empty() or missing
	if not fallback:
		var value: Variant=entries[current_region]
		if not value is Dictionary:fallback=true;queue_redraw();return
		var entry: Dictionary=value
		for key: String in (["static"] if variant=="static" else ["painting","veil","atmosphere"]):
			if not entry.get(key) is String or not ResourceLoader.exists(entry[key]):fallback=true;break
			var texture=load(entry[key])
			if not texture is Texture2D or texture.get_width()<=0 or texture.get_height()<=0:fallback=true;break
			textures[key]=texture
	if fallback:textures.clear()
	queue_redraw()

func cover(texture: Texture2D,offset:=Vector2.ZERO) -> void:
	var factor:=maxf(size.x/texture.get_width(),size.y/texture.get_height());var extent:=texture.get_size()*factor
	draw_texture_rect(texture,Rect2((size-extent)/2+offset,extent),false)

func _draw() -> void:
	if fallback:
		draw_rect(Rect2(Vector2.ZERO,size),Color("243c3e"))
		for i in 5:
			var y:=size.y*(.58+i*.07)
			draw_colored_polygon(PackedVector2Array([Vector2(0,y),Vector2(size.x*.28,y-size.y*.05),Vector2(size.x*.58,y+size.y*.01),Vector2(size.x,y-size.y*.04),size,Vector2(0,size.y)]),Color(.07+i*.012,.12+i*.016,.13+i*.016))
	elif variant=="static":cover(textures.static)
	else:
		cover(textures.painting);cover(textures.veil)
		cover(textures.atmosphere,Vector2(0 if reduced_motion else sin(clock/18.0)*size.x*.004,0))

func _process(delta: float) -> void:
	if is_visible_in_tree() and not fallback and variant=="layered" and not reduced_motion and _focused and not _suspended and not get_tree().paused:
		clock+=minf(delta,.05);queue_redraw()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_focused=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:_suspended=true
	elif what==NOTIFICATION_APPLICATION_RESUMED:_suspended=false
