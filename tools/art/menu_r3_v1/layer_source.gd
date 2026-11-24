extends Control
## Original separable atmosphere over unchanged generated painting. UI pixels, not world geometry.
var painting: Texture2D
var layer:="static"
var region:="gardens"
const TONES={"gardens":Color("23353d"),"vale":Color("25362b"),"laboratory":Color("273a42")}

func _draw() -> void:
	if layer in ["painting","static"] and painting:draw_texture_rect(painting,Rect2(Vector2.ZERO,size),false)
	if layer in ["veil","static"]:
		draw_rect(Rect2(Vector2.ZERO,size),Color(TONES[region],.18))
		# Feathered edge shade is transparent; the paintings remain flattened sources.
		for i in 32:
			var inset:=float(i)*minf(size.x,size.y)*.005
			draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color(.015,.025,.03,.007),false,maxf(1,minf(size.x,size.y)*.01))
	if layer in ["atmosphere","static"]:
		var color:=Color("c9dde1") if region!="vale" else Color("f0d39c")
		for i in 22:
			var at:=Vector2(.05+fmod(i*.267,.91),.08+fmod(i*.193,.84))*size
			if absf(at.x-size.x/2)<size.x*.23:continue
			draw_circle(at,1.0+float(i%3)*.35,Color(color,.24 if region=="gardens" else .14))
		for corner in [Vector2(.03,.89),Vector2(.94,.17)]:
			for i in 28:
				var radius:=size.y*(.04+.008*i)
				draw_set_transform(corner*size,0,Vector2(2.3,.45));draw_circle(Vector2.ZERO,radius,Color(color,.0014))
			draw_set_transform(Vector2.ZERO)
