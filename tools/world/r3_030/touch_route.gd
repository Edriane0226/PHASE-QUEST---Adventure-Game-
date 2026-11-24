extends RefCounted
## A route driver for disposable profiles. The world moves only through HUD touches.
const STICK := 17
const HAND := 18
const FIRE := 19
const RUN := 20
var tree: SceneTree
var world: Node2D
var hud: Control
var profile: Node
var checks := 0
var failures: Array[String] = []
var walked := 0.0
var feedback: Array[String] = []
var rendering := false

func _init(scene_tree: SceneTree, host: Node2D) -> void:
	tree=scene_tree
	world=host
	hud=host.hud
	profile=tree.root.get_node("PlayerSave")

func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		print("FAIL ",label," at ",world.player.position," modal=",world.input_adapter.modal)
	return ok

func ticks(count := 3) -> void:
	for i in range(count):
		await tree.physics_frame
		await tree.process_frame

func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout
	await ticks()

func tap(point: Vector2) -> void:
	hud.route_touch(HAND,point,true)
	hud.route_touch(HAND,point,false)

func stick(direction: Vector2) -> void:
	var rect: Rect2=hud.rects.joystick
	var at:=rect.get_center()+direction*rect.size.x*.32
	if not hud.pointers.has(STICK):hud.route_touch(STICK,rect.get_center(),true)
	hud.route_drag(STICK,at)

func stop() -> void:
	hud.route_touch(STICK,Vector2.ZERO,false)
	hud.route_touch(RUN,Vector2.ZERO,false)

func panel_button(button: Button) -> bool:
	if not is_instance_valid(button) or button.disabled:return false
	if world.panels.scroll.is_ancestor_of(button):world.panels.scroll.ensure_control_visible(button)
	await ticks(2)
	var at:=button.get_global_rect().get_center()
	for down in [true,false]:
		var touch:=InputEventScreenTouch.new()
		touch.index=0
		touch.position=at
		touch.pressed=down
		Input.parse_input_event(touch)
		await tree.process_frame
	await ticks()
	return true

func press(id: String) -> bool:
	return await panel_button(world.panels.action_buttons.get(id))

func acknowledge() -> void:
	for repeat in range(10):
		await ticks(2)
		if world.input_adapter.modal!="explanation":return
		var kind: String=world.panels.model.body
		if not feedback.has(kind):feedback.append(kind)
		var revision: int=world.panels.revision
		await press("explanation_ack")
		if world.input_adapter.modal=="explanation" and world.panels.revision==revision:
			check(false,"native touch acknowledges explanation")
			return

func mode(id: String) -> bool:
	await acknowledge()
	world.input_adapter.refresh()
	tap(hud.rects[id].get_center())
	await ticks()
	return check(profile.selected_device_mode()==id,"HUD selects "+id)

func _supported(at: Vector2) -> bool:
	# The carried sprite uses its own socket. Walking still uses the player's foot.
	if world.player.carrying and world.access.region_at(at)!=world.active_subregion_id:return false
	return world.geometry.standable(at,false,true)

func _clear(from: Vector2,to: Vector2) -> bool:
	var count:=maxi(1,ceili(from.distance_to(to)/8))
	for i in range(1,count+1):
		if not _supported(from.lerp(to,float(i)/count)):return false
	return true

func _grid_path(from: Vector2,to: Vector2,spacing: int,margin: int) -> PackedVector2Array:
	var box:=Rect2(from,Vector2.ZERO).expand(to).grow(margin)
	var grid:=AStarGrid2D.new()
	grid.cell_size=Vector2.ONE*spacing
	grid.region=Rect2i(Vector2i((box.position/spacing).floor()),Vector2i((box.size/spacing).ceil())+Vector2i.ONE)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var at:=Vector2(x,y)*spacing
			if not _supported(at):grid.set_point_solid(Vector2i(x,y),true)
	var first:=_nearest(grid,from,spacing)
	var last:=_nearest(grid,to,spacing)
	if not grid.is_in_boundsv(first) or not grid.is_in_boundsv(last):return PackedVector2Array()
	return grid.get_point_path(first,last)

func _nearest(grid: AStarGrid2D,at: Vector2,spacing: int) -> Vector2i:
	var middle:=Vector2i((at/spacing).round())
	var best:=grid.region.end
	var distance:=INF
	for y in range(middle.y-3,middle.y+4):
		for x in range(middle.x-3,middle.x+4):
			var cell:=Vector2i(x,y)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):continue
			var point:=Vector2(cell)*spacing
			var gap:=point.distance_to(at)
			if gap<distance and _clear(at,point):
				best=cell
				distance=gap
	return best

