extends RefCounted
## Paints the ground as pixel tiles, one art pixel per world unit, into page images.
## Heights and edges are read from the authoritative floors. Painting never grants or removes support.
## Whole cells use autotiled sheets. Cells cut by a floor edge are painted column by column, so the
## drawn edge is exactly the edge of the floor.
const GRID = preload("res://Scripts/World/terrain_relief.gd")
const HALF := [Vector2(0,-10),Vector2(20,0),Vector2(0,10),Vector2(-20,0)]
const ROAD_BIN := 256.0
const PAGE := Vector2i(768,384)
## The tallest ground that can be drawn above its own place.
const REACH := 440
## Floors this close can touch the cells of a page or their neighbour lookups.
const PAGE_MARGIN := 64.0
## Raise after any change to the painter or the tiles, then run tools/world/terrain_bake/bake.gd.
const BAKE_VERSION := 3
const BAKE_DIR := "res://assets/world/terrain_bake_v3/"
const SHEETS := "res://assets/pixel_v1/terrain/"
const SETS := ["cap","patch_a","patch_b","over","path","path_over","foot","edge","side","corner","ramp","decal"]
const SHARED := ["water_cap","water_deep","water_reflect","water_over","bridge_cap"]
const NE := 1
const SE := 2
const SW := 4
const NW := 8
const SIDES := {NE:Vector2i(0,-1),SE:Vector2i(1,0),SW:Vector2i(0,1),NW:Vector2i(-1,0)}
const OPPOSITE := {NE:SW,SE:NW,SW:NE,NW:SE}
const NONE := -999
const WATER := -20
## Patch noise levels, from which a cell belongs to a warm or a cool patch.
const WARM := {"snow":.34,"grass":.38,"lab":.28}
const COOL := {"snow":-.38,"grass":-.42,"lab":-.30}
const EMPTY := 0
const WHOLE := 1
const CUT := 2
## Which biome creeps over which at a border.
const RANK := {"snow":3,"grass":2,"lab":1}
const LIGHT := {"snow":Color("fcfdf5"),"grass":Color("d6e489"),"lab":Color("e9e7db")}
const TREAD := {"snow":Color("e6cf9f"),"grass":Color("e6cf9f"),"lab":Color("a0a7a1")}
const WOOD := [Color("e6cf9f"),Color("bd9870"),Color("8f6a50"),Color("8f6a50"),Color("574739"),Color("3a1f24")]
const SHORE := [Color("0d2f57"),Color("0d2f57"),Color("0d2f57"),Color("1b5c7a")]
const FOAM := Color("b4f5e3")

var models: Array = []
var biomes: Array = []
var routes: Array = []
var road_bins: Dictionary = {}
## Baked pages: page -> {signature of its floors -> record}. Read only while playing.
var pages: Dictionary = {}
var stats: Dictionary = {}
var dirty := true
var bake_loaded := false
var _roads_ready := false
var _patches := FastNoiseLite.new()
var _border := FastNoiseLite.new()
var _info: Dictionary = {}
var _kinds: Dictionary = {}
var _shallow: Dictionary = {}
static var _tiles: Dictionary = {}
static var _head := PackedInt32Array()
static var _foot := PackedInt32Array()

func _init() -> void:
	_patches.seed = 19017; _patches.frequency = .05
	_border.seed = 4021; _border.frequency = .16
	if _head.is_empty():
		for x in 40:
			# A cap is 2,6..38,38..6,2 pixels wide, so columns 0 and 39 are empty.
			var u: int = x if x < 20 else 39-x
			_head.append(9-(u-1)/2 if u > 0 else 10)
			_foot.append(10+(u-1)/2 if u > 0 else 9)

func configure(values: Array, kinds: Array) -> void:
	models = values; biomes = kinds; dirty = true
	pages.clear(); _roads_ready = false
	routes.resize(models.size())
	for i in routes.size():
		if routes[i] == null: routes[i] = []

func set_routes(index: int, values: Array) -> void:
	routes[index] = values; dirty = true
	pages.clear(); _roads_ready = false

# ---------------------------------------------------------------- bake

func bake_signature() -> String:
	# Actual generated geometry, not resource paths: also valid in compiled Android packs.
	# Floors change as puzzles are solved, so each page signs its own floors instead.
	var parts: Array = [BAKE_VERSION,biomes,routes]
	for model in models: parts.append_array([model.data,model.relief.columns])
	return _sha(var_to_bytes(parts))

func bake_path() -> String:
	return BAKE_DIR+("campaign" if models.size() > 1 else str(biomes[0]))+".res"

static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

