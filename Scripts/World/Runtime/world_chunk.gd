extends Node2D
## Chunk owns translated local geometry/state providers, never player/HUD/camera.
@export var chunk_id:=""
@export var subregion_id:=""
@export var ground_origin:=Vector2.ZERO
@export var fixture_only:=false
@export var surface_name:="snow"
var surfaces: Array=[]
var runtime_provider: Node
var context_provider: Node
var checkpoint_provider: Node
var optional_activity: Node
var quests: Array=[]
var tutorial:=""
func _ready() -> void:
	position=ground_origin;y_sort_enabled=true
func frame_valid() -> bool:
	return ground_origin.is_finite() and position==ground_origin and scale.is_equal_approx(Vector2.ONE) and is_zero_approx(rotation) and not top_level
func register_surface(polygon: PackedVector2Array,height:=0.0) -> bool:
	if polygon.size()<3 or not is_finite(height):return false
	for p in polygon:
		if not p.is_finite():return false
	surfaces.append({"polygon":polygon,"height":height});return true
func height_record(local: Vector2,_margin:=0.0) -> Dictionary:
	if is_instance_valid(runtime_provider) and runtime_provider.has_method("raised_surface"):return runtime_provider.raised_surface(local,_margin)
	var result: Dictionary={}
	for surface in surfaces:
		if Geometry2D.is_point_in_polygon(local,surface.polygon) and (result.is_empty() or surface.height>result.height):result={"height":surface.height}
	return result
func ground_polygons() -> Array:
	var result: Array=[]
	for surface in surfaces:
		var world:=PackedVector2Array()
		for p in surface.polygon:world.append(p+ground_origin)
		result.append(world)
	return result
func context_record() -> Dictionary:
	if is_instance_valid(optional_activity):
		var practice: Dictionary=optional_activity.world_context()
		if not practice.is_empty() or optional_activity.holding_item():return practice
	return context_provider.world_context() if is_instance_valid(context_provider) and context_provider.has_method("world_context") else {}
func checkpoint_records() -> Array:
	return checkpoint_provider.world_checkpoints() if is_instance_valid(checkpoint_provider) and checkpoint_provider.has_method("world_checkpoints") else []
