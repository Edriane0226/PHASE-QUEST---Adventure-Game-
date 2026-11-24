extends SceneTree
## Export L1's authored footprints in texture-local coordinates for shared props.
func _initialize():
	const LEGACY_GARDEN := "res://Zone_1/Levels/wrld_lvl_1.tscn"
	if not ResourceLoader.exists(LEGACY_GARDEN, "PackedScene"):
		push_error("Restore the R3 056 retirement backup into a disposable project before extracting legacy Garden collision.")
		quit(1)
		return
	var level = load(LEGACY_GARDEN).instantiate()
	var profiles={}
	for sprite in level.find_children("*","Sprite2D",true,false):
		var asset=str(sprite.get_meta("flat_asset",""))
		if asset=="fan_blade" and sprite.name!="BodySprite": continue
		var polygon=sprite.get_parent().get_node_or_null("CollisionBody/Footprint")
		if polygon==null: polygon=sprite.get_parent().get_node_or_null("Body/Footprint")
		if polygon==null: polygon=sprite.get_parent().get_node_or_null("PickupBody/Footprint")
		if asset.is_empty() or polygon==null or profiles.has(asset): continue
		var points=PackedVector2Array()
		for at in polygon.polygon:
			points.append(sprite.to_local(polygon.to_global(at))-sprite.offset)
		profiles[asset]=points
	var resource=Resource.new()
	resource.set_meta("profiles",profiles)
	var error=ResourceSaver.save(resource,"res://assets/zones/zone_1/flat_v1/collision_profiles.tres")
	print("Exported ",profiles.size()," L1 prop collision profiles")
	level.free()
	quit(0 if error==OK else 1)