func restore_bake() -> bool:
	if not ResourceLoader.exists(bake_path()): return false
	var resource = load(bake_path())
	if resource == null or resource.get_meta("signature","") != bake_signature(): return false
	var cached: Variant = resource.get_meta("pages",{})
	if not cached is Dictionary or cached.is_empty(): return false
	for states in cached.values():
		if not states is Dictionary: return false
		for record in states.values():
			if not record is Dictionary or not record.get("image") is PackedByteArray or not record.get("water") is PackedInt32Array: return false
	pages = cached; bake_loaded = true
	return true

func bake_resource() -> Resource:
	var resource := Resource.new()
	resource.set_meta("signature",bake_signature())
	resource.set_meta("pages",pages)
	return resource

## Packs the exported sheets into one resource, so an exported game needs no loose images.
static func pack_tiles() -> Resource:
	var packed := {}
	for biome in ["snow","grass","lab"]:
		for part in SETS: packed[biome+"_"+part] = null
	for part in SHARED: packed[part] = null
	for name in packed:
		var image := Image.load_from_file(ProjectSettings.globalize_path(SHEETS+name+".png"))
		image.convert(Image.FORMAT_RGBA8)
		packed[name] = image
	var resource := Resource.new()
	resource.set_meta("sheets",packed)
	return resource

static func tiles() -> Dictionary:
	if _tiles.is_empty():
		var path := BAKE_DIR+"tiles.res"
		_tiles = load(path).get_meta("sheets") if ResourceLoader.exists(path) else pack_tiles().get_meta("sheets")
	return _tiles

# ---------------------------------------------------------------- pages

## Signature of the visible floors each page can draw.
func current_signatures() -> Dictionary:
	var result: Dictionary = {}
	for index in models.size():
		var model: RefCounted = models[index]
		for floor in model.floors:
			if floor.conditional and not model.science_open: continue
			var box: Rect2 = floor.bounds.grow(PAGE_MARGIN)
			box = box.expand(box.position-Vector2(0,REACH))
			var mark := hash([index,floor.kind,float(floor.height),floor.polygon])
			for x in range(floori(box.position.x/PAGE.x),floori(box.end.x/PAGE.x)+1):
				for y in range(floori(box.position.y/PAGE.y),floori(box.end.y/PAGE.y)+1):
					var key := Vector2i(x,y)
					result[key] = hash([result.get(key,0),mark])
	return result

## Signatures of the pages as they are now. The caches of the painter are dropped, because floors may have changed.
func refresh() -> Dictionary:
	var started := Time.get_ticks_msec()
	if dirty and not restore_bake(): pages.clear(); bake_loaded = false
	dirty = false
	_info.clear(); _kinds.clear(); _shallow.clear()
	var wanted := current_signatures()
	var kept := 0
	for page in wanted:
		if not record(page,wanted[page]).is_empty(): kept += 1
	stats = {"pages":wanted.size(),"baked":kept,"to_paint":wanted.size()-kept,"refresh_ms":Time.get_ticks_msec()-started}
	return wanted

## The baked page for these floors, or nothing.
func record(page: Vector2i, signature: int) -> Dictionary:
	return pages.get(page,{}).get(signature,{})

## Paints one page for the bake.
func bake_page(page: Vector2i, signature: int) -> Dictionary:
	var job := begin(page)
	while not advance(job,1000000): pass
	var image: Image = job.image
	var baked := {"image":PackedByteArray() if image.is_invisible() else image.save_webp_to_buffer(false),"water":job.water}
	if not pages.has(page): pages[page] = {}
	pages[page][signature] = baked
	return baked

func begin(page: Vector2i) -> Dictionary:
	_prepare_roads()
	_info.clear(); _kinds.clear(); _shallow.clear()
	var rect := Rect2i(page*PAGE,PAGE)
	return {"page":page,"rect":rect,"image":Image.create(PAGE.x,PAGE.y,false,Image.FORMAT_RGBA8),"water":PackedInt32Array(),
		"row":ceili((rect.position.y-40)/10.0),"last":floori((rect.end.y+REACH+10)/10.0)}

## Paints rows from back to front until the time is used. Returns true when the page is complete.
func advance(job: Dictionary, budget_usec: int) -> bool:
	var until := Time.get_ticks_usec()+budget_usec
	var rect: Rect2i = job.rect
	while job.row <= job.last:
		var s: int = job.row
		for d in range(floori((rect.position.x-20)/20.0),ceili((rect.end.x+20)/20.0)+1):
			if posmod(d+s,2) != 0: continue
			_paint_cell(job,Vector2i((s+d)>>1,(s-d)>>1))
		job.row += 1
		if Time.get_ticks_usec() >= until: return job.row > job.last
	return true

# ---------------------------------------------------------------- what stands where

