extends Node2D
## PX-03 review scene: one screen of Stillwater (Z1L3) in the new pixel style. Not part of the game.
## Open px03_slice.tscn and run it (F6). Keys: 1 unlit, 2 lit, 3 after the puzzle, Space melts the ice,
## R restores it, E sends the explorer round, G greyscale, B colour-blind views, S silhouettes, F Reduced Effects.
## The ground is sampled from the live Zone 1 model into stillwater_sample.json.
const CAMERA := preload("res://Scripts/World/Runtime/pixel_camera.gd")
const LIGHT := preload("res://tools/art/pixel_v1/review/px03_light.gdshader")
const VIEW := preload("res://tools/art/pixel_v1/review/px03_view.gdshader")
const NE := 1
const SE := 2
const SW := 4
const NW := 8
const SIDES := {NE:Vector2i(0,-1), SE:Vector2i(1,0), SW:Vector2i(0,1), NW:Vector2i(-1,0)}
const STATES := ["solid","melting_early","melting_late","liquid","cleared"]
## Ambient and light per look. The numbers are engine settings, not palette colours.
const LOOKS := {
	"unlit":{"ambient":Vector3(1,1,1), "lights":false, "snow":false},
	"lit":{"ambient":Vector3(0.60,0.69,0.90), "lights":true, "snow":true},
	"solved":{"ambient":Vector3(1.10,0.98,0.89), "lights":true, "snow":true},
}
var sheets := {}
var cells := {}
var kind := {}
var ground: Node2D
var shadow_layer: Node2D
var things: Node2D
var flakes: Node2D
var light: Polygon2D
var camera: Camera2D
var actors: Array[Dictionary] = []
var barrier: Dictionary
var explorer: Dictionary
var old_explorer: Sprite2D
var look := "lit"
var heat := 0.0
var melting := false
var drained := -1.0
var clock := 0.0
var water_step := -1
var reduced := false
var route: PackedVector2Array = []
var route_at := 0.0
var lamps: Array[Dictionary] = []
var view_mode := 0
var centre := Vector2(-130,0)

# ---------------------------------------------------------------- sheets

func sheet(name: String) -> Dictionary:
	if sheets.has(name): return sheets[name]
	var base := ProjectSettings.globalize_path("res://assets/pixel_v1/slice/"+name)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+".json"))
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+".meta.json"))
	var tags := {}
	for tag in data.meta.frameTags: tags[tag.name] = range(int(tag.from),int(tag.to)+1)
	var entry := {"texture":ImageTexture.create_from_image(Image.load_from_file(base+".png")),
		"cell":Vector2(meta.cell[0],meta.cell[1]),"pivot":Vector2(meta.pivot[0],meta.pivot[1]),
		"frames":data.frames,"tags":tags,"clips":meta.clips}
	sheets[name] = entry
	return entry

func region(entry: Dictionary, frame: int) -> Rect2:
	var r: Dictionary = entry.frames[frame].frame
	return Rect2(r.x,r.y,r.w,r.h)

# ---------------------------------------------------------------- ground

static func at_cell(c: Vector2i) -> Vector2: return Vector2((c.x-c.y)*20,(c.x+c.y)*10)

static func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x/40+p.y/20),roundi(p.y/20-p.x/40))

func height(c: Vector2i) -> int: return cells.get(c,{"h":0}).h

