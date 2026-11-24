extends Control
## Pure disposable preview. No live store, targets, support or rewards.
signal narrated(text: String)
const EXPOSURE=preload("res://Scripts/World/phase_device_exposure.gd")
const PARTS=preload("res://Scripts/World/Zone1/stillwater_assembly.gd")
var topic:="freezing"
var elapsed:=0.0
var playing:=true
var simulation=EXPOSURE.new()
var _caption:=""
func _ready() -> void:custom_minimum_size=Vector2(0,220);replay()
func replay() -> void:
	elapsed=0;playing=true
	simulation.configure({"id":"stillwater_preview","zone":"melting_and_freezing","level":3,"material":"water","process":"melting" if topic=="melting" else "freezing","allowed_modes":["thermal" if topic=="melting" else "cryo"],"required_exposure":3.0,"max_range":100.0,"required_flags":[]});queue_redraw()
func toggle_playback() -> void:playing=not playing
func _process(delta: float) -> void:
	if not playing:return
	elapsed+=delta
	if elapsed>10:replay()
	var melt: bool=topic=="melting";var mode: String="thermal" if melt else "cryo";var process: String="melting" if melt else "freezing"
	if elapsed>2 and simulation.outcome().is_empty():simulation.advance(delta,mode,{"version":1,"unlocked_modes":{mode:true},"learned_capabilities":{process:true},"selected_mode":mode},{"material":"water","state":"solid" if melt else "liquid","amount":1.0,"phase_region":process,"heat_flow":"in" if melt else "out"},{})
	var caption: String="Thermal adds heat: ice → liquid water. Open supply valve to fill the empty trays." if melt else "Filled water loses heat: liquid → solid ice. Empty trays make no ice. Disconnect heater, freeze both, operate latch."
	if _caption!=caption:_caption=caption;narrated.emit(caption)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("dce5df"))
	var solid: bool=not simulation.outcome().is_empty();var melt: bool=topic=="melting"
	var id: String=("supply_liquid" if solid else "supply_solid") if melt else ("cooling_tray_latched" if solid else ("cooling_tray_freezing" if simulation.exposure()>0 else "cooling_tray_liquid"))
	draw_texture_rect(load(PARTS.visual(id).path),Rect2(size.x*.5-85,10,170,190),false)
	var from:=Vector2(size.x*.5+25,70);var to:=from+Vector2(65,0)
	if melt:var swap:=from;from=to;to=swap
	draw_line(from,to,Color("be783d") if melt else Color("398aaa"),4);draw_line(to,to+Vector2(-12,-8) if not melt else to+Vector2(12,-8),Color("be783d") if melt else Color("398aaa"),4)
