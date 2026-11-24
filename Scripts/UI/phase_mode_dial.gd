extends Control
## Presentation only. Selection adapter supplies preview; center stays committed.
const PROGRESS = preload("res://Scripts/Content/phase_device_progress.gd")
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
const ART := "res://assets/ui/phase_dial/v1/"
const MODES := ["thermal", "cryo", "pressure", "vacuum"]
const NAMES := {"thermal":"Thermal", "cryo":"Cryo", "pressure":"Pressure", "vacuum":"Vacuum"}
const UNLOCKS := {"thermal":"Z1L1", "cryo":"Z1L3", "pressure":"Z3L3", "vacuum":"Z3L1"}
const COLORS := {"thermal":Color("e6a34a"), "cryo":Color("80cce8"), "pressure":Color("b8a0dc"), "vacuum":Color("72c5b9")}
const ICON_AT := {"thermal":Vector2(128,43), "cryo":Vector2(128,183), "pressure":Vector2(49,110), "vacuum":Vector2(207,110)}
const LABEL_AT := {"thermal":Vector2(128,73), "cryo":Vector2(128,215), "pressure":Vector2(49,140), "vacuum":Vector2(207,140)}
var state: Dictionary = PROGRESS.defaults()
var hovered_mode := ""
var reduced_effects := false
var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
	for mode: String in MODES:
		for variant: String in ["locked", "idle", "hovered", "selected", "icon"]:
			_textures[mode+"_"+variant] = load(ART+mode+"_"+variant+".svg")
	for key: String in ["frame", "center_glow", "lock"]:
		_textures[key] = load(ART+key+".svg")
	queue_redraw()

func present(record: Dictionary, hovered := "", reduce_effects := false) -> void:
	state = PROGRESS.normalize(record)
	hovered_mode = hovered if hovered in MODES else ""
	reduced_effects = reduce_effects
	queue_redraw()

func set_preview(mode: String) -> void:
	var next := mode if mode in MODES else ""
	if next == hovered_mode: return
	hovered_mode = next
	queue_redraw()

func visual_state(mode: String) -> String:
	if not state.unlocked_modes.has(mode): return "locked"
	if state.selected_mode == mode: return "selected"
	return "hovered" if hovered_mode == mode else "idle"

func _text(value: String, at: Vector2, font_size: int, tint: Color) -> void:
	var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(FONT,at-Vector2(width/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	if _textures.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/256.0)
	var bounds := Rect2(0,0,256,256)
	draw_texture_rect(_textures.frame,bounds,false)
	for mode: String in MODES:
		var variant := visual_state(mode)
		draw_texture_rect(_textures[mode+"_"+variant],bounds,false)
		var tint: Color = Color("eee4c9") if variant == "locked" else COLORS[mode]
		if variant == "selected": tint = Color("182b3a")
		var icon: Vector2 = ICON_AT[mode]
		# Icon SVG has 256px canvas and a 36px glyph; keep glyph 29px tall.
		draw_texture_rect(_textures[mode+"_icon"],Rect2(icon-Vector2(102,102),Vector2(204,204)),false,tint)
		var at: Vector2 = LABEL_AT[mode]
		_text(NAMES[mode],at,19 if mode in ["thermal","cryo"] else 18,tint)
		if variant == "locked":
			draw_texture_rect(_textures.lock,Rect2(at+Vector2(-32,5),Vector2(14,14)),false)
			_text(UNLOCKS[mode],at+Vector2(10,19),15,Color("eee4c9"))
		elif variant == "selected":
			_text("EQUIPPED",at+Vector2(0,18),12,Color("182b3a"))
		elif variant == "hovered":
			_text("READY",at+Vector2(0,18),12,Color("fff0c8"))
	# Locked and already-selected wedges also get a preview rim. Center glyph
	# and colored fill continue to represent the durable selected mode only.
	if not hovered_mode.is_empty():
		var angle: float = {"thermal":-PI/2,"cryo":PI/2,"pressure":PI,"vacuum":0.0}[hovered_mode]
		draw_arc(Vector2(128,128),106,angle-deg_to_rad(40),angle+deg_to_rad(40),32,Color("fff5d4"),4,true)
	var selected: String = state.selected_mode
	if not selected.is_empty() and not reduced_effects:
		draw_texture_rect(_textures.center_glow,bounds,false,COLORS[selected])
	draw_circle(Vector2(128,128),30,Color("172b3b"))
	draw_arc(Vector2(128,128),30,0,TAU,64,Color("d7bc7e"),3,true)
	if not selected.is_empty():
		draw_circle(Vector2(128,128),23,Color(COLORS[selected],0.18 if reduced_effects else 0.38))
		draw_texture_rect(_textures[selected+"_icon"],Rect2(32,32,192,192),false,COLORS[selected])
	else:
		draw_texture_rect(_textures.lock,Rect2(115,113,26,26),false)
