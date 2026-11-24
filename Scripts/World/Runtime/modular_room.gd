extends Node2D
## Presentation derives from ground occupancy. Solid bodies never follow visibility.
const ANCHOR=preload("res://Scripts/World/Runtime/grounded_visual.gd")
var room_id:=""
var subregion_id:=""
var origin:=Vector2.ZERO
var size_cubes:=Vector2(8,8)
var elevation:=0.0
var occupied:=false
var pieces: Array=[]
var bodies: Array=[]
var walls: Array=[]
var root_sort: Node2D
var biome_material:="snow"
var authored := false
static func project(uv: Vector2) -> Vector2:return Vector2((uv.x-uv.y)*20,(uv.x+uv.y)*10)
func point(uv: Vector2) -> Vector2:return origin+project(uv)
func coordinates(at: Vector2) -> Vector2:
	var p:=at-origin
	return Vector2(p.x/40+p.y/20,p.y/20-p.x/40)
func configure(record: Dictionary,sort: Node2D) -> void:
	room_id=record.id;subregion_id=record.subregion;origin=Vector2(record.origin[0],record.origin[1]);elevation=float(record.elevation);biome_material=record.material;root_sort=sort
	size_cubes=Vector2(record.size_cubes[0],record.size_cubes[1])
	for u in range(int(size_cubes.x)):
		for v in range(int(size_cubes.y)):
			_piece("floor",Vector2(u,v),false,0)
			_piece("roof",Vector2(u,v),true,60)
	for i in range(int(size_cubes.y)):
		_wall("wall_v",Vector2(0,i),Vector2(0,i+1),false)
		if i<2 or i>=5:_wall("wall_v",Vector2(size_cubes.x,i),Vector2(size_cubes.x,i+1),true)
	for i in range(int(size_cubes.x)):
		_wall("window_u" if i in [2,5] else "wall_u",Vector2(i,0),Vector2(i+1,0),false)
		_wall("wall_u",Vector2(i,size_cubes.y),Vector2(i+1,size_cubes.y),true)
	_piece("door_v",Vector2(size_cubes.x,2),true,0)
	_solid(Vector2(size_cubes.x,2),Vector2(size_cubes.x,2.18));_solid(Vector2(size_cubes.x,4.82),Vector2(size_cubes.x,5))
func bind_authored() -> void:
	var record: Dictionary = get_meta("room")
	authored=true
	room_id=record.id;subregion_id=record.subregion;origin=global_position
	elevation=record.elevation;size_cubes=record.size;biome_material=record.material
	pieces=$Pieces.get_children()
	bodies=$Walls.get_children()
	for body in bodies:
		for collider in body.get_children():
			if collider is CollisionPolygon2D:walls.append(collider.global_transform*collider.polygon)
func _piece(kind: String,uv: Vector2,cut: bool,rise: float) -> Node2D:
	var camera_facing:=cut and kind!="roof"
	if camera_facing and kind!="door_v":cut=_obstructs_work_area(kind,uv)
	var anchor=ANCHOR.new();anchor.name=(room_id+"_"+kind+"_"+str(pieces.size())).validate_node_name()
	var mid:=Vector2(.5,0) if kind.ends_with("_u") else Vector2(0,.5) if kind.ends_with("_v") else Vector2.ZERO
	if kind=="door_v":mid=Vector2(0,1.5)
	anchor.position=point(uv+mid);anchor.elevation=elevation+rise
	anchor.z_index=-1 if kind=="floor" else 2 if kind=="roof" else 0
	var sprite:=Sprite2D.new();sprite.name="Artwork";sprite.centered=false
	sprite.texture=load("res://assets/world/modular_v1/"+biome_material+"."+kind+".svg")
	sprite.position=-Vector2(64,96)-project(mid);anchor.visuals.add_child(sprite)
	anchor.set_meta("room_id",room_id);anchor.set_meta("module_id",biome_material+"."+kind);anchor.set_meta("offset_cubes",Vector3(uv.x,uv.y,rise/20));anchor.set_meta("cutaway",cut)
	anchor.set_meta("camera_facing",camera_facing)
	root_sort.add_child(anchor);pieces.append(anchor);return anchor
func _obstructs_work_area(kind: String,uv: Vector2) -> bool:
	var a:=project(uv);var b:=project(uv+(Vector2.RIGHT if kind.ends_with("_u") else Vector2.DOWN))
	var face:=PackedVector2Array([a,b,b-Vector2(0,60),a-Vector2(0,60)])
	var work:=PackedVector2Array([project(Vector2(1,1)),project(Vector2(size_cubes.x-1,1)),project(size_cubes-Vector2.ONE),project(Vector2(1,size_cubes.y-1))])
	return not Geometry2D.intersect_polygons(face,work).is_empty()
func _wall(kind: String,a: Vector2,b: Vector2,cut: bool) -> void:
	_piece(kind,a,cut,0);_solid(a,b)
func _solid(a: Vector2,b: Vector2) -> void:
	var from:=point(a);var to:=point(b);var normal: Vector2=(to-from).normalized().orthogonal()*2
	var polygon:=PackedVector2Array([from+normal,to+normal,to-normal,from-normal])
	var body:=StaticBody2D.new();body.name="Solid_"+room_id.validate_node_name();body.position=from;body.collision_layer=1;body.collision_mask=4
	var shape:=CollisionPolygon2D.new();var local:=PackedVector2Array()
	for p in polygon:local.append(p-from)
	shape.polygon=local;body.add_child(shape);add_child(body);bodies.append(body);walls.append(polygon)
func contains_ground(at: Vector2,height: float,retain:=false) -> bool:
	if not is_finite(height) or absf(height-elevation)>.5:return false
	var uv:=coordinates(at);var inset: float=-.08 if retain else .08
	return uv.x>=inset and uv.y>=inset and uv.x<=size_cubes.x-inset and uv.y<=size_cubes.y-inset
func present(value: bool) -> void:
	occupied=value
	for piece in pieces:
		if is_instance_valid(piece):piece.visible=not value or not piece.get_meta("cutaway",false)
func set_culled(value: bool) -> void:
	for piece in pieces:
		if is_instance_valid(piece):piece.visible=not value and (not occupied or not piece.get_meta("cutaway",false))
func _exit_tree() -> void:
	if authored:return
	for piece in pieces:
		if is_instance_valid(piece):
			piece.visible=true
			piece.queue_free()