func load_ground() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/pixel_v1/review/stillwater_sample.json"))
	for row in data.cells: cells[Vector2i(int(row[0]),int(row[1]))] = {"h":int(row[2]),"path":row[3]==1}
	# Landform rules 1 and 2: no single-cell bumps, and edges in steps of several cells.
	for repeat in 4:
		var next := {}
		for c: Vector2i in cells:
			var votes := {}
			for dx in range(-1,2):
				for dy in range(-1,2):
					var other: int = height(c+Vector2i(dx,dy))
					votes[other] = int(votes.get(other,0))+(2 if dx==0 and dy==0 else 1)
			var best: int = cells[c].h
			for h in votes:
				if votes[h] > int(votes.get(best,0)): best = h
			next[c] = best
		for c: Vector2i in next: cells[c].h = next[c]
	# This slice has no ramp tile, so the trail keeps to the lower ground.
	for c: Vector2i in cells:
		if cells[c].path and cells[c].h == 1: cells[c].h = 0
	for repeat in 2:
		for c: Vector2i in cells:
			if cells[c].h != 1: continue
			var near := 0
			for s in SIDES.values(): near += 1 if height(c+s) >= 1 else 0
			if near <= 1: cells[c].h = 0
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.075
	for c: Vector2i in cells:
		var n := noise.get_noise_2d(c.x,c.y)
		kind[c] = "water" if cells[c].h < 0 else ("path" if cells[c].path else ("drift" if n > 0.22 else ("hollow" if n < -0.42 else "snow")))
	# Deep water starts two cells from a bank.
	for c: Vector2i in cells:
		if cells[c].h >= 0: continue
		var near := false
		for dx in range(-2,3):
			for dy in range(-2,3):
				if absi(dx)+absi(dy) <= 3 and cells.get(c+Vector2i(dx,dy),{"h":-1}).h >= 0: near = true
		if not near: kind[c] = "deep"
	# A patch needs neighbours of its own kind; crumbs go back to plain snow.
	for repeat in 2:
		for c: Vector2i in cells:
			if not kind[c] in ["drift","hollow","deep"]: continue
			var same := 0
			for s in SIDES.values(): same += 1 if kind.get(c+s,"") == kind[c] else 0
			if same < 2: kind[c] = "water" if kind[c] == "deep" else "snow"

static func scatter(c: Vector2i, salt: int) -> int:
	var h := (c.x*374761393+c.y*668265263+salt*974634777) & 0x7fffffff
	h = ((h ^ (h >> 13))*1274126177) & 0x7fffffff
	return h >> 8

func stamp(name: String, frame: int, at: Vector2, pivot := Vector2(20,10)) -> void:
	var entry := sheet(name)
	var r := region(entry,frame)
	ground.draw_texture_rect_region(entry.texture,Rect2(at-pivot,r.size),r)

func draw_ground() -> void:
	var order := cells.keys()
	order.sort_custom(func(p,q): return p.x+p.y < q.x+q.y if p.x+p.y != q.x+q.y else p.x < q.x)
	for c: Vector2i in order:
		var h: int = cells[c].h
		var at := at_cell(c)-Vector2(0,20*h)
		var k: String = kind[c]
		var mine := 0
		var lower := 0
		var higher := 0
		for bit: int in SIDES:
			var other: Vector2i = c+SIDES[bit]
			if not cells.has(other): continue
			if height(other) < h: lower |= bit
			if height(other) > h: higher |= bit
			if kind[other] != k and height(other) == h: mine |= bit
		match k:
			"deep":
				stamp("water_deep",(0 if scatter(c,3)%3==0 else 4)+(water_step+scatter(c,4))%4,at)
				var soft := 0
				for bit: int in SIDES:
					if kind.get(c+SIDES[bit],"deep") != "deep": soft |= bit
				if soft: stamp("water_over",soft,at)
			"water":
				stamp("water_cap",[0,4,8,8,4,8,8][scatter(c,3)%7]+(water_step+scatter(c,4))%4,at)
				if higher & (NE|NW): stamp("shore",higher & (NE|NW),at)
			"path":
				stamp("path_cap",scatter(c,1)%6,at)
				if mine: stamp("path_over",mine,at)
			_:
				var name: String = {"snow":"snow_cap","drift":"snow_drift","hollow":"snow_hollow"}[k]
				var roll := scatter(c,2)%16
				# Most ground stays calm: plan rule 6 keeps about 70% of it empty.
				var frame: int = ([0,1,0,1,0,1,0,1,0,1,2,3,4,5,6,7][roll] if k=="snow" else [0,0,0,1,1,2,0,3][roll%8])
				stamp(name,frame,at)
				if k != "snow":
					var soft := 0
					for bit: int in SIDES:
						if kind.get(c+SIDES[bit],"snow") != k: soft |= bit
					if soft: stamp("snow_over",soft,at)
				if higher & (NE|NW): stamp("snow_foot",higher & (NE|NW),at)
		if h >= 0:
			if h == 0 and (higher & NE) and (higher & NW): stamp("snow_corner",1,at,Vector2(20,30))
			for bit in [SW,SE]:
				if not lower & bit: continue
				for level in range(h,height(c+SIDES[bit]),-1):
					stamp("snow_side",(0 if bit==SW else 4)+scatter(c,5+level)%4,at_cell(c)-Vector2(0,20*level))
			if (lower & SW) and (lower & SE): stamp("snow_corner",0,at)
			if lower: stamp("snow_edge",lower,at)
			if (lower & SW) and (lower & SE) and scatter(c,9)%2==0: stamp("snow_decal",4,at)
			if k in ["snow","drift"] and not lower and not higher:
				var roll := scatter(c,7)%70
				if roll < 4: stamp("snow_decal",[0,1,0,2][roll],at,Vector2(20,26))