func _road(points: Array, model: RefCounted) -> void:
	for i in range(1,points.size()):
		var a: Vector2 = model.v(points[i-1]); var b: Vector2 = model.v(points[i])
		var box := Rect2(a,Vector2.ZERO).expand(b).grow(140)
		for x in range(floori(box.position.x/ROAD_BIN),floori(box.end.x/ROAD_BIN)+1):
			for y in range(floori(box.position.y/ROAD_BIN),floori(box.end.y/ROAD_BIN)+1):
				var key := Vector2i(x,y)
				if not road_bins.has(key): road_bins[key] = []
				road_bins[key].append([a,b])

func _prepare_roads() -> void:
	if _roads_ready: return
	road_bins.clear(); _roads_ready = true
	for i in models.size():
		var model: RefCounted = models[i]
		for branch in model.data.local_branches: _road(branch.points,model)
		for trail in model.data.trails: _road(trail.sampled_points,model)
		for source in model.data.get("sources",[]):
			for portal in source.portal_routes: _road(portal.points,model)
		for chamber in model.data.get("chambers",[]): _road(chamber.service_loop,model)
		for route in routes[i]: _road(route.points,model)

func _on_road(point: Vector2) -> bool:
	var distance := INF
	for segment in road_bins.get(Vector2i(floori(point.x/ROAD_BIN),floori(point.y/ROAD_BIN)),[]):
		distance = minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1])))
	return distance < 52.0+_patches.get_noise_2d(point.x*.16,point.y*.16)*22.0

## What covers one cell: nothing, one height everywhere, or a cut with a height per pixel.
func info(cell: Vector2i) -> Dictionary:
	var known: Variant = _info.get(cell)
	if known != null: return known
	var result := _look(cell)
	_info[cell] = result
	return result

func _look(cell: Vector2i) -> Dictionary:
	var at: Vector2 = GRID.center(cell)
	var box := Rect2(at-Vector2(20,10),Vector2(40,20))
	var found: Array = []
	var best := {}
	for index in models.size():
		var model: RefCounted = models[index]
		var seen := {}
		for bin in model.cells(box):
			for id in model.floor_bins.get(bin,[]):
				if seen.has(id): continue
				seen[id] = true
				var floor: Dictionary = model.floors[id]
				if floor.conditional and not model.science_open: continue
				if not floor.bounds.intersects(box): continue
				var inside := 0
				for p: Vector2 in HALF:
					if Geometry2D.is_point_in_polygon(at+p*.985,floor.polygon): inside += 1
				var centre := Geometry2D.is_point_in_polygon(at,floor.polygon)
				if inside == 0 and not centre:
					var diamond := PackedVector2Array()
					for p: Vector2 in HALF: diamond.append(at+p)
					if Geometry2D.intersect_polygons(diamond,floor.polygon).is_empty(): continue
				var entry := {"h":roundi(model.surface_height(floor,at)),"floor":floor,"mi":index,"all":inside == 4 and centre,"centre":centre,"deck":floor.kind == "bridge"}
				found.append(entry)
				# Land wins over a deck at the same height: planks show only over water.
				if entry.all and (best.is_empty() or entry.h > best.h or (entry.h == best.h and best.deck and not entry.deck)): best = entry
	if found.is_empty(): return {"k":EMPTY,"h":WATER}
	var top: int = NONE
	for entry in found: top = maxi(top,entry.h)
	# A deck that meets land at its own height ends at the shore line, pixel by pixel.
	var shore := false
	if not best.is_empty() and best.deck:
		for entry in found:
			if entry.h == best.h and not entry.deck: shore = true
	if not best.is_empty() and best.h == top and not shore: return _whole(best)
	if best.is_empty() or shore:
		# Several pieces of one height may fill the cell together.
		var left: Array = [PackedVector2Array([at+HALF[0]*.985,at+HALF[1]*.985,at+HALF[2]*.985,at+HALF[3]*.985])]
		var even := true
		for entry in found:
			if shore and entry.deck: continue
			# Planks and land together never make one whole cell: the line between them stays exact.
			if entry.h != top or entry.deck != found[0].deck and not shore: even = false
			var next: Array = []
			for piece in left: next.append_array(Geometry2D.clip_polygons(piece,entry.floor.polygon))
			left = next
		var area := 0.0
		for piece in left: area += absf(_area(piece))
		if even and area < 1.0:
			var owner: Dictionary = {}
			for entry in found:
				if shore and entry.deck: continue
				if owner.is_empty() or (entry.centre and not entry.deck) or (owner.deck and not entry.deck): owner = entry
			return _whole(owner)
	found.sort_custom(func(p,q): return p.h < q.h if p.h != q.h else (p.deck and not q.deck))
	var heights := PackedInt32Array(); heights.resize(800); heights.fill(NONE)
	var decks := PackedByteArray(); decks.resize(800)
	var filled := 0
	for entry in found:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(PackedVector2Array([box.position,box.position+Vector2(40,0),box.end,box.position+Vector2(0,20)]),entry.floor.polygon):
			_raster(piece,box.position,heights,decks,entry.h,1 if entry.deck else 0)
	var main: int = NONE
	for i in 800:
		if heights[i] != NONE: filled += 1; main = maxi(main,heights[i])
	if filled == 0: return {"k":EMPTY,"h":WATER}
	var owner: Dictionary = found[-1]
	if filled == 400:
		var same := true
		for i in 800:
			if heights[i] != NONE and (heights[i] != main or decks[i] != (1 if owner.deck else 0)): same = false; break
		if same: return _whole(owner)
	var planks := 0
	for entry in found:
		if entry.deck: planks = _boards(entry.floor)
	return {"k":CUT,"h":main,"deck":owner.deck,"mi":owner.mi,"heights":heights,"decks":decks,"boards":planks}

