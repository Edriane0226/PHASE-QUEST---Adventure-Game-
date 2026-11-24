extends RefCounted
## Pixel landmarks for the current authored explorer; never resizes the model.
static func inspect(image: Image) -> Dictionary:
	var yellow: Array[Vector2i] = []
	for y in range(75,145):
		for x in range(50,143):
			var c := image.get_pixel(x,y)
			if c.a > 0.95 and c.r > 0.50 and c.g > 0.32 and c.g > c.b*1.65 and c.r > c.g*1.05 and c.r < c.g*1.9:
				yellow.append(Vector2i(x,y))
	var neck := Vector2(96,96)
	if not yellow.is_empty():
		var first_row := 192
		for point: Vector2i in yellow: first_row = mini(first_row,point.y)
		var total := Vector2.ZERO
		var count := 0
		for point: Vector2i in yellow:
			if point.y <= first_row+12:
				total += Vector2(point)
				count += 1
		neck = (total/maxi(count,1)).round()
	return {"neck":neck,"band_top":clampi(int(neck.y)+4,93,106),"band_bottom":clampi(int(neck.y)+35,126,136)}

static func primary_hand(image: Image, neck: Vector2, direction: String) -> Dictionary:
	var points: Dictionary = {}
	for y in range(int(neck.y)+9,mini(141,int(neck.y)+38)):
		for x in range(48,145):
			var c := image.get_pixel(x,y)
			if c.a > 0.95 and c.r > 0.65 and c.g > 0.40 and c.b > 0.23 and c.r > c.g*1.08 and c.g > c.b*1.08 and c.r < c.g*1.8:
				points[Vector2i(x,y)] = true
	var components: Array[Array] = []
	while not points.is_empty():
		var queue: Array = [points.keys()[0]]
		points.erase(queue[0])
		var cursor := 0
		while cursor < queue.size():
			var point: Vector2i = queue[cursor]
			cursor += 1
			for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next := point+step
				if points.has(next):
					points.erase(next)
					queue.append(next)
		if queue.size() >= 8: components.append(queue)
	var prefer_right := direction in ["east","south_east","north","north_east"]
	var chosen: Array = []
	var best := -INF
	for component: Array in components:
		var center := Vector2.ZERO
		for point: Vector2i in component: center += Vector2(point)
		center /= component.size()
		var score := center.x if prefer_right else -center.x
		if score > best:
			best = score
			chosen = component
	assert(not chosen.is_empty(),"Missing hand landmark: "+direction)
	var extreme := -INF if prefer_right else INF
	for point: Vector2i in chosen:
		extreme = maxf(extreme,point.x) if prefer_right else minf(extreme,point.x)
	var fingertips: Array = []
	for point: Vector2i in chosen:
		if absf(point.x-extreme) <= 6: fingertips.append(point)
	chosen = fingertips
	var palm := Vector2.ZERO
	var low := Vector2i(192,192)
	var high := Vector2i.ZERO
	for point: Vector2i in chosen:
		palm += Vector2(point)
		low = low.min(point)
		high = high.max(point)
	palm = (palm/chosen.size()).round()
	# Keep the socket on a real skin pixel if the centroid lies in an outline gap.
	var nearest: Vector2i = chosen[0]
	for point: Vector2i in chosen:
		if Vector2(point).distance_squared_to(palm) < Vector2(nearest).distance_squared_to(palm): nearest = point
	return {"grip":Vector2(nearest),"hand_rect":Rect2(low-Vector2i.ONE,high-low+Vector2i(3,3))}

static func warp(point: Vector2, arm: Vector4) -> Vector2:
	if is_zero_approx(arm.z): return point
	var progress := clampf((point.x*arm.w-arm.x)/maxf(1,arm.y-arm.x),0,1)
	return point+Vector2(arm.w*arm.z*progress,0)
