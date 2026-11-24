extends RefCounted
## Cosmetic cube faces below the existing coast plane. No support or collision changes.
const PALETTE = preload("res://Scripts/World/terrain_palette.gd")
const REGISTRY = preload("res://Scripts/Content/world_subregions.gd")
const STEP := 20.0
const LAYERS := 3
var faces: Array = []
var biome := "grass"
var _mainland: Array[PackedVector2Array] = []

func on_mainland(at: Vector2) -> bool:
	if _mainland.is_empty():
		for row in REGISTRY.definitions():
			var polygon := PackedVector2Array()
			for p in row.permission_polygon:polygon.append(Vector2(p[0],p[1]))
			_mainland.append(polygon)
	for polygon: PackedVector2Array in _mainland:
		if Geometry2D.is_point_in_polygon(at,polygon):return true
	return false

func configure(model: RefCounted,kind: String,mainland: Array=[]) -> void:
	faces.clear();biome=kind
	_mainland.assign(mainland)
	for region in model.data.regions:
		var polygon: PackedVector2Array=model.polygon(region.permission_polygon)
		for i in range(polygon.size()):
			var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
			var normal: Vector2=(b-a).normalized().orthogonal()*6
			var count:=maxi(1,ceili(a.distance_to(b)/80.0))
			for j in range(count):
				var from:=a.lerp(b,float(j)/count);var to:=a.lerp(b,float(j+1)/count)
				if absf(from.x-to.x)<.01:continue
				var mid: Vector2=(from+to)*.5
				var plus:=on_mainland(mid+normal);var minus:=on_mainland(mid-normal)
				# True outside only: never erect a visual wall along earned regional seams.
				if plus==minus:continue
				var inward: Vector2=normal if plus else -normal
				var supported:=false
				for floor in model.nearby(mid+inward,model.floors,model.floor_bins):
					if floor.kind=="mainland" and Geometry2D.is_point_in_polygon(mid+inward,floor.polygon):supported=true;break
				if not supported:continue
				faces.append({"a":from,"b":to,"inward":inward,"region":region.id})

func draw_faces(canvas: Node2D) -> void:
	for face in faces:
		var color: Color=PALETTE.LEFT[biome] if face.inward.x>0 else PALETTE.RIGHT[biome]
		for z in range(LAYERS):
			var a: Vector2=face.a+Vector2(0,z*STEP);var b: Vector2=face.b+Vector2(0,z*STEP)
			var drop:=Vector2(0,STEP)
			canvas.draw_colored_polygon(PackedVector2Array([a,b,b+drop,a+drop]),color)
