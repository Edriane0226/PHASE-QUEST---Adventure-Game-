@tool
extends "res://Scripts/World/Zone1/Props/grounded_prop.gd"
## Eight saved phase textures depict warming; geometry stays editor-owned.
@export var melt_frames: Array[Texture2D] = []
func _process(delta: float) -> void:
	super._process(delta)
	if kind=="ice" and amount>=1:
		puddle_age=0
		syncNativeArt()
func syncNativeArt() -> void:
	super.syncNativeArt()
	if not is_instance_valid(bodySprite) or melt_frames.size()!=8:return
	var phase:=mini(6,floori(clampf(amount,0,1)*7+.00001))
	bodySprite.texture=melt_frames[phase]
	if kind=="ice":
		bodySprite.visible=amount<1
		$CrackedIce.hide()
		for side in bodySprite.get_children():
			if side is Sprite2D:side.texture=melt_frames[phase]
		$MeltedPuddle.visible=amount>=1
		$MeltedPuddle.modulate.a=1
	elif kind=="crystal":
		$ThawedCrystal.texture=melt_frames[7]
