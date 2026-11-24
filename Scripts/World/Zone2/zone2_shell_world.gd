extends "res://Scripts/World/Runtime/phase_world.gd"
## Non-ready terrain integration scene. Only an explicit isolated fixture profile can mount it.
const GEOMETRY=preload("res://Scripts/World/Zone2/zone2_geometry.gd")
const ART=preload("res://Scripts/World/Zone2/zone2_ground_art.gd")
const ANCHOR=preload("res://Scripts/World/Runtime/grounded_visual.gd")
var geometry: RefCounted
var ground_art: Node2D
var professor: Node2D
var permission_bodies: Array=[]
var props: Array=[]
var zero_area_bank_fragments:=0
var _kit: Resource
var _kit_entries: Dictionary={}
func _ready() -> void:
	development_preview=true;super._ready()
	if not fixture_session() or not get_node("/root/PlayerSave").get_meta("r3_017_permissions",false):
		input_adapter.feedback="Zone 2 terrain shells await campaign integration.";input_adapter.refresh();return
	geometry=GEOMETRY.new()
	if not geometry.load_data():last_error="Zone 2 shell geometry unavailable.";return
	ground_art=ART.new();ground_art.name="NativeZoneTerrain";add_child(ground_art);ground_art.configure(geometry)
	for number in range(1,7):
		var chunk=load("res://World/Zone2/Z2L%dShell.tscn"%number).instantiate();chunk.configure_geometry(geometry)
		if not mount_chunk(chunk):last_error="Cannot mount Zone 2 shell "+str(number);return
	_kit=load("res://assets/zones/zone_2/world_v1/kit_atlas.tres")
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_2/world_v1/kit_catalog.json"))
	for entry in catalog.entries:
		if not _kit_entries.has(entry.group):_kit_entries[entry.group]=entry
		_kit_entries[entry.id]=entry
	build_geometry_bodies();build_art()
	var routes_path:="res://World/Data/zone2-routes.json"
	if FileAccess.file_exists(routes_path):
		var routes_data=JSON.parse_string(FileAccess.get_file_as_string(routes_path))
		if routes_data is Dictionary and routes_data.get("geometry_hash")==FileAccess.get_sha256(GEOMETRY.DATA):ground_art.routes=routes_data.routes;ground_art.queue_redraw()
	subregion_changed.connect(_move_professor)
	set_fixture_permissions(1,false)
	activate("Z2L1",geometry.v(geometry.data.regions[0].entry))
func sprite_asset(id: String,point: Vector2,name_hint: String) -> Node2D:
	var definition: Dictionary=_kit_entries.get(id,{})
	if definition.is_empty():return null
	var anchor=ANCHOR.new();anchor.name=name_hint.validate_node_name();anchor.position=point;anchor.elevation=float(geometry.height_record(point).get("height",0));$GroundSort.add_child(anchor)
	var sprite:=Sprite2D.new();sprite.name="Artwork";sprite.centered=false;sprite.texture=_kit.get_meta("tiles",{}).get(definition.id)
	if sprite.texture==null:sprite.texture=load(definition.path)
	sprite.scale=Vector2.ONE*float(definition.world_scale);sprite.position=-Vector2(definition.pivot_px[0],definition.pivot_px[1])*float(definition.world_scale);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	anchor.visuals.add_child(sprite);anchor.set_meta("asset_id",definition.id);anchor.set_meta("ground_xy",point)
	props.append(anchor);return anchor
func build_art() -> void:
	for decoration in geometry.data.decorations:sprite_asset(decoration.asset,geometry.v(decoration.at),"Scenery_"+str(props.size()))
	for decoration in geometry.relief.clustered_decorations(geometry):sprite_asset(decoration.asset,decoration.at,"NaturalCluster_"+str(props.size()))
	for placement in geometry.data.equipment:
		var art:=sprite_asset(placement.asset,geometry.v(placement.at),placement.station+"_"+placement.asset)
		if art:art.set_meta("station_id",placement.station)
	for s in geometry.data.stations:
		var at: Vector2=geometry.v(s.ground_xy)
		if s.kind=="checkpoint":sprite_asset("landing",at+Vector2(-65,-52),s.id+"_SafeDeck")
		elif s.kind=="assessor":
			var anchor=ANCHOR.new();anchor.name="FinnCapstone";anchor.position=at;anchor.elevation=float(geometry.height_record(at).get("height",0));$GroundSort.add_child(anchor)
			var actor=load("res://Actors/Characters/CastActor.tscn").instantiate();actor.cast_id="finn";anchor.visuals.add_child(actor)
	for stop in geometry.data.exploration_stops:sprite_asset("flowers",geometry.v(stop.ground_xy)+Vector2(-65,-40),stop.id+"_Scenery")
	professor=ANCHOR.new();professor.name="SharedProfessorZ2";$GroundSort.add_child(professor)
	var actor=load("res://Actors/Characters/CastActor.tscn").instantiate();actor.cast_id="professor_z2";professor.visuals.add_child(actor)
	for reserve in geometry.data.travel_reserves:
		var marker:=Marker2D.new();marker.name=reserve.id.validate_node_name();marker.position=geometry.v(reserve.local_anchor);marker.set_meta("travel_contract",reserve);$GroundSort.add_child(marker)
