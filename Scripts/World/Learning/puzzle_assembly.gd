extends Node
## Independent components. Grid footprints, visual pivots and physical bounds are separate.
const ANCHOR=preload("res://Scripts/World/Runtime/grounded_visual.gd")
const ROOM=preload("res://Scripts/World/Runtime/modular_room.gd")
const SUPPORT=preload("res://Scripts/World/terrain_support_profiles.gd")
var assembly_id:=""
var origin:=Vector2.ZERO
var elevation:=0.0
var footprint:=Vector2.ZERO
var world: Node2D
var chunk: Node2D
var parts: Dictionary={}
var specs: Dictionary={}
var bodies: Dictionary={}
var interactions: Dictionary={}
var interaction_markers: Dictionary={}
var support_bounds: Dictionary={}
var part_elevations: Dictionary={}
var error:=""
static func vector2(value: Variant) -> Vector2:
	if value is Vector2:return value
	return Vector2(value[0],value[1]) if value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) else Vector2(INF,INF)
static func safe_id(value: Variant) -> bool:return value is String and not value.is_empty() and not "/" in value and not ":" in value and value.length()<=96
func configure(definition: Dictionary,host: Node2D,owner_chunk: Node2D) -> bool:
	if not parts.is_empty() or not safe_id(definition.get("id")):return false
	world=host;chunk=owner_chunk;assembly_id=definition.id;origin=vector2(definition.get("origin_ground"));footprint=vector2(definition.get("footprint_cubes"))
	if not origin.is_finite() or not footprint.is_finite() or footprint.x<=0 or footprint.y<=0 or not definition.get("components") is Array:return false
	var ground: Dictionary=world.raised_surface(origin)
	if ground.is_empty():error="Assembly requires real supported ground.";return false
	elevation=float(ground.height)
	# Validate every component before creating any art/body. No texture stretching/snapping.
	for spec in definition.components:
		if not spec is Dictionary or not safe_id(spec.get("id")) or specs.has(spec.id):error="Duplicate/invalid component ID.";return false
		var offset: Variant=spec.get("offset_cubes");var size:=vector2(spec.get("footprint_cubes"))
		if not offset is Array or offset.size()!=3 or not size.is_finite() or size.x<=0 or size.y<=0:return false
		for value in offset:
			if not (value is int or value is float) or not is_finite(float(value)):return false
		var pivot: Vector2=vector2(spec.get("ground_pivot_cubes",[0,0]))
		if not pivot.is_finite():return false
		var rear:=Vector2(offset[0],offset[1])-pivot
		if rear.x<0 or rear.y<0 or rear.x+size.x>footprint.x+.001 or rear.y+size.y>footprint.y+.001 or offset[2]<0:return false
		if not (spec.get("height_layers") is int or spec.get("height_layers") is float) or not is_finite(float(spec.height_layers)) or spec.height_layers<0:return false
		if not spec.get("variants") is Dictionary or spec.variants.is_empty() or not spec.get("initial") is Dictionary:return false
		for visual in spec.variants.values():
			if not visual is Dictionary:return false
			if spec.get("kind","")=="state_effect":
				if _polygon(visual.get("polygon")).size()<3 or not visual.get("color") is String:return false
			elif not visual.get("path") is String or not ResourceLoader.exists(visual.path,"Texture2D") or not vector2(visual.get("pivot_px")).is_finite() or not (visual.get("scale") is float or visual.get("scale") is int) or not is_finite(float(visual.scale)) or visual.scale<=0:return false
		var point:=ground_point(spec)
		if not point.is_finite():return false
		# Validate occupied footprint at real floor elevation, not sprite overlap.
		var part_height:=elevation
		if definition.get("stepped_floor",false):
			part_height=float(world.raised_surface(point).get("height",INF))
		for corner in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y),size*.5]:
			var at: Vector2=point+ROOM.project(corner-pivot)
			var support: Dictionary=world.raised_surface(at)
			if support.is_empty() or absf(float(support.height)-part_height)>.5 or not _supported(at):error="Component %s lacks matching stacked support."%spec.id;return false
		for field in ["collision_bounds","support_bounds","interaction_bounds"]:
			var polygon:=_polygon(spec.get(field,[]))
			if spec.get(field,[])!=[] and (polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty()):return false
		if spec.get("collision_layer",1) not in [1,2]:return false
		part_elevations[spec.id]=part_height
		specs[spec.id]=spec.duplicate(true)
	for spec in specs.values():_build(spec)
	return true
