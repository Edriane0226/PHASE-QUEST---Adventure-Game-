extends Control
## Static labeled particle models. Seven routes, six phase directions; no simulation/unlock.
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const RULES=preload("res://Scripts/Content/phase_transition_rules.gd")
const TITLES={"melting":"Melting","freezing":"Freezing","evaporation":"Evaporation · surface","boiling":"Boiling · throughout liquid","condensation":"Condensation","sublimation":"Controlled sublimation","deposition":"Controlled deposition"}
var process:="melting"
var stage:=0
var large_text:=false
var reduced_motion:=true
var sample_points:=12

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(0,254);resized.connect(queue_redraw)

func present(key: String,step:=0,large:=false,reduce:=true) -> void:
	process=key if RULES.PROCESSES.has(key) else "melting";stage=clampi(step,0,2);large_text=large;reduced_motion=reduce
	custom_minimum_size.y=302 if large else 266;queue_redraw()

func words(text: String,at: Vector2,font_size:=15,color:=Color("26382f")) -> void:
	draw_string(FONT,at,text,HORIZONTAL_ALIGNMENT_CENTER,-1,font_size,color)

func arrow(a: Vector2,b: Vector2,color: Color) -> void:
	draw_line(a,b,color,3,true);var direction:=(b-a).normalized()
	draw_polyline(PackedVector2Array([b-direction*9+direction.orthogonal()*5,b,b-direction*9-direction.orthogonal()*5]),color,3,true)

func particles(state: String,area: Rect2) -> void:
	var outline:=Color("53766f")
	draw_rect(area,Color("edf2e8"));draw_rect(area,outline,false,2)
	if state=="liquid":draw_rect(Rect2(area.position+Vector2(3,area.size.y*.40),Vector2(area.size.x-6,area.size.y*.60-3)),Color("9ac9d0"))
	if state=="solid":draw_rect(area.grow(-8),Color("c9e6ea"),true)
	for i in sample_points:
		var point:=Vector2.ZERO
		if state=="solid":point=Vector2(.25+(i%4)*.16,.27+(i/4)*.23)
		elif state=="liquid":point=[Vector2(.14,.56),Vector2(.32,.52),Vector2(.52,.59),Vector2(.78,.50),Vector2(.22,.74),Vector2(.44,.72),Vector2(.68,.71),Vector2(.88,.76),Vector2(.12,.88),Vector2(.36,.91),Vector2(.59,.90),Vector2(.80,.90)][i]
		else:point=[Vector2(.12,.20),Vector2(.38,.13),Vector2(.61,.28),Vector2(.84,.16),Vector2(.22,.54),Vector2(.49,.42),Vector2(.70,.60),Vector2(.90,.45),Vector2(.10,.82),Vector2(.37,.76),Vector2(.61,.89),Vector2(.87,.80)][i]
		var at:=area.position+point*area.size
		draw_circle(at,3.6,Color("426c83"));draw_arc(at,4,0,TAU,16,outline,1,true)
	if process=="boiling" and state=="liquid":
		for p in [Vector2(.3,.58),Vector2(.68,.73),Vector2(.5,.85)]:draw_arc(area.position+p*area.size,6,0,TAU,24,Color("26382f"),2,true)
	if process=="evaporation" and state=="liquid":
		for x in [.3,.7]:arrow(area.position+Vector2(area.size.x*x,area.size.y*.40),area.position+Vector2(area.size.x*x,9),Color("426c83"))
	if process=="condensation" and state=="liquid":
		for x in [.28,.7]:draw_colored_polygon(PackedVector2Array([area.position+Vector2(area.size.x*x,8),area.position+Vector2(area.size.x*x-4,17),area.position+Vector2(area.size.x*x+4,17)]),Color("426c83"))
	if process=="deposition" and state=="solid":
		var at:=area.get_center();draw_line(at-Vector2(0,24),at+Vector2(0,24),Color("486c7c"),3,true)
		for i in 6:draw_line(at,at+Vector2(22,0).rotated(i*TAU/6),Color("486c7c"),2,true)

func _draw() -> void:
	var rule: Dictionary=RULES.PROCESSES[process];var px:=19 if large_text else 16
	var width:=minf((size.x-82)/2,190);var height:=84.0
	var left:=Rect2(12,66,width,height);var right:=Rect2(size.x-12-width,66,width,height)
	words(TITLES[process],Vector2(12,24),px+1)
	words("HEAT IN" if rule.heat=="in" else "HEAT OUT",Vector2(12,49),px,Color("875229") if rule.heat=="in" else Color("315e7c"))
	arrow(Vector2(128 if rule.heat=="in" else 196,42),Vector2(196 if rule.heat=="in" else 128,42),Color("875229") if rule.heat=="in" else Color("315e7c"))
	particles(rule.from,left);particles(rule.to,right)
	var center:=Vector2(size.x/2,108);arrow(center-Vector2(22,0),center+Vector2(22,0),Color("3e5a44"))
	words(str(rule.from).to_upper(),Vector2(left.position.x,174),px);words(str(rule.to).to_upper(),Vector2(right.position.x,174),px)
	var legend:="Same substance · particles shown as a model"
	if "gas" in [rule.from,rule.to]:legend="Water vapor is invisible · dots are a model"
	words(legend,Vector2(12,201 if not large_text else 204),px)
	var note:="Step %d / 3 · Before / heat transfer / after"%(stage+1)
	if process in ["sublimation","deposition"]:note="Contained apparatus · no liquid stage"
	elif process=="evaporation":note="Escape at surface · not bubbles throughout"
	elif process=="boiling":note="Vapor bubbles form throughout the liquid"
	elif process=="condensation":note="Cooling produces liquid droplets"
	words(note,Vector2(12,227 if not large_text else 236),px)
	if process=="deposition":words("Frost sample · never a support platform",Vector2(12,250 if not large_text else 269),px)
	var x:=left.position.x if stage==0 else center.x-14 if stage==1 else right.position.x
	draw_line(Vector2(x,155),Vector2(x+(width if stage!=1 else 28),155),Color("aa7738"),3,true)