func make_body(points: PackedVector2Array,layer: int,name_hint: String) -> StaticBody2D:
	# Triangulation loses precision for sub-unit bank fragments at large world XY.
	# Keep physical shapes local; translation preserves their exact world footprint.
	var origin: Vector2=points[0];var local:=PackedVector2Array()
	for point in points:local.append(point-origin)
	var pieces: Array=[local]
	if Geometry2D.triangulate_polygon(local).is_empty():pieces=Geometry2D.offset_polygon(local,.01)
	var valid: Array=[]
	for piece in pieces:
		if Geometry2D.triangulate_polygon(piece).is_empty():continue
		valid.append(piece)
	if valid.is_empty():
		var twice_area:=0.0
		for j in range(local.size()):twice_area+=float(local[j].x)*float(local[(j+1)%local.size()].y)-float(local[(j+1)%local.size()].x)*float(local[j].y)
		if name_hint=="WaterBank" and absf(twice_area)*.5<.01:zero_area_bank_fragments+=1;return null
		push_error("Invalid nonzero physical boundary: "+name_hint);return null
	var body:=StaticBody2D.new();body.name=name_hint.validate_node_name();body.position=origin;body.collision_layer=layer;body.collision_mask=4
	for piece in valid:
		var shape:=CollisionPolygon2D.new();shape.polygon=piece;body.add_child(shape)
	$GroundSort.add_child(body);return body
func edge_polygon(from: Vector2,to: Vector2,width:=3.0) -> PackedVector2Array:
	var normal: Vector2=(to-from).normalized().orthogonal()*width
	return PackedVector2Array([from+normal,to+normal,to-normal,from-normal])
func build_geometry_bodies() -> void:
	for i in range(6):
		var p: PackedVector2Array=geometry.region_polygons[i];var bodies: Array=[]
		for j in range(p.size()):bodies.append(make_body(edge_polygon(p[j],p[(j+1)%p.size()],5),8,"Permission_"+str(i)+"_"+str(j)))
		permission_bodies.append(bodies)
	for b in geometry.blockers:
		make_body(b.polygon,b.layer,"LandscapeSolid")
	# Coast/water banks leave recorded bridge decks open. Never infer support from painted water.
	for points in geometry.data.water:
		var p: PackedVector2Array=geometry.polygon(points)
		for j in range(p.size()):
			var from: Vector2=p[j];var to: Vector2=p[(j+1)%p.size()]
			if geometry.region_at((from+to)/2).is_empty():continue
			var pieces: Array=[edge_polygon(from,to,2)]
			for bridge in geometry.bridges:
				var next: Array=[]
				for piece in pieces:next.append_array(Geometry2D.clip_polygons(piece,bridge))
				pieces=next
			for piece in pieces:
				if piece.size()>=3:
					var bank:=make_body(piece,1,"WaterBank")
					if bank:geometry.add_blocker(piece,geometry.region_at((from+to)/2),1)
	for i in range(6):
		var p: PackedVector2Array=geometry.region_polygons[i]
		for j in range(p.size()):
			var from: Vector2=p[j];var to: Vector2=p[(j+1)%p.size()];var middle: Vector2=(from+to)/2;var normal: Vector2=(to-from).normalized().orthogonal()*10
			if geometry.region_at(middle+normal).is_empty() or geometry.region_at(middle-normal).is_empty():
				var shape:=edge_polygon(from,to,3);make_body(shape,1,"OuterCoast");geometry.add_blocker(shape,"",1)
func set_fixture_permissions(completed_prefix: int,open_science: bool) -> bool:
	if geometry==null or not fixture_session() or not get_node("/root/PlayerSave").get_meta("r3_017_permissions",false):return false
	input_adapter.stop_all("fixture_permissions",true)
	geometry.prefix=clampi(completed_prefix,0,6);geometry.science_open=open_science
	for i in range(6):
		for body in permission_bodies[i]:body.collision_layer=0 if i<geometry.prefix else 8
	# Closing a test fixture never strands its reviewer on a removed conditional deck.
	if not active_subregion_id.is_empty() and (not geometry.permitted(player.position) or not geometry.supported_box(Rect2(player.position-Vector2(10,11),Vector2(20,22)))):
		var index:=clampi(SAVE_LEVEL-1,0,maxi(0,geometry.prefix-1))
		var destination: Dictionary=geometry.data.regions[index]
		activate(destination.id,geometry.v(destination.entry))
	ground_art.queue_redraw();return true
func raised_surface(point: Vector2,_margin:=0.0) -> Dictionary:
	if geometry==null:return {}
	var record: Dictionary=geometry.height_record(point)
	return record
func valid_landing(point: Vector2) -> bool:
	if geometry==null or not point.is_finite() or not geometry.standable(point,false,true,true):return false
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=player.get_node("CollisionShape2D").shape;query.transform=Transform2D(0,point);query.collision_mask=11;query.exclude=[player.get_rid()]
	var surface:=raised_surface(point)
	if is_instance_valid(surface.get("body")):query.exclude.append(surface.body.get_rid())
	return player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func unsupported_fall(point: Vector2) -> bool:
	return geometry==null or not geometry.supported_box(Rect2(point-Vector2(10,11),Vector2(20,22)))
func player_controls_allowed() -> bool:
	return super.player_controls_allowed() and geometry!=null and geometry.permitted(player.position)
func _physics_process(_delta: float) -> void:
	if geometry==null or active_subregion_id.is_empty():return
	var owner: String=geometry.region_at(player.position)
	if owner.is_empty() or owner==active_subregion_id or not geometry.permitted(player.position):return
	_active_chunk_id=owner+".shell";active_subregion_id=owner
	var definition=REGISTRY.definition(owner);SAVE_ZONE=definition.zone_id;SAVE_LEVEL=definition.level
	_move_professor(owner);subregion_changed.emit(owner);input_adapter.refresh()
func _move_professor(id: String) -> void:
	if not is_instance_valid(professor):return
	for s in geometry.data.stations:
		if s.subregion==id and s.kind=="professor":professor.position=geometry.v(s.ground_xy);professor.elevation=float(geometry.height_record(professor.position).get("height",0));return