func _garden_path(from: Vector2,to: Vector2) -> PackedVector2Array:
	if world.active_subregion_id!="Z1L1" or world.access.region_at(to)!="Z1L1":return PackedVector2Array()
	var graph:=AStar2D.new()
	var nodes: Dictionary={}
	for floor_record in world.models[0].floors:
		if floor_record.region!="Z1L1" or floor_record.kind!="legacy":continue
		var at: Vector2=floor_record.bounds.get_center()
		if not nodes.has(at) and _supported(at):
			var id:=nodes.size()+2
			nodes[at]=id
			graph.add_point(id,at)
	for point: Vector2 in nodes:
		for step in [Vector2(40,20),Vector2(-40,20),Vector2(80,0),Vector2(0,40)]:
			var next: Vector2=point+step
			if nodes.has(next) and _clear(point,next):graph.connect_points(nodes[point],nodes[next])
	for end in [0,1]:
		var at:=from if end==0 else to
		graph.add_point(end,at)
		for point: Vector2 in nodes:
			if at.distance_to(point)<=88 and _clear(at,point):graph.connect_points(end,nodes[point])
	return graph.get_point_path(0,1)

func _walk_segment(at: Vector2,tolerance := 3.5) -> bool:
	var blocked:=0
	var initial: Vector2=world.player.position
	var falls: int=world.fall_count
	var ticks_allowed:=ceili(initial.distance_to(at)/maxf(25,world.player.movement_speed())*60*2)+100
	for i in range(ticks_allowed):
		var offset: Vector2=at-world.player.position
		if offset.length()<tolerance:break
		var before: Vector2=world.player.position
		stick(offset.normalized()*minf(1.0,offset.length()/14))
		if offset.length()>160 and not world.player.carrying and not hud.pointers.has(RUN):
			hud.route_touch(RUN,hud.rects.run.get_center(),true)
		elif offset.length()<=50 and hud.pointers.has(RUN):
			hud.route_touch(RUN,Vector2.ZERO,false)
		await tree.physics_frame
		if world.fall_count!=falls:break
		var move:=before.distance_to(world.player.position)
		walked+=move
		blocked=blocked+1 if move<.05 else 0
		if blocked>28:break
	stop()
	await ticks(2)
	return world.player.position.distance_to(at)<6 and world.fall_count==falls

func bridge(from: Vector2,to: Vector2) -> bool:
	if not await go(from):return false
	if not await _walk_segment(from,2.1):return false
	return _clear(world.player.position,to) and await _walk_segment(to,2.1)

func go(to: Vector2) -> bool:
	await acknowledge()
	if world.player.position.distance_to(to)<5:return true
	if not _supported(to):return false
	if _clear(world.player.position,to) and await _walk_segment(to):return true
	var resolutions: Array[Vector2i]=[Vector2i(28,200),Vector2i(14,125),Vector2i(28,500)]
	if world.active_subregion_id=="Z1L2":
		resolutions.push_front(Vector2i(8,64))
	for resolution in resolutions:
		var path:=_grid_path(world.player.position,to,resolution.x,resolution.y)
		if path.is_empty():continue
		path.append(to)
		if await _follow(path,resolution.x==8):return true
	var authored:=_garden_path(world.player.position,to)
	if not authored.is_empty() and await _follow(authored,true):return true
	print("No route ",world.player.position," → ",to," zone=",world.active_subregion_id," cargo=",world.player.carrying)
	return false

func _follow(path: PackedVector2Array,precise: bool) -> bool:
	var index:=0
	while index<path.size():
		var end:=index
		if precise:
			while end>0 and end+1<path.size() and absf((path[end]-path[end-1]).cross(path[end+1]-path[end]))<.01:end+=1
		else:
			while end+1<path.size() and _clear(world.player.position,path[end+1]):end+=1
		if not await _walk_segment(path[end],2.1 if precise else 3.5):return false
		index=end+1
	return world.player.position.distance_to(path[-1])<6

func approach(at: Vector2, predicate: Callable, radii: Array) -> bool:
	var poses: Array[Vector2]=[]
	var from: Vector2=world.player.position
	for radius in radii:
		for step in range(16):
			var point:=at+Vector2.from_angle(step*TAU/16)*float(radius)
			if _supported(point):poses.append(point)
	poses.sort_custom(func(a,b):return from.distance_squared_to(a)<from.distance_squared_to(b))
	if predicate.call():return true
	for point in poses:
		if await go(point) and predicate.call():return true
	return false

