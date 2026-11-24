extends Node
## One occupied room. Recomputed from current ground every frame, never serialized.
var world: Node2D
var rooms: Array=[]
var occupied_id:=""
func bind(host: Node2D) -> void:
	world=host
func add_room(room: Node2D) -> void:
	rooms.append(room);recompute()
func recompute() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player):return
	rooms=rooms.filter(func(room):return is_instance_valid(room) and room.is_inside_tree() and not room.is_queued_for_deletion())
	var selected: Node2D
	# Retain current room across a 1.6px threshold band; no neighboring roof flicker.
	for room in rooms:
		if not is_instance_valid(room) or not room.is_inside_tree() or room.is_queued_for_deletion():continue
		if not world.dead and room.subregion_id==world.active_subregion_id and room.contains_ground(world.player.position,world.player._floor_height,room.room_id==occupied_id):
			if selected==null or room.room_id==occupied_id:selected=room
	occupied_id=selected.room_id if selected else ""
	for room in rooms:
		if is_instance_valid(room):room.present(room==selected)
	var camera: Camera2D=world.player.get_node("Camera2D")
	var half: Vector2=world.get_viewport_rect().size/camera.zoom*.5
	var view:=Rect2(camera.get_screen_center_position()-half,half*2).grow(180)
	for room in rooms:
		if is_instance_valid(room):room.set_culled(not view.intersects(Rect2(room.origin+Vector2(-160,-room.elevation-60),Vector2(320,220))))
func ray_fraction(from: Vector2,to: Vector2) -> float:
	var fraction:=1.0
	for room in rooms:
		if not is_instance_valid(room) or not room.is_inside_tree() or room.is_queued_for_deletion():continue
		for polygon in room.walls:
			if Geometry2D.is_point_in_polygon(from,polygon):return 0
			for i in range(polygon.size()):
				var hit: Variant=Geometry2D.segment_intersects_segment(from,to,polygon[i],polygon[(i+1)%polygon.size()])
				if hit!=null:fraction=minf(fraction,from.distance_to(hit)/maxf(.001,from.distance_to(to)))
	return fraction
func _process(_delta: float) -> void:recompute()
func _exit_tree() -> void:
	for room in rooms:
		if is_instance_valid(room):room.present(false)
