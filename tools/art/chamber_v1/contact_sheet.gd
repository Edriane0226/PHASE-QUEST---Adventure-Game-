extends SceneTree
const FOLDER := "res://docs/tests/evidence/phase-chambers/"
func _initialize() -> void:
	var directions := ["east","south_east","south","south_west","west","north_west","north","north_east"]
	var phases := Image.create(1680,600,false,Image.FORMAT_RGBA8)
	for mode in ["pressure","vacuum"]:
		var sheet := Image.create(2000,780,false,Image.FORMAT_RGBA8)
		for i in 8:
			var capture := Image.load_from_file(FOLDER+mode+"-impact-"+directions[i]+".png")
			assert(capture != null and capture.get_size() == Vector2i(960,540))
			sheet.blit_rect(capture,Rect2i(170,120,500,390),Vector2i(i%4*500,i/4*390))
		assert(sheet.save_png(FOLDER+mode+"-directions.png") == OK)
		var names := ["start","impact-east","partial","stop"]
		for i in 4:
			var capture := Image.load_from_file(FOLDER+mode+"-"+names[i]+".png")
			phases.blit_rect(capture,Rect2i(260,180,420,300),Vector2i(i*420,0 if mode == "pressure" else 300))
	assert(phases.save_png(FOLDER+"mode-phases.png") == OK)
	print("CHAMBER CONTACT SHEETS / two eight-direction sheets + mode phases / original-scale crops")
	quit()