func interact(id: String,at: Vector2) -> bool:
	await acknowledge()
	var key: String=world.active_subregion_id+":"+id
	var wanted:=func():return world.active_chunk().context_record().get("key")==key
	var radii: Array=[25,32,36,48,56,63] if key=="Z1L1:exit" else [25,32,36]
	if not check(await approach(at,wanted,radii),"walk to Hand action "+key):return false
	world.input_adapter.refresh()
	tap(hud.controls.context.get_global_rect().get_center())
	await wait(.84)
	return true

func aim(id: String) -> bool:
	var provider: Node=world.learning_provider()
	var target: Node2D=provider.targets.get(id)
	if not is_instance_valid(target):return false
	var at: Vector2=target.get_meta("ground_xy")
	var emitter: Node=world.input_adapter.emitter
	var reason: String=target.targeting_reason(world,profile)
	if not reason.is_empty():
		print("Target ",target.definition().id," is ineligible: ",reason)
		return false
	var candidates: Array[Vector2]=[]
	var from: Vector2=world.player.position
	for radius in [56,67,78,87]:
		for step in range(16):
			var point:=at+Vector2.from_angle(step*TAU/16)*float(radius)
			if _supported(point):candidates.append(point)
	candidates.sort_custom(func(a,b):return from.distance_squared_to(a)<from.distance_squared_to(b))
	for point in candidates:
		if not await go(point):continue
		for i in range(2):
			target=provider.targets.get(id)
			if not is_instance_valid(target):
				stop()
				return false
			var muzzle: Node2D=world.player.device_muzzle()
			stick(muzzle.global_position.direction_to(target.global_position))
			await ticks(1)
		stop()
		await ticks(2)
		if is_instance_valid(emitter.selected) and emitter.selected==provider.targets.get(id):return true
	print("Aim trace ",id," last=",emitter.reason," facing=",emitter.facing)
	return false

func expose(id: String) -> bool:
	await acknowledge()
	if not check(await aim(id),"walk and face "+id):return false
	var target: Node=world.learning_provider().targets.get(id)
	if not check(is_instance_valid(target),"active target survives current approach "+id):return false
	var seconds: float=target.definition().required_exposure
	hud.route_touch(FIRE,hud.rects.fire.get_center(),true)
	await wait(seconds+.35)
	hud.route_touch(FIRE,Vector2.ZERO,false)
	return check(profile.data.active_run.state.get("device_outcomes",{}).has(id),"actual Fire commits "+id)

func jump(from: Vector2,direction: Vector2) -> bool:
	if not check(await go(from),"walk to jump takeoff "+str(from)):return false
	stick(direction)
	await ticks(2)
	tap(hud.rects.jump.get_center())
	var started: bool=world.player.jump_elapsed>=0
	stop()
	await wait(.85)
	return check(started,"HUD Jump started")

func boundary(from: String,to: String) -> bool:
	await acknowledge()
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
	var path: PackedVector2Array=[]
	for route in catalog.routes:
		if route.id in [from+"--"+to,to+"--"+from]:
			for pair in route.points:path.append(Vector2(pair[0],pair[1]))
			if route.id.begins_with(to):path.reverse()
			break
	if path.is_empty():return false
	if not check(await go(path[0]),"walk to trailhead "+from+" → "+to):return false
	var falls: int=world.fall_count
	for at in path:
		for frame in range(100):
			var offset: Vector2=at-world.player.position
			if offset.length()<4:break
			stick(offset.normalized()*minf(1,offset.length()/12))
			var before: Vector2=world.player.position
			await tree.physics_frame
			if world.fall_count!=falls:break
			walked+=before.distance_to(world.player.position)
		if world.fall_count!=falls or world.player.position.distance_to(at)>=5:
			stop()
			return check(false,"supported trail "+from+" → "+to+" blocked at "+str(at))
	stop()
	await ticks()
	return check(world.active_subregion_id==to and world.fall_count==falls,"geographic crossing enters "+to)

func continue_from_disk() -> bool:
	world.input_adapter.close_panel()
	if not check(profile.save_world_location(world),"save supported location"):return false
	profile.load_profile()
	var okay: bool=world.restore_saved_world(world.access)
	await ticks()
	return check(okay,"Continue from binary save")