func _whole(entry: Dictionary) -> Dictionary:
	return {"k":WHOLE,"h":entry.h,"deck":entry.deck,"mi":entry.mi,"boards":_boards(entry.floor) if entry.deck else 0}

## Boards lie across the longest side of a deck. First frame of the matching set.
static func _boards(floor: Dictionary) -> int:
	var long := Vector2.ZERO
	for i in floor.polygon.size():
		var edge: Vector2 = floor.polygon[(i+1)%floor.polygon.size()]-floor.polygon[i]
		if edge.length() > long.length(): long = edge
	return 0 if absf(long.dot(Vector2(2,1))) >= absf(long.dot(Vector2(2,-1))) else 4

static func _area(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in p.size(): sum += p[i].cross(p[(i+1)%p.size()])
	return sum*.5

## Marks the pixels of the diamond whose centres lie in the polygon.
static func _raster(polygon: PackedVector2Array, origin: Vector2, heights: PackedInt32Array, decks: PackedByteArray, h: int, deck: int) -> void:
	var n := polygon.size()
	for y in 20:
		var line := origin.y+y+.5
		var cross: Array = []
		for i in n:
			var a := polygon[i]; var b := polygon[(i+1)%n]
			if (a.y <= line) != (b.y <= line): cross.append(a.x+(line-a.y)/(b.y-a.y)*(b.x-a.x)-origin.x)
		cross.sort()
		var half := 2*y+1 if y < 10 else 2*(19-y)+1
		for k in range(0,cross.size()-1,2):
			for x in range(maxi(20-half,ceili(cross[k]-.5)),mini(19+half,ceili(cross[k+1]-.5)-1)+1):
				heights[y*40+x] = h
				decks[y*40+x] = deck

## The cell whose drawn cap owns this pixel.
static func owner(x: int, y: int) -> Vector2i:
	var s := floori(y/10.0)
	for row in [s,s+1,s-1]:
		var inner: int = y-row*10+10
		if inner < 0 or inner > 19: continue
		var half: int = 2*inner+1 if inner < 10 else 2*(19-inner)+1
		# Centres of this row stand 40 apart.
		var d := roundi((x+.5)/20.0)
		for column in [d,d-1,d+1]:
			if posmod(column+row,2) != 0: continue
			var left: int = x-column*20+20
			if left >= 20-half and left <= 19+half: return Vector2i((row+column)>>1,(row-column)>>1)
	return GRID.cell_at(Vector2(x+.5,y+.5))

func height_at(x: int, y: int) -> int:
	var cell := owner(x,y)
	var data := info(cell)
	if data.k == WHOLE: return data.h
	if data.k == EMPTY: return NONE
	var at: Vector2 = GRID.center(cell)
	return data.heights[(y-int(at.y)+10)*40+x-int(at.x)+20]

func deck_at(x: int, y: int) -> bool:
	var cell := owner(x,y)
	var data := info(cell)
	if data.k == WHOLE: return data.deck
	if data.k == EMPTY: return false
	var at: Vector2 = GRID.center(cell)
	return data.decks[(y-int(at.y)+10)*40+x-int(at.x)+20] == 1

static func scatter(c: Vector2i, salt: int) -> int:
	var h := (c.x*374761393+c.y*668265263+salt*974634777) & 0x7fffffff
	h = ((h ^ (h >> 13))*1274126177) & 0x7fffffff
	return h >> 8

## Biome of a cell. Near a border it wanders by up to three cells, so there is no straight line.
func biome_of(cell: Vector2i, data: Dictionary) -> String:
	if models.size() < 2: return biomes[0]
	var own: int = data.mi
	for d in range(1,4):
		for side: Vector2i in SIDES.values():
			var other := info(cell+side*d)
			if other.k == EMPTY or other.mi == own: continue
			if _border.get_noise_2d(cell.x,cell.y) > [.05,.25,.42][d-1]: return biomes[other.mi]
			return biomes[own]
	return biomes[own]

## deck, path, a (warm patch), b (cool patch) or plain.
func kind_of(cell: Vector2i, data: Dictionary) -> String:
	var known: Variant = _kinds.get(cell)
	if known != null: return known
	var result := "plain"
	if data.k != EMPTY:
		if data.deck: result = "deck"
		else:
			var at: Vector2 = GRID.center(cell)
			if _on_road(at): result = "path"
			else:
				var n := _patches.get_noise_2d(cell.x,cell.y)
				var land: String = biomes[data.mi]
				result = "a" if n > WARM[land] else ("b" if n < COOL[land] else "plain")
				if result != "plain" and not _patch_holds(cell,n > 0.0,data.mi): result = "plain"
	_kinds[cell] = result
	return result

## A patch needs company and keeps away from a border of two biomes.
func _patch_holds(cell: Vector2i, warm: bool, mi: int) -> bool:
	var same := 0
	for side: Vector2i in SIDES.values():
		var n := _patches.get_noise_2d(cell.x+side.x,cell.y+side.y)
		if (n > WARM[biomes[mi]]) if warm else (n < COOL[biomes[mi]]): same += 1
		for d in [2,4]:
			var far := info(cell+side*d)
			if far.k != EMPTY and far.mi != mi: return false
	return same >= 2

# ---------------------------------------------------------------- painting

func _stamp(job: Dictionary, name: String, frame: int, at: Vector2i) -> void:
	var sheet: Image = tiles()[name]
	var tall := 24 if name.ends_with("over") or name.ends_with("foot") or name.ends_with("edge") else (40 if name.ends_with("side") or name.ends_with("corner") or name.ends_with("ramp") or name.ends_with("decal") else 20)
	job.image.blend_rect(sheet,Rect2i((frame%8)*40,(frame/8)*tall,40,tall),at-job.rect.position)

func _dot(job: Dictionary, x: int, y: int, colour: Color) -> void:
	x -= job.rect.position.x; y -= job.rect.position.y
	if x >= 0 and y >= 0 and x < PAGE.x and y < PAGE.y: job.image.set_pixel(x,y,colour)

func _paint_cell(job: Dictionary, cell: Vector2i) -> void:
	var data := info(cell)
	var at := Vector2i(GRID.center(cell))
	if data.k != WHOLE: _paint_water(job,cell,at)
	if data.k == EMPTY: return
	if at.y-data.h-30 > job.rect.end.y: return
	if data.k == CUT: _paint_cut(job,cell,at,data)
	else: _paint_whole(job,cell,at,data)

func _paint_whole(job: Dictionary, cell: Vector2i, at: Vector2i, data: Dictionary) -> void:
	var h: int = data.h
	var corner := at-Vector2i(20,10+h)
	var biome := biome_of(cell,data)
	var kind := kind_of(cell,data)
	var lower := 0
	var higher := 0
	var climbed := 0
	var other_kind := 0
	var other_biome := {}
	var cut := 0
	for bit: int in SIDES:
		var next: Vector2i = cell+SIDES[bit]
		var side := info(next)
		if side.k == CUT:
			cut |= bit
			if side.h == h and kind != "deck" and not side.deck and kind_of(next,side) != kind: other_kind |= bit
			continue
		if side.k == EMPTY or side.h < h:
			# A ramp climbs to this edge: it has no lip.
			lower |= bit
			if side.k == WHOLE and side.h == h-20 and _ramp(next,side.h) == OPPOSITE[bit]: climbed |= bit
			continue
		if side.h > h: higher |= bit; continue
		if kind_of(next,side) != kind: other_kind |= bit
		var theirs := biome_of(next,side)
		if theirs != biome and RANK[theirs] > RANK[biome]: other_biome[theirs] = int(other_biome.get(theirs,0)) | bit
	# Cap.
	match kind:
		"deck":
			_stamp(job,"bridge_cap",scatter(cell,1)%4+data.boards,corner)
			_sill(job,corner,other_kind)
		"path":
			var up := _ramp(cell,h)
			if up != 0:
				_stamp(job,biome+"_ramp",0 if up == NE else 1,corner-Vector2i(0,20))
				higher &= ~up
			else:
				_stamp(job,biome+"_path",scatter(cell,1)%6,corner)
			var banks := 0
			for bit: int in SIDES:
				if other_kind & bit and kind_of(cell+SIDES[bit],info(cell+SIDES[bit])) != "deck": banks |= bit
			if banks and up == 0: _stamp(job,biome+"_path_over",banks,corner)
		_:
			var roll := scatter(cell,2)%16
			# Most ground stays calm: plan rule 6 keeps about 70% of it empty.
			if kind == "plain": _stamp(job,biome+"_cap",[0,1,0,1,0,1,0,1,0,1,2,3,4,5,6,7][roll],corner)
			else:
				_stamp(job,biome+"_patch_"+kind,[0,0,0,1,1,2,0,3][roll%8],corner)
				if other_kind: _stamp(job,biome+"_over",other_kind,corner)
	for theirs in other_biome:
		if kind != "deck": _stamp(job,theirs+"_over",other_biome[theirs],corner)
	if higher & (NE|NW) and kind != "deck": _stamp(job,biome+"_foot",higher & (NE|NW),corner)
	# Walls, one cube at a time.
	for bit in [SW,SE]:
		if lower & bit:
			var side := info(cell+SIDES[bit])
			var base: int = WATER if side.k == EMPTY else side.h
			if kind == "deck":
				for x in _face(bit): _deck_wall(job,at.x-20+x,at.y-10+_foot[x],h,base)
			else:
				var level := h
				while level > base:
					_stamp(job,biome+"_side",(0 if bit == SW else 4)+scatter(cell,5+level)%4,at-Vector2i(20,10+level))
					level -= 20
				if side.k == EMPTY: _shore(job,at,bit)
				_close_wall(job,cell,at,bit,h,base,side.k == EMPTY,biome)
		elif cut & bit:
			for x in _face(bit):
				var wx: int = at.x-20+x
				var wy: int = at.y-10+_foot[x]
				var below := height_at(wx,wy+1)
				if below < h and height_at(wx,wy+2) < h: _column(job,wx,wy,h,maxi(below,WATER),below == NONE,_faces_left(wx,wy,h),biome,kind == "deck")
	if kind != "deck":
		if (lower & SW) and (lower & SE) and climbed == 0: _stamp(job,biome+"_corner",0,corner)
		if (higher & NE) and (higher & NW) and _ramp(cell,h) == 0: _stamp(job,biome+"_corner",1,corner-Vector2i(0,20))
		if lower & ~climbed and kind == "path": _path_edge(job,corner,lower & ~climbed,biome)
		elif lower & ~climbed: _stamp(job,biome+"_edge",lower & ~climbed,corner)
		if kind != "path" and lower == 0 and higher == 0 and cut == 0 and other_biome.is_empty():
			var roll := scatter(cell,7)%200
			if roll < 6: _stamp(job,biome+"_decal",roll,corner+Vector2i(0,-18))
	elif lower & (NE|NW):
		for x in range(1,39):
			if lower & (NW if x < 20 else NE): _dot(job,corner.x+x,corner.y+_head[x],WOOD[0])

## A path keeps its own colour at a step: a lit tread, not the lip of the ground beside it.
func _path_edge(job: Dictionary, corner: Vector2i, mask: int, biome: String) -> void:
	for x in range(1,39):
		if mask & (NW if x < 20 else NE) and x%7 != 3: _dot(job,corner.x+x,corner.y+_head[x],TREAD[biome])
		if mask & (SW if x < 20 else SE):
			_dot(job,corner.x+x,corner.y+_foot[x]-1,TREAD[biome])
			_dot(job,corner.x+x,corner.y+_foot[x],TREAD[biome])

## A path cell whose neighbour behind is the same path one cube higher becomes a ramp.
func _ramp(cell: Vector2i, h: int) -> int:
	for bit in [NE,NW]:
		var next: Vector2i = cell+SIDES[bit]
		var side := info(next)
		if side.k == WHOLE and side.h == h+20 and kind_of(next,side) == "path": return bit
	return 0

## The end of a deck: a dark sill with a lit beam where planks meet the ground.
func _sill(job: Dictionary, corner: Vector2i, mask: int) -> void:
	if mask == 0: return
	for x in range(1,39):
		for y in range(_head[x],_foot[x]+1):
			var back: int = NW if x < 20 else NE
			var front: int = SW if x < 20 else SE
			var d := 99
			if mask & back: d = y-_head[x]
			if mask & front: d = mini(d,_foot[x]-y)
			if d <= 3: _dot(job,corner.x+x,corner.y+y,WOOD[5] if d == 0 else (WOOD[0] if d == 1 else (WOOD[1] if d == 2 else WOOD[4])))

## The column at the tip belongs to the cell behind. Where that cell has no such wall, close it here.
func _close_wall(job: Dictionary, cell: Vector2i, at: Vector2i, bit: int, h: int, base: int, water: bool, biome: String) -> void:
	var back: Vector2i = cell+SIDES[NW if bit == SW else NE]
	var behind := info(back)
	var top: int = mini(h,behind.h)
	if behind.k == EMPTY or top <= base: return
	var front := info(back+SIDES[bit])
	if behind.k == WHOLE and behind.h == h and (front.k == EMPTY or front.k == WHOLE and front.h <= base and _ramp(back+SIDES[bit],front.h) == 0): return
	_column(job,at.x-20+(0 if bit == SW else 39),at.y-1,top,base,water,bit == SW,biome,false)

## A wall is twenty columns wide, one more than its half of the cap, so neighbours leave no gap.
static func _face(bit: int) -> Array:
	return range(1,21) if bit == SW else range(19,39)

func _shore(job: Dictionary, at: Vector2i, bit: int) -> void:
	for x in _face(bit):
		_shore_column(job,at.x-20+x,at.y+10+_foot[x]+1)

## The foot of a bank in the water: shade, then a broken line of foam.
func _shore_column(job: Dictionary, x: int, y: int) -> void:
	var wave: int = [0,0,1,1,1,0,0,-1,-1,0][posmod(x/2,10)]
	for k in 4+wave:
		_dot(job,x,y+k,SHORE[mini(k,3)] if k < 3+wave else SHORE[3])
	if posmod(x/5+y/7,3) != 0: _dot(job,x,y+6+wave,FOAM)

## One column of wall under a cut edge.
func _column(job: Dictionary, x: int, y: int, h: int, base: int, water: bool, left: bool, biome: String, deck: bool) -> void:
	if deck: _deck_wall(job,x,y,h,base); return
	var side: Image = tiles()[biome+"_side"]
	var u := posmod(x,20)
	var c := (1 if left else 19)+u
	var d := 0
	while d < h-base:
		var part := mini(20-d%20,h-base-d)
		var frame := (0 if left else 4)+scatter(Vector2i(floori(x/20.0),(h-d)/20),6)%4
		job.image.blend_rect(side,Rect2i(frame*40+c,_foot[c]+1+d%20,1,part),Vector2i(x,y+1-h+d)-job.rect.position)
		d += part
	var lip: Image = tiles()[biome+"_edge"]
	var mask := SW if left else SE
	var e := (1 if left else 20)+posmod(x,19)
	job.image.blend_rect(lip,Rect2i(mask%8*40+e,mask/8*24+_foot[e]-2,1,7),Vector2i(x,y-2-h)-job.rect.position)
	if water: _shore_column(job,x,y+1-base)

## A deck has a beam and piers instead of a wall of earth.
func _deck_wall(job: Dictionary, x: int, y: int, h: int, base: int) -> void:
	var pier := posmod(x,44) < 5
	var drop := h-base
	# Over ground the side is boarded up to the floor. Over water only the beam and the piers show.
	if base != WATER:
		for k in drop: _dot(job,x,y+1-h+k,WOOD[0] if k == 0 else (WOOD[1] if k < 3 else (WOOD[5] if posmod(x,8) == 0 or k == drop-1 else WOOD[4])))
		return
	for k in (drop if pier else mini(drop,WOOD.size())):
		var colour: Color = WOOD[mini(k,5)] if k < WOOD.size() else (WOOD[2] if posmod(x,44) < 2 else WOOD[4])
		_dot(job,x,y+1-h+k,colour)
	_dot(job,x,y-h,WOOD[0])
	if base == WATER:
		for k in (4 if pier else 2): _dot(job,x,y+1-base+k,SHORE[0] if pier else SHORE[3])

## A front edge that falls to the right shows the lit left face.
func _faces_left(x: int, y: int, h: int) -> bool:
	# Steep edges first, then edges that are almost level on the screen.
	for probe in [Vector2i(6,2),Vector2i(24,1),Vector2i(12,1)]:
		var right := height_at(x+probe.x,y+probe.y) >= h
		if right != (height_at(x-probe.x,y+probe.y) >= h): return right
	return true

func _paint_cut(job: Dictionary, cell: Vector2i, at: Vector2i, data: Dictionary) -> void:
	var biome := biome_of(cell,data)
	var heights: PackedInt32Array = data.heights
	var decks: PackedByteArray = data.decks
	var kind := kind_of(cell,data)
	var land: Image = tiles()[biome+{"path":"_path","a":"_patch_a","b":"_patch_b"}.get(kind,"_cap")]
	var frame := scatter(cell,1)%2
	var banks := 0
	for bit: int in SIDES:
		var side := info(cell+SIDES[bit])
		if kind in ["path","a","b"] and side.k != EMPTY and side.h == data.h and not side.deck and kind_of(cell+SIDES[bit],side) != kind: banks |= bit
	var over: Image = tiles()[biome+("_path_over" if kind == "path" else "_over")]
	var planks: Image = tiles()["bridge_cap"]
	var board: int = scatter(cell,1)%4+data.boards
	var origin := at-Vector2i(20,10)
	for x in range(1,39):
		var y: int = _head[x]
		var last: int = _foot[x]
		while y <= last:
			var h: int = heights[y*40+x]
			if h == NONE: y += 1; continue
			var deck := decks[y*40+x] == 1
			var end := y
			while end < last and heights[(end+1)*40+x] == h and (decks[(end+1)*40+x] == 1) == deck: end += 1
			var dst: Vector2i = Vector2i(origin.x+x,origin.y+y-h)-job.rect.position
			if deck: job.image.blend_rect(planks,Rect2i(board*40+x,y,1,end-y+1),dst)
			else:
				job.image.blend_rect(land,Rect2i(frame*40+x,y,1,end-y+1),dst)
				if banks: job.image.blend_rect(over,Rect2i(banks%8*40+x,banks/8*24+y,1,end-y+1),dst)
			var wx: int = origin.x+x
			# Back edge: a lit rim.
			var above: int = heights[(y-1)*40+x] if y > _head[x] else height_at(wx,origin.y+y-1)
			if above < h and height_at(wx,origin.y+y-2) < h: _dot(job,wx,origin.y+y-h,WOOD[0] if deck else LIGHT[biome])
			# Front edge: a wall down to whatever is there.
			var below: int = heights[(end+1)*40+x] if end < last else height_at(wx,origin.y+end+1)
			if below < h and height_at(wx,origin.y+end+2) >= h:
				# A hairline between two pieces of one floor, less than a pixel wide: no wall belongs there.
				_dot(job,wx,origin.y+end+1-h,WOOD[2] if deck else land.get_pixel(20,10))
			elif below < h:
				var wy := origin.y+end
				_column(job,wx,wy,h,maxi(below,WATER),below == NONE,_faces_left(wx,wy,h),biome,deck)
			elif deck and below == h and not deck_at(wx,origin.y+end+1):
				_end_beam(job,wx,origin.y+end-h,-1,4)
			if deck and above == h and not deck_at(wx,origin.y+y-1):
				_end_beam(job,wx,origin.y+y-h,1,mini(4,end-y+1))
			y = end+1

## The end cap of a deck: a dark line on the ground side, then a lit beam.
func _end_beam(job: Dictionary, x: int, y: int, step: int, count: int) -> void:
	for k in count: _dot(job,x,y+step*k,[WOOD[5],WOOD[0],WOOD[1],WOOD[4]][k])

# ---------------------------------------------------------------- water

func is_shallow(cell: Vector2i) -> bool:
	var known: Variant = _shallow.get(cell)
	if known != null: return known
	var result := false
	for dx in range(-2,3):
		for dy in range(-2,3):
			if absi(dx)+absi(dy) <= 3 and info(cell+Vector2i(dx,dy)).k != EMPTY: result = true; break
		if result: break
	_shallow[cell] = result
	return result

## Rows of the water atlas: 0-2 shallow, 3-4 reflection, 5-19 shallow over deep for masks 1-15.
func _paint_water(job: Dictionary, cell: Vector2i, at: Vector2i) -> void:
	var place := Rect2i(at+Vector2i(-20,10),Vector2i(40,20))
	if not job.rect.intersects(place): return
	if not job.rect.has_point(at+Vector2i(0,20)): return
	var row := -1
	if is_shallow(cell):
		row = [0,1,2,2,1,2,2][scatter(cell,3)%7]
		if info(cell+SIDES[NE]).k != EMPTY or info(cell+SIDES[NW]).k != EMPTY: row = 3+scatter(cell,3)%2
	else:
		var mask := 0
		for bit: int in SIDES:
			if is_shallow(cell+SIDES[bit]): mask |= bit
		if mask: row = 4+mask
	if row >= 0: job.water.append_array(PackedInt32Array([place.position.x,place.position.y,row,scatter(cell,4)%4]))

static func water_atlas() -> Image:
	var sheet := tiles()
	var atlas := Image.create(160,400,false,Image.FORMAT_RGBA8)
	for row in 20:
		for f in 4:
			var name := "water_cap" if row < 3 else ("water_reflect" if row < 5 else "water_over")
			var frame: int = row*4+f if row < 3 else ((row-3)*4+f if row < 5 else row-4)
			var tall := 24 if row >= 5 else 20
			atlas.blit_rect(sheet[name],Rect2i((frame%8)*40,(frame/8)*tall,40,20),Vector2i(f*40,row*20))
	return atlas

## Four frames of open deep water, 320x160, that repeat in both directions.
static func sea_frames() -> Array:
	var sheet: Image = tiles()["water_deep"]
	var result: Array = []
	for f in 4:
		var image := Image.create(320,160,false,Image.FORMAT_RGBA8)
		for s in range(-1,17):
			for d in range(-1,9):
				var x := d*40+(20 if posmod(s,2) == 1 else 0)
				var y := s*10
				var home := Vector2i(posmod(x/20,16),posmod(s,16))
				var variant := 0 if scatter(home,31)%4 == 0 else 1
				var frame := variant*4+(f+scatter(home,32))%4
				image.blend_rect(sheet,Rect2i(frame*40,0,40,20),Vector2i(x-20,y-10))
		result.append(image)
	return result
