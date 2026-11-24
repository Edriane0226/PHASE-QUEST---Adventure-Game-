extends Control
## Provider-owned map/fog textures. No discovery, travel or unlock authority here.
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const MARKER=preload("res://assets/ui/hud/r3_v1/player_marker.svg")
const MASK=preload("res://assets/ui/hud/r3_v1/minimap_mask.gdshader")
var map_view: TextureRect
var record: Dictionary={}
var visible_markers:=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	map_view=TextureRect.new();map_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;map_view.stretch_mode=TextureRect.STRETCH_SCALE
	var shader:=ShaderMaterial.new();shader.shader=MASK;map_view.material=shader
	add_child(map_view);map_view.show_behind_parent=true
	resized.connect(_layout);_layout()

func _layout() -> void:
	if not is_instance_valid(map_view):return
	map_view.position=Vector2.ONE*7;map_view.size=size-Vector2.ONE*14;queue_redraw()

func present(value: Dictionary) -> void:
	record=value.duplicate();map_view.texture=value.get("texture")
	map_view.material.set_shader_parameter("has_fog",value.get("fog") is Texture2D)
	if value.get("fog") is Texture2D:map_view.material.set_shader_parameter("fog_texture",value.fog)
	queue_redraw()

func _draw() -> void:
	var center:=size/2;var radius:=size.x/2-4
	if not record.get("texture") is Texture2D:
		draw_circle(center,radius,Color("334c3d"));var caption:="Uncharted";var px:=12
		draw_string(FONT,center+Vector2(-FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x/2,18),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color("e9e9d5"))
	draw_arc(center,radius,0,TAU,96,Color("263c2d"),7,true);draw_arc(center,radius,0,TAU,96,Color("dce5ca"),2,true);draw_arc(center,radius-5,0,TAU,96,Color("8fa582"),1,true)
	draw_string_outline(FONT,Vector2(center.x-5,17),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color("263c2d"));draw_string(FONT,Vector2(center.x-5,17),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff5d8"))
	visible_markers=0
	for marker: Dictionary in record.get("markers",[]):
		var p: Vector2=marker.get("position",Vector2(2,2))
		if not marker.get("discovered",false) or not p.is_finite() or p.length()>.80:continue
		visible_markers+=1;var at:=center+p*(radius-8)
		draw_circle(at,3,Color("1d3328"));draw_circle(at,2,Color("f4df9a"))
	var angle:=float(record.get("heading",0.0));draw_set_transform(center,angle,Vector2.ONE)
	draw_texture_rect(MARKER,Rect2(-9,-9,18,18),false)
	draw_set_transform(Vector2.ZERO)
