@tool
extends "res://Scripts/World/Zone1/Props/melting_prop.gd"
## Attunement switches between matched saved sprites without moving their base.
func syncNativeArt() -> void:
	super.syncNativeArt()
	if not is_instance_valid(bodySprite): return
	bodySprite.visible = not active
	$Attuned.visible = active
