@tool
extends "res://Scripts/World/Zone1/Props/melting_prop.gd"
## Grounded collectibles keep their authored base instead of bobbing above it.
func syncNativeArt() -> void:
	super.syncNativeArt()
	if not is_instance_valid(bodySprite): return
	if kind in ["crystal","blades"]: bodySprite.position = artHome
	if kind=="crystal":
		bodySprite.visible = not active and amount<1.0
		$ThawedCrystal.visible = not active and amount>=1.0
	if kind in ["wood","blades","crystal"]:
		var shadow := get_node_or_null("GroundContact")
		if shadow: shadow.visible = not active
		for body in get_children():
			if body is StaticBody2D:
				for shape in body.get_children():
					if shape is CollisionPolygon2D and shape.disabled!=active: shape.set_deferred("disabled",active)