# ---------------------------------------------------------------- things

func add(name: String, at: Vector2, clip: String, shadows := true) -> Dictionary:
	var entry := sheet(name)
	var lift := 20.0*height(cell_at(at))
	var node := Node2D.new()
	node.position = at.round()
	var sprite := Sprite2D.new()
	sprite.texture = entry.texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.position = -entry.pivot-Vector2(0,lift)
	node.add_child(sprite)
	things.add_child(node)
	var actor := {"name":name,"node":node,"sprite":sprite,"entry":entry,"clip":"","time":0.0,"next":"","lift":lift,"shadows":[]}
	if shadows and ResourceLoader.exists("res://assets/pixel_v1/slice/"+name+"_shadow.png") or FileAccess.file_exists("res://assets/pixel_v1/slice/"+name+"_shadow.png"):
		var dark := sheet(name+"_shadow")
		for tag in dark.tags:
			var s := Sprite2D.new()
			s.texture = dark.texture
			s.centered = false
			s.region_enabled = true
			s.region_rect = region(dark,dark.tags[tag][0])
			s.position = node.position-dark.pivot-Vector2(0,lift)
			s.modulate = Color(1,1,1,0.34 if tag=="idle_contact" else 0.26)
			s.set_meta("tag",tag)
			shadow_layer.add_child(s)
			actor.shadows.append(s)
	actors.append(actor)
	play(actor,clip)
	return actor

func play(actor: Dictionary, clip: String) -> void:
	actor.clip = clip
	actor.time = 0.0
	show_frame(actor)

func show_frame(actor: Dictionary) -> void:
	var frames: Array = actor.entry.tags[actor.clip]
	var t: float = actor.time*1000.0
	var total := 0.0
	for f in frames: total += actor.entry.frames[f].duration
	var settings: Dictionary = actor.entry.clips[actor.clip]
	if not settings.get("loop",false) and t >= total:
		if settings.has("next"): play(actor,settings.next)
		return
	if reduced and settings.get("loop",false): t = 0.0
	t = fmod(t,total)
	for f in frames:
		t -= actor.entry.frames[f].duration
		if t < 0:
			actor.sprite.region_rect = region(actor.entry,f)
			return

## The five states come from one number, as a provider would report it. Art never decides.
static func state_of(melt: float, gone: bool) -> String:
	if gone: return "cleared"
	if melt >= 1.0: return "liquid"
	if melt >= 0.5: return "melting_late"
	return "melting_early" if melt > 0.0 else "solid"

