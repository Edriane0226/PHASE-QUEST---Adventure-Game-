extends Control
## Disposable visual simulation: no PlayerSave, world, live target or commit API.
signal narrated(text: String)
const EXPOSURE=preload("res://Scripts/World/phase_device_exposure.gd")
var topic:="melting"
var playing:=true
var elapsed:=0.0
var simulation=EXPOSURE.new()
var textures: Dictionary={}
var _caption:=""
func _ready() -> void:
	custom_minimum_size=Vector2(0,220);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_1/world_v1/kit_catalog.json"))
	for entry in catalog.entries:
		if entry.id.begins_with("gear_") or entry.id.begins_with("bell_") or entry.id.begins_with("load_gauge_"):textures[entry.id]=load(entry.path)
	replay()
func replay() -> void:
	elapsed=0;playing=true;simulation.configure({"id":"mill_guide_only","zone":"melting_and_freezing","level":2,"material":"water","process":"melting","allowed_modes":["thermal"],"required_exposure":4.0,"max_range":100.0,"required_flags":[]});queue_redraw()
func toggle_playback() -> void:playing=not playing
func _process(delta: float) -> void:
	if not playing:return
	elapsed+=delta
	if elapsed>=12:replay()
	if topic=="melting" and elapsed>=2 and simulation.outcome().is_empty():
		simulation.advance(minf(delta,elapsed-2),"thermal",{"version":1,"unlocked_modes":{"thermal":true},"learned_capabilities":{"melting":true},"selected_mode":"thermal"},{"material":"water","state":"solid","amount":1.0,"phase_region":"melting","heat_flow":"in"},{})
	var caption:=""
	if topic=="resonance":caption="Ring LOW → MIDDLE → HIGH. Vibration fractures the bridge ice; no melting evidence."
	elif topic=="balance":caption="Heavy 3 + light 2 = load 5. Raise lift, lower return bridge, carry brake pin. No phase change."
	else:caption="Select Thermal; aim; hold Fire for four valid seconds. Ice becomes liquid water; metal stays solid. Match its tray."
	if caption!=_caption:_caption=caption;narrated.emit(caption)
	queue_redraw()
func _texture(id: String,at: Vector2,extent:=Vector2(130,130)) -> void:
	if not textures.has(id):return
	draw_texture_rect(textures[id],Rect2(at,extent),false)
func _draw() -> void:
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	if topic=="resonance":
		for i in range(3):_texture(["bell_low","bell_mid","bell_high"][i]+("_played" if elapsed>i+1 else "_idle"),Vector2(size.x*(.1+i*.28),25),Vector2(110,150))
	elif topic=="balance":_texture("load_gauge_%d"%mini(5,int(elapsed)),Vector2(size.x*.5-80,12),Vector2(160,185))
	else:
		var frame:=3 if not simulation.outcome().is_empty() else mini(2,int(simulation.exposure()))
		_texture("gear_thaw_%d"%frame,Vector2(size.x*.15,10),Vector2(150,170))
		_texture("gear_tray_occupied" if elapsed>=8 else "gear_tray_empty",Vector2(size.x*.6,40),Vector2(125,145))
		draw_line(Vector2(size.x*.48,95),Vector2(size.x*.56,95),Color("b26d32"),4)
func _panel() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("e5e8dc");style.set_corner_radius_all(8);return style
