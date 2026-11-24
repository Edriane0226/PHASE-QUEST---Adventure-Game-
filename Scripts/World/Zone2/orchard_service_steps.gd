extends Node
## One-cube rise. Use the same surfaces for ordinary jumping, save validation and display.
const REGION := "Z2L2"
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const TILE = preload("res://assets/world/shared_terrain/v1/svg/grass_tile_e15_h20.svg")
var model: RefCounted
var host: Node2D
var paths: Array[String] = []
var visuals: Array[Node2D] = []
var _plinth: Dictionary

func install(world: Node2D, chunk: Node2D, curb: Vector2, plinth: Vector2) -> void:
	host = world
	model = world.geometry.region_models[REGION]
	_step(chunk, "OrchardCurb", curb, 1)
	_plinth = _step(chunk, "OrchardPlinth", plinth, 2)
	set_plinth_access(false)

func set_plinth_access(open: bool) -> void:
	# Layer 1 stays solid during jumps. Layer 2 permits the ordinary hop.
	var layer := 2 if open else 1
	_plinth.body.collision_layer = layer
	_plinth.blocker.layer = layer

func _step(chunk: Node2D, path: String, center: Vector2, width: int) -> Dictionary:
	var height: float = host.raised_surface(center).height + 20
	var half := Vector2(40,20) * width
	var poly := PackedVector2Array([Vector2(0,-half.y),Vector2(half.x,0),Vector2(0,half.y),Vector2(-half.x,0)])
	var body := StaticBody2D.new()
	body.position = center - chunk.ground_origin
	body.collision_layer = 2
	body.collision_mask = 4
	var shape := CollisionPolygon2D.new()
	shape.polygon = poly
	body.add_child(shape)
	chunk.add_child(body)
	host.source_bodies[REGION+":"+path] = body
	paths.append(path)
	var ground := Transform2D(0,center) * poly
	model.add_floor(ground,REGION,"platform",20,false,path)
	model.add_blocker(ground,REGION,2,false,path)
	var blocker: Dictionary = model.blockers.back()
	for u in width:
		for v in width:
			var tile = ANCHOR.new()
			tile.position = center + Vector2(40*(u-v),20*(u+v-width+1))
			tile.elevation = height
			tile.z_index = -1
			host.district_art_parent(chunk).add_child(tile)
			visuals.append(tile)
			var sprite := Sprite2D.new()
			sprite.texture = TILE
			sprite.scale = Vector2.ONE * 0.5
			tile.visuals.add_child(sprite)
	return {"body":body, "blocker":blocker}

func _exit_tree() -> void:
	if model == null:
		return
	var floors: Array = model.floors.filter(func(r): return r.body_path not in paths)
	var blockers: Array = model.blockers.filter(func(r): return r.source_path not in paths)
	model.floors = []
	model.floor_bins = {}
	model.blockers = []
	model.blocker_bins = {}
	for record in floors: model.index_record(record,model.floors,model.floor_bins)
	for record in blockers: model.index_record(record,model.blockers,model.blocker_bins)
	for path in paths: host.source_bodies.erase(REGION+":"+path)
	for tile in visuals:
		if is_instance_valid(tile): tile.queue_free()
