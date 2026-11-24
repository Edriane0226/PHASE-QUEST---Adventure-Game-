extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var geometry=load("res://Scripts/World/Zone1/zone1_geometry.gd").new();geometry.load_data()
	for i in range(geometry.floors.size()):
		var floor: Dictionary=geometry.floors[i];var points:=PackedVector2Array()
		for p in floor.polygon:points.append(p-Vector2(0,geometry.height_mainland(p) if floor.kind in ["mainland","bridge"] else floor.height))
		if Geometry2D.triangulate_polygon(points).is_empty():print("BAD FLOOR ",i," ",floor.region," ",floor.kind," count=",points.size()," points=",points)
	print("INSPECTED ",geometry.floors.size()," floors");quit()