func _supported(at: Vector2) -> bool:
	if world.get("geometry")!=null:return world.geometry.supported_box(SUPPORT.foot_rect(at))
	return world.valid_landing(at)
func ground_point(spec: Dictionary) -> Vector2:
	if spec.has("legacy_local_xy"):return chunk.ground_origin+vector2(spec.legacy_local_xy)
	var offset: Array=spec.offset_cubes
	return origin+ROOM.project(Vector2(offset[0],offset[1]))
func _polygon(values: Variant) -> PackedVector2Array:
	var result:=PackedVector2Array()
	if not values is Array:return result
	for value in values:
		var point:=vector2(value)
		if not point.is_finite():return PackedVector2Array()
		result.append(point)
	return result
func _build(spec: Dictionary) -> void:
	var anchor=ANCHOR.new();anchor.name=(assembly_id+"_"+spec.id).validate_node_name();anchor.position=ground_point(spec);anchor.elevation=float(part_elevations[spec.id])+float(spec.offset_cubes[2])*20
	anchor.z_index=int(spec.get("z_index",0));anchor.set_meta("assembly_id",assembly_id);anchor.set_meta("component_id",spec.id)
	world.district_art_parent(chunk).add_child(anchor);parts[spec.id]=anchor
	var sprite: Node2D=Polygon2D.new() if spec.get("kind","")=="state_effect" else Sprite2D.new();sprite.name="Artwork"
	if sprite is Sprite2D:sprite.centered=false
	anchor.visuals.add_child(sprite)
	var polygon:=_polygon(spec.get("collision_bounds",[]))
	if not polygon.is_empty():
		var body:=StaticBody2D.new();body.name=(assembly_id+"_"+spec.id+"_Solid").validate_node_name();body.position=anchor.position-chunk.ground_origin;body.collision_layer=int(spec.get("collision_layer",1));body.collision_mask=4
		var shape:=CollisionPolygon2D.new();shape.polygon=polygon;body.add_child(shape);chunk.add_child(body);bodies[spec.id]=body
	interactions[spec.id]=_polygon(spec.get("interaction_bounds",[]));support_bounds[spec.id]=_polygon(spec.get("support_bounds",[]))
	var marker:=Marker2D.new();marker.name=(assembly_id+"_"+spec.id+"_Touch").validate_node_name();marker.position=anchor.position-chunk.ground_origin-Vector2(0,anchor.elevation);chunk.add_child(marker);interaction_markers[spec.id]=marker
func initial_state() -> Dictionary:
	var result: Dictionary={}
	for id in specs:result[assembly_id+"/"+id]=specs[id].initial.duplicate(true)
	return result
func present(states: Dictionary,owners: Dictionary,locations: Dictionary={}) -> void:
	for id in parts:
		var spec: Dictionary=specs[id];var state: Dictionary=states.get(assembly_id+"/"+id,spec.initial)
		var variant: String=str(state.get(spec.get("visual_field","phase"),spec.get("default_variant","default")))
		var visual: Dictionary=spec.variants.get(variant,spec.variants.values()[0])
		var anchor=parts[id];var sprite: Node2D=anchor.visuals.get_node("Artwork")
		if sprite is Polygon2D:sprite.polygon=_polygon(visual.polygon);sprite.color=Color(visual.color)
		else:
			var texture=load(visual.path)
			if sprite.texture!=texture:sprite.texture=texture
			sprite.scale=Vector2.ONE*float(visual.scale);sprite.position=-vector2(visual.pivot_px)*float(visual.scale)
		# Item visibility is derived from its one committed owner, never treated as state.
		if spec.has("item_id"):
			var owner: String=owners.get(spec.item_id,"world:"+assembly_id+"/"+id)
			anchor.visible=owner!="player"
			anchor.position=locations.get(owner.get_slice(":",1),ground_point(spec)) if owner!="player" else ground_point(spec)
			if bodies.has(id):
				bodies[id].collision_layer=0 if owner=="player" else int(spec.get("collision_layer",1));bodies[id].position=anchor.position-chunk.ground_origin
func marker(component: String) -> Node2D:return parts.get(component)
func contains_interaction(component: String,at: Vector2) -> bool:
	return parts.has(component) and interactions[component].size()>=3 and Geometry2D.is_point_in_polygon(at-parts[component].position,interactions[component])
func dispose(detach:=true) -> void:
	for node in parts.values()+bodies.values()+interaction_markers.values():
		if is_instance_valid(node):
			if detach and node.get_parent():node.get_parent().remove_child(node)
			node.queue_free()
	parts.clear();bodies.clear();interaction_markers.clear()
func _exit_tree() -> void:dispose(false)
