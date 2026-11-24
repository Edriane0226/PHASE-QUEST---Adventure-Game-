extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	change_scene_to_file("res://World/Zone3/Zone3ShellWorld.tscn");await scene_changed
	var w=current_scene;w.set_fixture_permissions(6,true);await physics_frame
	var g=w.geometry
	for c in g.data.chambers:
		var loop: PackedVector2Array=g.polygon(c.service_loop)
		for i in range(1,loop.size()):
			for j in range(21):
				var p: Vector2=loop[i-1].lerp(loop[i],j/20.0)
				if g.standable(p,true):continue
				var box: Rect2=g.SUPPORT.cargo_clearance_rect(p)
				print("BAD ",c.id," ",p," supported=",g.supported_box(box)," blocked=",g.blocked_box(box))
				for b in g.blockers:
					if b.bounds.intersects(box) and not Geometry2D.intersect_polygons(g.rect_poly(box),b.polygon).is_empty():print(" BLOCKER ",b.bounds," layer=",b.layer)
				break
	for e in g.data.equipment:
		var p: Vector2=g.v(e.observation)
		if not g.standable(p) or p.distance_to(g.v(e.at))>48:print("TOUCH ",e.id," distance=",p.distance_to(g.v(e.at))," standable=",g.standable(p))
	quit()
