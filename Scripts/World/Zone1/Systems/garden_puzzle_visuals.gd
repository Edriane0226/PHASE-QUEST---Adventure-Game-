extends Node
## Binds the saved Level 1 art to existing puzzle/save state; creates no geometry.
var level
var fan_blades: Sprite2D
var fan_angle: Sprite2D
var warm_lights: Array[PointLight2D] = []

func _ready() -> void:
	call_deferred("_bind")

func _bind() -> void:
	level = get_parent()
	level.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	level.player.get_node("AnimatedSprite2D").texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if level.has_node("Actors/vent/FanFace/Blades"):
		fan_blades = level.get_node("Actors/vent/FanFace/Blades")
		fan_angle = level.get_node("Actors/vent/VentRotor")
		for prop_name in ["brazier0", "brazier1", "brazier2", "receiver"]:
			warm_lights.append(level.get_node("Actors/" + prop_name + "/WarmLight"))
	sync_art(0.0)

func _process(_delta: float) -> void:
	if is_instance_valid(level):
		sync_art()

func sync_art(_delta := 0.0) -> void:
	if is_instance_valid(fan_blades):
		fan_blades.rotation = fan_angle.rotation
		fan_blades.visible = level.props.vent.active
		for light in warm_lights:
			light.visible = light.get_parent().active
