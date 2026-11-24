extends SceneTree
func _initialize() -> void:
	var geometry=load("res://Scripts/World/Zone1/zone1_geometry.gd").new();geometry.load_data()
	for points in geometry.data.water:
		var p: PackedVector2Array=geometry.polygon(points)
		for j in range(p.size()):
			var from: Vector2=p[j];var to: Vector2=p[(j+1)%p.size()]
			if geometry.region_at((from+to)/2).is_empty():continue
			var normal: Vector2=(to-from).normalized().orthogonal()*2
			var pieces: Array=[PackedVector2Array([from+normal,to+normal,to-normal,from-normal])]
			for bridge in geometry.bridges:
				var next: Array=[]
				for piece in pieces:next.append_array(Geometry2D.clip_polygons(piece,bridge))
				pieces=next
			for piece in pieces:
				if piece.size()<3 or not Geometry2D.triangulate_polygon(piece).is_empty():continue
				var local:=PackedVector2Array();var area:=0.0
				for at in piece:local.append(at-piece[0])
				for k in range(local.size()):area+=float(local[k].x)*float(local[(k+1)%local.size()].y)-float(local[(k+1)%local.size()].x)*float(local[k].y)
				print("INVALID BANK / points=",piece," / local=",local," / area=",area*.5," / local triangles=",Geometry2D.triangulate_polygon(local))
	quit()
