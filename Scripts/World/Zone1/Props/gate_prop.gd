@tool
extends "res://Scripts/World/Zone1/Props/melting_prop.gd"
## The door releases with the science/reward gate; stone columns stay solid.
func syncNativeArt() -> void:
	super.syncNativeArt()
	if not is_instance_valid(bodySprite): return
	bodySprite.visible = not active
	$OpenGate.visible = active
	$CollisionBody/Footprint.set_deferred("disabled",active)
	if has_node("OpenLeftContact"):
		$GroundContact.visible = not active
		$OpenLeftContact.visible = active
		$OpenRightContact.visible = active