func show_state(state: String, at_once := false) -> void:
	if barrier.get("state","") == state: return
	var from: String = barrier.get("state","")
	barrier.state = state
	var change := "to_%s_from_%s" % [state,from]
	play(barrier,change if not at_once and not reduced and barrier.entry.tags.has(change) else "idle_"+state)
	for s: Sprite2D in barrier.shadows: s.visible = s.get_meta("tag") == "idle_"+state

# ---------------------------------------------------------------- scene

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("14141f"))
	load_ground()
	ground = Node2D.new(); add_child(ground)
	ground.draw.connect(draw_ground)
	shadow_layer = Node2D.new(); add_child(shadow_layer)
	things = Node2D.new(); things.y_sort_enabled = true; add_child(things)
	camera = Camera2D.new(); add_child(camera); camera.make_current(); camera.position = centre
	var trees := [Vector2(-408,-96),Vector2(-436,-58),Vector2(-372,-124),Vector2(-424,126),Vector2(-388,150),Vector2(30,-142),Vector2(62,-118),Vector2(160,112)]
	for p in trees: add("tree_pine",p,"idle")
	add("rocks",Vector2(-18,-104),"idle")
	var shelter := add("shelter",Vector2(-196,86),"idle_warm")
	var lantern := add("lantern",Vector2(-74,20),"idle_on")
	barrier = add("barrier_direct",Vector2(-100,-76),"idle_solid")
	show_state("solid",true)
	explorer = add("explorer",Vector2(-128,0),"idle_south")
	route = PackedVector2Array([Vector2(-128,0),Vector2(-168,0),Vector2(-182,-7),Vector2(-182,-20),Vector2(-168,-27),Vector2(-118,-27),Vector2(-104,-20),Vector2(-104,-7),Vector2(-118,0),Vector2(-128,0)])
	var frames: SpriteFrames = load("res://assets/characters/cast/explorer/frames.tres")
	old_explorer = Sprite2D.new()
	old_explorer.texture = frames.get_frame_texture("idle_south",0)
	old_explorer.scale = Vector2.ONE*0.2923077
	old_explorer.position = Vector2(1,-14-20.0*height(cell_at(Vector2(-94,4))))
	var stand := Node2D.new(); stand.position = Vector2(-94,4); stand.add_child(old_explorer); things.add_child(stand)
	flakes = Node2D.new(); flakes.z_index = 110; add_child(flakes)
	flakes.draw.connect(draw_snow)
	light = Polygon2D.new()
	light.polygon = PackedVector2Array([Vector2(-700,-420),Vector2(700,-420),Vector2(700,420),Vector2(-700,420)])
	light.z_index = 100
	light.material = ShaderMaterial.new()
	light.material.shader = LIGHT
	add_child(light)
	lamps = [
		{"at":lantern.node.position+Vector2(8,2-lantern.lift),"radius":108.0,"colour":Vector3(1.17,0.92,0.68),"flicker":true},
		{"at":shelter.node.position+Vector2(-62,10-shelter.lift),"radius":80.0,"colour":Vector3(1.18,0.88,0.60),"flicker":false},
		{"at":shelter.node.position+Vector2(34,16-shelter.lift),"radius":34.0,"colour":Vector3(1.10,0.80,0.56),"flicker":false},
	]
	set_look(look)
	frame_camera()
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()
	if "--perf" in OS.get_cmdline_user_args(): measure.call_deferred()

func frame_camera() -> void:
	var size := Vector2(get_window().size)
	var content := get_viewport().get_stretch_transform().get_scale()
	var scale_now: int = CAMERA.play_scale(size.y)
	camera.zoom = Vector2.ONE*scale_now/content
	camera.offset = (Vector2(Vector2i(size)%2)*0.5+Vector2.ONE*CAMERA.EDGE_BIAS)/scale_now

