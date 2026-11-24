extends Control
const FONT = preload("res://Scripts/UI/quest_ui.gd").FONT
const FACTS := [
	["Melting", "Melting is a phase change from solid to liquid when a substance gains heat. An ice cube melts into liquid water."],
	["Freezing", "Freezing is a phase change from liquid to solid when a substance loses heat. Water freezes into ice."],
	["Vaporization", "Vaporization changes a liquid into a gas as it gains heat. Evaporation happens at the surface; boiling happens throughout the liquid."],
	["Condensation", "Condensation changes a gas into a liquid when it loses heat. Water vapor forms droplets on the outside of a cold glass."],
	["Sublimation", "Sublimation changes a solid directly into a gas without becoming a liquid. Dry ice changes into carbon dioxide gas."],
	["Deposition", "Deposition changes a gas directly into a solid without becoming a liquid. Water vapor can form frost on a very cold surface."]
]
const NAMES := ["MELTING", "FREEZING", "VAPORIZATION", "CONDENSATION", "SUBLIMATION", "DEPOSITION"]
var learning := true
var fact_index := 0
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func text_center(value: String, y: float, font_size: int, ink: Color) -> void:
	draw_string(FONT,Vector2((size.x-FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)/2,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)

func symbol(at: Vector2, index: int, radius: float, ink: Color) -> void:
	# Particle arrangements show the actual state before and after each phase change.
	var from_state: int = [0,1,1,2,0,2][index]
	var to_state: int = [1,0,2,1,2,0][index]
	for side in range(2):
		var state: int = from_state if side==0 else to_state
		var center := at+Vector2(-radius*0.65 if side==0 else radius*0.65,0)
		for particle in range(4):
			var spacing := radius*(0.16 if state==0 else (0.25 if state==1 else 0.36))
			var offset := Vector2((particle%2-0.5)*spacing*2,(particle/2-0.5)*spacing*2)
			if state==1:
				offset.x += spacing*0.4 if particle>1 else 0.0
			draw_circle(center+offset,maxf(2,radius*0.065),ink)
	draw_line(at+Vector2(-radius*0.2,0),at+Vector2(radius*0.2,0),ink,1.5,true)
	draw_line(at+Vector2(radius*0.08,-radius*0.12),at+Vector2(radius*0.2,0),ink,1.5,true)
	draw_line(at+Vector2(radius*0.08,radius*0.12),at+Vector2(radius*0.2,0),ink,1.5,true)

func _draw() -> void:
	if not learning:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.08,0.10,0.12,0.12))
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color("101f2b"))
	var ink := Color("e8e5d8")
	var muted := Color("8faeb9")
	var gold := Color("e5bb73")
	var scale_factor := clampf(minf(size.x/1000.0,size.y/600.0),0.55,1.5)
	# Quiet constellation field and glacial contours make this a Phase Quest journey.
	for i in range(48):
		var at := Vector2(fposmod(i*137.3+37,size.x),fposmod(i*83.7+19,size.y*0.65))
		draw_circle(at,0.8 if i%3 else 1.4,Color(0.7,0.85,0.9,0.10+float(i%4)*0.035))
	for ridge in range(3):
		var points := PackedVector2Array()
		for i in range(25):
			var x := size.x*i/24.0
			var y := size.y*(0.87+ridge*0.045)-sin(i*0.42+ridge*1.5)*size.y*0.035
			points.append(Vector2(x,y))
		draw_polyline(points,Color(0.35,0.57,0.65,0.12),1.0,true)
	text_center("P H A S E   Q U E S T",size.y*0.13,roundi(15*scale_factor),gold)
	var center := Vector2(size.x/2,size.y*0.39)
	var radius := 70*scale_factor
	for ring in range(4):
		draw_circle(center,radius*(1.65-ring*0.16),Color(0.22,0.51,0.61,0.014))
	draw_arc(center,radius*1.24,0,TAU,96,Color("294553"),2,true)
	if progress>0:
		draw_arc(center,radius*1.24,-PI/2,-PI/2+TAU*progress,96,gold,2.2,true)
	var crest := PackedVector2Array()
	for i in range(7):
		crest.append(center+Vector2.from_angle(-PI/2+i*TAU/6)*radius)
	draw_polyline(crest,Color("6e9eae"),1.5,true)
	symbol(center,fact_index,44*scale_factor,ink)
	for i in range(6):
		var at := center+Vector2.from_angle(-PI/2+i*TAU/6)*radius*1.24
		draw_circle(at,3.2*scale_factor,gold if progress>=float(i+1)/6 else Color("405a65"))
	text_center("FIELD NOTES  /  %02d"%(fact_index+1),size.y*0.62,roundi(12*scale_factor),gold)
	text_center(FACTS[fact_index][0],size.y*0.68,roundi(27*scale_factor),ink)
	var paragraph := TextParagraph.new()
	paragraph.width = minf(size.x-48,640*scale_factor)
	paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
	paragraph.add_string(FACTS[fact_index][1],FONT,roundi(16*scale_factor))
	paragraph.draw(get_canvas_item(),Vector2((size.x-paragraph.width)/2,size.y*0.72),muted)
	text_center("Preparing your next discovery",size.y*0.94,roundi(12*scale_factor),muted)

