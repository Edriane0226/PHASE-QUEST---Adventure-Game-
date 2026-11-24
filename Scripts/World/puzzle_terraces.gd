extends RefCounted
## Real, walkable puzzle foundations. XY support/gaps and gate ownership stay authored.
const STEP := 20.0
const BIN := 256.0
var platforms: Array = []
var bins: Dictionary = {}
var source_platforms: Array = []

func _index(record: Dictionary,box: Rect2) -> void:
	platforms.append(record)
	for x in range(floori(box.position.x/BIN),floori(box.end.x/BIN)+1):
		for y in range(floori(box.position.y/BIN),floori(box.end.y/BIN)+1):
			var key:=Vector2i(x,y)
			if not bins.has(key):bins[key]=[]
			bins[key].append(record)

func configure(model: RefCounted) -> void:
	platforms.clear();bins.clear();source_platforms.clear()
	for source in model.data.get("sources",[]):
		var polygon: PackedVector2Array=model.polygon(source.protected_envelope)
		var record:={"kind":"source","region":source.subregion,"polygon":polygon,"height":80.0,"radius":320.0}
		source_platforms.append(record);_index(record,model.box_of(polygon).grow(record.radius))
	for station in model.data.stations:
		if station.kind not in ["puzzle court","existing puzzle","runtime override","crystal","assessor","optional minigame"]:continue
		var at: Vector2=model.v(station.ground_xy);var owned_by_source:=false
		for source in source_platforms:
			if Geometry2D.is_point_in_polygon(at,source.polygon):owned_by_source=true;break
		if owned_by_source:continue
		var half:=Vector2(float(station.footprint[2])*.5+96,float(station.footprint[3])*.5+72)
		var record:={"kind":"station","region":station.subregion,"station":station.id,"center":at,"half":half,"height":40.0+20.0*posmod(str(station.id).hash(),2)}
		_index(record,Rect2(at-half*2,half*4))

func offset_at(point: Vector2) -> float:
	var height:=0.0
	for record in bins.get(Vector2i(floori(point.x/BIN),floori(point.y/BIN)),[]):
		var weight:=0.0
		if record.kind=="source":
			if Geometry2D.is_point_in_polygon(point,record.polygon):weight=1.0
			else:
				var distance:=INF;var p: PackedVector2Array=record.polygon
				for i in range(p.size()):distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,p[i],p[(i+1)%p.size()])))
				weight=1.0-smoothstep(0,record.radius,distance)
		else:
			var delta: Vector2=(point-record.center).abs()/record.half
			weight=1.0-smoothstep(1.0,2.0,delta.x+delta.y)
		height=maxf(height,float(record.height)*weight)
	return roundf(height/STEP)*STEP