func set_look(value: String) -> void:
	look = value
	var settings: Dictionary = LOOKS[look]
	light.material.set_shader_parameter("ambient",settings.ambient)
	light.visible = look != "unlit"
	flakes.visible = settings.snow and not reduced
	for actor in actors:
		if actor.name == "shelter": play(actor,"idle_warm" if settings.lights else "idle_cold")
		if actor.name == "lantern": play(actor,"idle_on" if settings.lights else "idle_off")
	update_lights()

func update_lights() -> void:
	var places: PackedVector4Array = []
	var colours: PackedVector3Array = []
	for lamp in lamps:
		var pulse := 1.0
		if lamp.flicker and not reduced: pulse = [1.0,0.96,1.0,0.93][int(clock*5)%4]
		places.append(Vector4(lamp.at.x,lamp.at.y,roundf(lamp.radius*pulse),1.0 if look=="lit" else 0.6))
		colours.append(lamp.colour)
	while places.size() < 6:
		places.append(Vector4(0,0,1,0))
		colours.append(Vector3.ZERO)
	light.material.set_shader_parameter("place",places)
	light.material.set_shader_parameter("tint",colours)

func draw_snow() -> void:
	# 110 flakes, whole pixels, two sizes. Near flakes fall faster and drift with the wind.
	for i in 110:
		var near := i%5 == 0
		var speed := 34.0 if near else 18.0+float(i%7)
		var x := fposmod(float((i*193)%880)-float(clock)*(14.0 if near else 7.0)+sin(clock*0.8+i)*3.0,880.0)-440.0+centre.x
		var y := fposmod(float((i*317)%460)+clock*speed,460.0)-230.0
		var side := 2 if near else 1
		flakes.draw_rect(Rect2(Vector2(x,y).floor(),Vector2(side,side)),Color("e9e7db") if near else Color("c8dcea"))

func _process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	clock += delta
	frame_camera()
	for actor in actors:
		if actor == explorer: continue
		actor.time += delta
		show_frame(actor)
	if melting:
		heat = minf(heat+delta/3.2,1.0)
		if heat >= 1.0:
			if drained < 0: drained = 1.6
			drained = maxf(drained-delta,0)
		show_state(state_of(heat,drained == 0.0))
		if drained == 0.0: melting = false
	if not route.is_empty() and route_at > 0.0: walk(delta)
	else:
		explorer.time += delta
		show_frame(explorer)
	var now := int(clock/0.18) if not reduced else 0
	if now != water_step:
		water_step = now
		ground.queue_redraw()
	flakes.queue_redraw()
	update_lights()

func walk(delta: float) -> void:
	route_at += 52.0*delta
	var left := route_at
	for i in range(1,route.size()):
		var length := route[i-1].distance_to(route[i])
		if left <= length:
			explorer.node.position = route[i-1].lerp(route[i],left/length).round()
			var turn := posmod(roundi(rad_to_deg((route[i]-route[i-1]).angle())/45.0),8)
			var clip: String = "walk_"+["east","south_east","south","south_west","west","north_west","north","north_east"][turn]
			explorer.clip = clip
			# The pose follows distance: one cycle is 32 units, so feet do not slide.
			var frame: int = int(route_at/32.0*4.0)%4
			explorer.sprite.region_rect = region(explorer.entry,explorer.entry.tags[clip][frame])
			move_shadow()
			return
		left -= length
	route_at = 0.0
	explorer.node.position = route[-1]
	move_shadow()
	play(explorer,"idle_south")

func move_shadow() -> void:
	for s: Sprite2D in explorer.shadows: s.position = explorer.node.position-Vector2(32,55+explorer.lift)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: set_look("unlit")
		KEY_2: set_look("lit")
		KEY_3: solve_at_once()
		KEY_SPACE: melting = true
		KEY_R: restore()
		KEY_E: route_at = 0.01
		KEY_G: set_view(1 if view_mode != 1 else 0)
		KEY_B: set_view(2 if view_mode < 2 or view_mode >= 4 else view_mode+1)
		KEY_S: set_view(5 if view_mode != 5 else 0)
		KEY_F: reduced = not reduced; set_look(look)

