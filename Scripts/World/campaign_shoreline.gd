extends RefCounted
## Solid outer banks, explicit interior fall gaps. Visual floor remains separate.
static func build(ground: Node2D, passage_envelopes: Array[PackedVector2Array]) -> StaticBody2D:
	var regions: Array[PackedVector2Array]=passage_envelopes.duplicate()
	for floor in ground.get_children():
		if floor is Polygon2D: regions.append(floor.polygon)
	var changed := true
	while changed:
		changed=false
		for first in range(regions.size()):
			for second in range(first+1,regions.size()):
				var joined=Geometry2D.merge_polygons(regions[first],regions[second])
				if joined.size()==1:
					regions[first]=joined[0]
					regions.remove_at(second)
					changed=true
					break
			if changed: break
	var body=StaticBody2D.new()
	body.name="ShorelineBanks"
	body.collision_layer=1
	body.collision_mask=0
	var segments=PackedVector2Array()
	for region in regions:
		for inset in Geometry2D.offset_polygon(region,-2.0):
			for index in range(inset.size()):
				segments.append(inset[index])
				segments.append(inset[(index+1)%inset.size()])
	var shape=ConcavePolygonShape2D.new()
	shape.segments=segments
	var collision=CollisionShape2D.new()
	collision.shape=shape
	body.add_child(collision)
	return body
