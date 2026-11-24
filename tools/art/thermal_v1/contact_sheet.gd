extends SceneTree
## Evidence packing only. Crops actual 1:1 gameplay captures, never redraws art.
func _initialize() -> void:
	var folder := "res://docs/tests/evidence/phase-thermal/"
	var directions := ["east","south_east","south","south_west","west","north_west","north","north_east"]
	var sheet := Image.create(1760,620,false,Image.FORMAT_RGBA8)
	for i in 8:
		var image := Image.load_from_file(folder+"impact-"+directions[i]+".png")
		assert(image != null and image.get_size() == Vector2i(960,540))
		sheet.blit_rect(image,Rect2i(220,144,440,310),Vector2i(i%4*440,i/4*310))
	assert(sheet.save_png(folder+"directions-contact-sheet.png") == OK)
	print("THERMAL CONTACT SHEET / 8 actual 1:1 crops / E SE S SW / W NW N NE")
	quit()
