extends Node
## The side rails and both gates block walking, jumping and Fire independently of art.
const PARTS = preload("res://Scripts/World/Zone2/stream_circuit_assembly.gd")
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const RISE := 40.0
const RIDE := Rect2(-47,-35,94,70)
const UPPER := Rect2(47,-35,101,70)
const GAP := Rect2(148,-35,42,70)
const EXIT := Rect2(190,-35,94,70)
const DECK_PATH := "StreamLiftDeck"
const UPPER_PATH := "StreamUpperLanding"
const EXIT_PATH := "StreamExitDeck"
var deck_floor: Dictionary
var lift_at: Vector2
var ground_height: float
var visual_height: float
var visual_target: float
var _world: Node2D
var _chunk: Node2D
var _model: RefCounted
var _owned: Array[String] = []
var _visuals: Array[Node2D] = []
var _deck: Node2D
var _entry_gate: Dictionary
var _landing_gate: Dictionary

func install(world: Node2D, chunk: Node2D, at: Vector2) -> void:
	_world = world
	_chunk = chunk
	_model = world.geometry.region_models[PARTS.REGION]
	lift_at = at
	ground_height = world.raised_surface(at).height
	visual_height = ground_height
	visual_target = ground_height
	deck_floor = _floor(RIDE,DECK_PATH,0)
	_floor(UPPER,UPPER_PATH,RISE)
	_floor(EXIT,EXIT_PATH,RISE)
	_deck = _surface(RIDE,0)
	_surface(UPPER,RISE)
	_surface(EXIT,RISE)
	_entry_gate = _barrier(Rect2(-50,-37,6,74),"StreamLowerGate",1,0)
	_landing_gate = _barrier(Rect2(44,-37,6,74),"StreamUpperGate",1,RISE)
	_barrier(GAP,"StreamWalkGap",2,0,false)
	for index in 6:
		var x := -50.0+float(index)*56
		for y in [-40,35]:
			var rail := Rect2(x,y,56,5)
			_barrier(rail,"StreamSide%d_%d" % [index,int(y)],1,RISE)
	_barrier(Rect2(279,-39,7,78),"StreamEndRail",1,RISE)

func _floor(local: Rect2, path: String, height: float) -> Dictionary:
	var record := Rect2(lift_at+local.position,local.size)
	_model.add_floor(_model.rect_poly(record),PARTS.REGION,"platform",height,false,path)
	_owned.append(path)
	return _model.floors.back()

func _anchor(at: Vector2, elevation: float) -> Node2D:
	var anchor := ANCHOR.new()
	anchor.position = at
	anchor.elevation = ground_height+elevation
	_world.get_node("GroundSort").add_child(anchor)
	_visuals.append(anchor)
	return anchor

func _face(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var face := Polygon2D.new()
	face.polygon = points
	face.color = color
	parent.add_child(face)

func _surface(local: Rect2, elevation: float) -> Node2D:
	var anchor := _anchor(lift_at+Vector2(local.position.x,local.end.y),elevation)
	anchor.z_index = -1
	var top := Rect2(Vector2(0,-local.size.y),local.size)
	_face(anchor.visuals,_model.rect_poly(top),Color("af9465"))
	_face(anchor.visuals,_model.rect_poly(Rect2(0,0,top.size.x,8)),Color("6c503a"))
	for x in range(12,int(top.size.x),14):
		_face(anchor.visuals,_model.rect_poly(Rect2(float(x),top.position.y,1.5,top.size.y)),Color("85684c"))
	return anchor

func _barrier(local: Rect2, path: String, layer: int, elevation: float, visible_rail := true) -> Dictionary:
	var rect := Rect2(lift_at+local.position,local.size)
	var body := StaticBody2D.new()
	body.position = rect.get_center()-_chunk.ground_origin
	body.collision_layer = layer
	body.collision_mask = 4
	var box := RectangleShape2D.new()
	box.size = rect.size
	var shape := CollisionShape2D.new()
	shape.shape = box
	body.add_child(shape)
	_chunk.add_child(body)
	_model.add_blocker(_model.rect_poly(rect),PARTS.REGION,layer,false,path)
	_owned.append(path)
	var art: Node2D
	if visible_rail:
		art = _anchor(rect.get_center(),elevation)
		_face(art.visuals,_model.rect_poly(Rect2(-rect.size/2-Vector2(0,9),rect.size+Vector2(0,7))),Color("6f6047"))
		_face(art.visuals,_model.rect_poly(Rect2(-rect.size/2-Vector2(0,10),rect.size)),Color("d3b981"))
	return {"body":body,"record":_model.blockers.back(),"art":art}

func _set_gate(gate: Dictionary, open: bool) -> void:
	var layer := 0 if open else 1
	gate.record.layer = layer
	gate.body.collision_layer = layer
	gate.art.visible = not open

func apply(measured: bool, stage: String, snap: bool) -> void:
	_set_gate(_entry_gate,measured)
	_set_gate(_landing_gate,stage == "locked")
	deck_floor.height = 0 if stage == "lowered" else RISE
	visual_target = ground_height+float(deck_floor.height)
	if snap:
		visual_height = visual_target
		_deck.elevation = visual_height

func advance(delta: float) -> void:
	visual_height = move_toward(visual_height,visual_target,320.0*delta)
	_deck.elevation = visual_height

func boarded(at: Vector2) -> bool:
	return RIDE.grow(-13).has_point(at-lift_at)

func docked(actor: Node2D) -> bool:
	return boarded(actor.position) and is_equal_approx(visual_height,ground_height+RISE) and absf(actor._display_floor-visual_height) < 1.0

func _exit_tree() -> void:
	if _model == null:
		return
	var floors: Array = _model.floors.filter(func(record):return record.body_path not in _owned)
	var blockers: Array = _model.blockers.filter(func(record):return record.source_path not in _owned)
	_model.floors = []
	_model.floor_bins = {}
	_model.blockers = []
	_model.blocker_bins = {}
	for record in floors: _model.index_record(record,_model.floors,_model.floor_bins)
	for record in blockers: _model.index_record(record,_model.blockers,_model.blocker_bins)
	for art in _visuals:
		if is_instance_valid(art): art.queue_free()
