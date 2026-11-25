extends RefCounted
## Real, walkable puzzle foundations. XY support/gaps and gate ownership stay authored.
const STEP := 20.0
const BIN := 256.0
const PLATEAU := ["puzzle court","existing puzzle","runtime override","crystal","assessor","optional minigame"]
## A region falls to its lower neighbour over this distance. Wide enough for one cube per ledge.
const SLOPE := 1000.0
const PIECE := 80.0
## A station stands on one level this far out, in halves of its plateau.
const PAD := 1.6
## Around a pad the land rises one cube for each block.
const PAD_REACH := 320.0
const PAD_RISE := 67.0
var platforms: Array = []
var bins: Dictionary = {}
var source_platforms: Array = []
var _blocks: Dictionary = {}
var _slopes: Dictionary = {}
var _borders: Array = []
const GRID = preload("res://Scripts/World/terrain_relief.gd")

func _index(record: Dictionary,box: Rect2) -> void:
	platforms.append(record)
	for x in range(floori(box.position.x/BIN),floori(box.end.x/BIN)+1):
		for y in range(floori(box.position.y/BIN),floori(box.end.y/BIN)+1):
			var key:=Vector2i(x,y)
			if not bins.has(key):bins[key]=[]
			bins[key].append(record)

func configure(model: RefCounted) -> void:
	platforms.clear();bins.clear();source_platforms.clear();_blocks.clear();_slopes.clear();_borders.clear()
	_read_borders(model)
	for source in model.data.get("sources",[]):
		var polygon: PackedVector2Array=model.polygon(source.protected_envelope)
		var record:={"kind":"source","region":source.subregion,"polygon":polygon,"height":80.0,"radius":320.0}
		source_platforms.append(record);_index(record,model.box_of(polygon).grow(record.radius))
	for station in model.data.stations:
		if station.kind not in PLATEAU:continue
		var at: Vector2=model.v(station.ground_xy);var owned_by_source:=false
		for source in source_platforms:
			if Geometry2D.is_point_in_polygon(at,source.polygon):owned_by_source=true;break
		if owned_by_source:continue
		var half:=Vector2(float(station.footprint[2])*.5+96,float(station.footprint[3])*.5+72)
		var record:={"kind":"station","region":station.subregion,"station":station.id,"center":at,"half":half,"height":20.0+20.0*posmod(str(station.id).hash(),2)}
		_index(record,Rect2(at-half*2,half*4).grow(PAD_REACH))
	# No step runs through a checkpoint hut, a professor or a landmark: flat ground, not raised.
	for station in model.data.stations:
		if station.kind in PLATEAU:continue
		var at: Vector2=model.v(station.ground_xy);var half:=Vector2(90,50)
		_index({"kind":"station","region":station.subregion,"center":at,"half":half,"height":0.0},Rect2(at-half*2,half*4).grow(PAD_REACH))
	# A room has an authored floor level. The land under it stays level with that floor.
	for room in model.data.get("rooms",[]):
		_index({"kind":"station","region":room.subregion,"center":room.center,"half":room.half,"height":0.0,"level":room.elevation},Rect2(room.center-room.half*2,room.half*4).grow(PAD_REACH))

## Short pieces of every region border, with the height of the land on the other side.
func _read_borders(model: RefCounted) -> void:
	for i in model.data.regions.size():
		var own: float=float(model.data.regions[i].elevation)
		var p: PackedVector2Array=model.region_polygons[i] if i<model.region_polygons.size() else model.polygon(model.data.regions[i].permission_polygon)
		var pieces: Array=[]
		for j in p.size():
			var a:=p[j];var b:=p[(j+1)%p.size()];var count:=maxi(1,ceili(a.distance_to(b)/PIECE))
			var out:=(b-a).normalized().orthogonal()*8.0
			for k in count:
				var from:=a.lerp(b,float(k)/count);var to:=a.lerp(b,float(k+1)/count);var mid:=(from+to)*.5;var other:=0.0
				for q in model.data.regions.size():
					if q==i:continue
					if Geometry2D.is_point_in_polygon(mid+out,model.region_polygons[q]) or Geometry2D.is_point_in_polygon(mid-out,model.region_polygons[q]):other=maxf(other,float(model.data.regions[q].elevation))
				if other<own:pieces.append([from,to,other])
		_borders.append(pieces)

## Height of a region at a block. Districts of one land meet at the lower of their levels, not at the sea.
func slope_at(model: RefCounted,region: int,at: Vector2) -> float:
	var key:=Vector3i(int(at.x),int(at.y),region)
	var known: Variant=_slopes.get(key)
	if known!=null:return known
	var height:=_slope(model,region,at);var nearest:=PAD;var level:=INF
	for record in bins.get(Vector2i(floori(at.x/BIN),floori(at.y/BIN)),[]):
		if record.kind!="station" or record.region!=model.data.regions[region].id:continue
		if not record.has("level"):record.level=_pad_level(model,region,record)
		var delta: Vector2=(at-record.center).abs()/record.half
		var t: float=delta.x+delta.y
		if t<=nearest:nearest=t;level=record.level
		elif t>PAD:height=minf(height,record.level+STEP*ceilf((t-PAD)*minf(record.half.x,record.half.y*2.0)/PAD_RISE))
	if is_finite(level):height=level
	_slopes[key]=height
	return height

## The lowest slope under the pad, so a station near a border does not stand on a tower.
func _pad_level(model: RefCounted,region: int,record: Dictionary) -> float:
	var level:=_slope(model,region,record.center)
	for k in 8:
		var way:=Vector2.RIGHT.rotated(k*TAU/8);var t: float=absf(way.x)/record.half.x+absf(way.y)/record.half.y
		level=minf(level,_slope(model,region,record.center+way*PAD/t))
	return level

func _slope(model: RefCounted,region: int,at: Vector2) -> float:
	var own: float=float(model.data.regions[region].elevation);var height:=own
	at=GRID.ledge_center(at)
	for piece in _borders[region]:
		var distance:=at.distance_to(Geometry2D.get_closest_point_to_segment(at,piece[0],piece[1]))
		if distance<SLOPE:height=minf(height,lerpf(piece[2],own,distance/SLOPE))
	return roundf(height/STEP)*STEP

## One height for each 3x3 block: the highest of its cells, so a puzzle plateau never shrinks.
func offset_at(point: Vector2) -> float:
	var block: Vector2i=GRID.block_of(GRID.cell_at(point))
	var known: Variant=_blocks.get(block)
	if known!=null:return known
	var height:=0.0
	for dx in GRID.BLOCK:
		for dy in GRID.BLOCK:height=maxf(height,_offset(GRID.center(block*GRID.BLOCK+Vector2i(dx,dy))))
	_blocks[block]=height
	return height

func _offset(point: Vector2) -> float:
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