func solve_at_once() -> void:
	heat = 1.0
	melting = false
	drained = 0.0
	show_state("cleared",true)
	set_look("solved")

func restore() -> void:
	heat = 0.0
	melting = false
	drained = -1.0
	show_state("solid",true)
	set_look("lit")

# ---------------------------------------------------------------- checks

## 0 normal, 1 greyscale, 2 protan, 3 deutan, 4 tritan, 5 silhouettes.
func set_view(mode: int) -> void:
	view_mode = mode
	var layer := get_node_or_null("View") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new(); layer.name = "View"; add_child(layer)
		var rect := ColorRect.new(); rect.name = "Rect"; rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = ShaderMaterial.new(); rect.material.shader = VIEW
		layer.add_child(rect)
	layer.visible = mode in [1,2,3,4]
	layer.get_node("Rect").material.set_shader_parameter("mode",mode)
	var flat := mode == 5
	ground.modulate = Color(1,1,1)
	for actor in actors: actor.sprite.modulate = Color.BLACK if flat else Color.WHITE
	ground.visible = not flat
	old_explorer.visible = not flat
	shadow_layer.visible = not flat
	light.visible = not flat and look != "unlit"
	flakes.visible = not flat and LOOKS[look].snow
	RenderingServer.set_default_clear_color(Color("c8dcea") if flat else Color("14141f"))

func shot(file: String) -> void:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_window().get_texture().get_image()
	image.save_png(OS.get_environment("SHOT_DIR")+"/"+file+".png")
	print("SHOT ",file," ",image.get_size())

func capture() -> void:
	set_process(false)
	var args := OS.get_cmdline_user_args()
	get_window().borderless = true
	var tag := "-mobile" if "--mobile" in args else ""
	for size: Vector2i in ([Vector2i(1920,1080)] if tag else [Vector2i(1920,1080),Vector2i(1280,720)]):
		get_window().size = size
		for i in 6: await get_tree().process_frame
		restore()
		var part := "%dx%d%s" % [size.x,size.y,tag]
		set_look("unlit"); step(0.2); await shot("unlit-"+part)
		set_look("lit"); step(0.2); await shot("lit-"+part)
		solve_at_once(); step(0.2); await shot("solved-"+part)
	if tag == "":
		get_window().size = Vector2i(1920,1080)
		for i in 6: await get_tree().process_frame
		restore(); step(0.1)
		for mode in [1,2,3,4]:
			set_view(mode); await shot("view-"+["","greyscale","protan","deutan","tritan"][mode])
		set_view(0)
		get_window().size = Vector2i(640,360)
		for i in 6: await get_tree().process_frame
		set_view(5); step(0.0); await shot("silhouette-1x"); set_view(0)
		await shot("lit-1x")
		if "--film" in args: await film()
	get_tree().quit()

func measure() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().borderless = true
	get_window().size = Vector2i(2400,1080)
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for value in ["unlit","lit"]:
		set_look(value)
		for i in 60: await get_tree().process_frame
		var gpu := []
		for i in 400:
			await get_tree().process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		gpu.sort()
		print("PERF ",value," 2400x1080 gpu p50 ",snappedf(gpu[200],.01)," p95 ",snappedf(gpu[380],.01))
	get_tree().quit()

func film() -> void:
	# 14 seconds at 12.5 frames a second, 640x360.
	restore()
	for i in 175:
		if i == 12: route_at = 0.01
		if i == 70: melting = true
		if i == 140: set_look("solved")
		step(0.08)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_window().get_texture().get_image().save_png("%s/film/%03d.png" % [OS.get_environment("FILM_DIR"),i])
