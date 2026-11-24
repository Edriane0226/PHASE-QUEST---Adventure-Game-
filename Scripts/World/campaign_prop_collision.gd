extends Node
## L1-authored texture-local footprints, scaled with the matching prop artwork.
const PROFILES = preload("res://assets/zones/zone_1/flat_v1/collision_profiles.tres")
var shapes: Array[CollisionPolygon2D] = []
func _ready(): call_deferred("build")
func build():
	var level=get_parent()
	var sprites: Array=[]
	for group in ["Scenery","Checkpoints"]:
		sprites.append_array(level.get_node(group).find_children("*","Sprite2D",true,false))
	for id in ["CacheWarmCamp","PracticeSign","SafeExit"]:
		if level.has_node(id): sprites.append(level.get_node(id))
	var profiles: Dictionary=PROFILES.get_meta("profiles")
	for sprite: Sprite2D in sprites:
		var asset=sprite.texture.resource_path.get_file().get_basename()
		# The mill foundation and science gates already own their complete solid bodies.
		if (asset not in profiles and not sprite.texture.has_meta("collision_polygon")) or sprite.has_node("Body/Footprint"): continue
		if sprite.has_node("Trunk"): sprite.get_node("Trunk").queue_free()
		var body=StaticBody2D.new()
		body.name="SharedPropBody"
		body.collision_layer=1
		body.collision_mask=0
		var shape=CollisionPolygon2D.new()
		var points=PackedVector2Array()
		var outline: PackedVector2Array=sprite.texture.get_meta("collision_polygon") if sprite.texture.has_meta("collision_polygon") else profiles[asset]
		for at in outline: points.append(at+sprite.offset)
		shape.polygon=points
		body.add_child(shape)
		sprite.add_child(body)
		sprite.set_meta("shared_collision_profile",asset)
		shapes.append(shape)
func _physics_process(_delta):
	for shape in shapes:
		var sprite=shape.get_parent().get_parent()
		shape.set_deferred("disabled",not sprite.visible)
