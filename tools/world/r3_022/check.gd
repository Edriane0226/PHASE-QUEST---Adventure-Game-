extends SceneTree
const ROOM=preload("res://Scripts/World/Runtime/modular_room.gd")
const SUPPORT=preload("res://Scripts/World/terrain_support_profiles.gd")
const WS=preload("res://Scripts/Content/world_save.gd")
var checks:=0
var failures: Array=[]
var world: Node
var observations: Array=[]
class Probe extends "res://Scripts/World/phase_device_target_2d.gd":
	func definition() -> Dictionary:return {"max_range":500.0}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func roofs(room: Node) -> bool:
	for piece in room.pieces:
		if str(piece.get_meta("module_id")).ends_with(".roof") and not piece.visible:return false
	return true
func walk(to: Vector2) -> bool:
	var arrived:=false
	for tick in range(240):
		var direction: Vector2=to-world.player.position
		if direction.length()<3:arrived=true;break
		world.player.set_touch_movement(direction.normalized()*minf(1,direction.length()/8));await physics_frame
	world.player.set_touch_movement(Vector2.ZERO)
	if not arrived:print("WALK_STOP at=",world.player.position," target=",to," allowed=",world.player_controls_allowed()," hud=",world.hud.supported," restore=",world.restoration_pending," floor=",world.player._floor_height," modal=",world.input_adapter.modal)
	return arrived
func settle() -> void:
	await physics_frame;await process_frame;world.room_cutaway.recompute()
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	check(ProjectSettings.globalize_path("user://").contains("r3-prompt022"),"isolated user storage")
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame;world=current_scene
	var profile=root.get_node("PlayerSave");profile.set_completed_prefix(18);await physics_frame
	check(world.chunks.size()==18 and world.room_cutaway.rooms.size()==3,"18 shells / three independently owned rooms")
	var identities: Array=[world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]
	var baseline_completed: Dictionary=profile.data.completed.duplicate(true)
	Engine.time_scale=3
	for room in world.room_cutaway.rooms.duplicate():
		var label: String=room.room_id
		var width: int=int(room.size_cubes.x);var depth: int=int(room.size_cubes.y)
		check(room.pieces.size()==2*width*depth+2*width+2*depth-2 and room.bodies.size()==2*width+2*depth-1,"separate piece/body ownership "+label)
		for piece in room.pieces:
			check(piece.get_meta("room_id")==label and piece.get_parent()==world.get_node("GroundSort"),"world ground sorting ownership "+label)
			check(piece.visuals.position.y==-piece.elevation,"art-only elevation "+label)
		for u in range(width+1):
			for v in range(depth+1):
				var p: Vector2=room.point(Vector2(u,v))
				check(world.geometry.supported_box(SUPPORT.foot_rect(p)),"actual full-foot floor "+label)
				check(absf(float(world.geometry.height_record(p).get("height",-999))-room.elevation)<.1,"grounded cube layer "+label)
		var outside: Vector2=room.point(Vector2(width+2,3.5));var inside: Vector2=room.point(Vector2(width-3,3.5))
		check(world.activate(room.subregion_id,outside),"supported doorway approach "+label);await settle()
		check(roofs(room) and not room.occupied,"complete exterior outside "+label)
		var falls: int=world.fall_count
		check(await walk(inside),"walk into open door "+label);await settle()
		check(room.occupied and not roofs(room),"occupied roof removed "+label)
		for piece in room.pieces:check(piece.visible==not piece.get_meta("cutaway",false),"rear perspective retained / only foreground cut "+label)
		check(world.fall_count==falls,"door floor has no gap "+label)
		# Outside proximity and airborne sprite motion cannot claim another floor.
		check(not room.contains_ground(inside,room.elevation+20,true),"different physical floor excluded "+label)
		check(not room.contains_ground(outside,room.elevation,false),"outside roof overlap excluded "+label)
		for u in [width+.02,width-.01,width+.01,width-.02]:
			world.player.position=room.point(Vector2(u,3.5));world.room_cutaway.recompute();check(room.occupied,"door threshold hysteresis "+label)
		check(world.activate(room.subregion_id,inside),"restore interior test position "+label);await settle()
		# Adjacent room shares biome/floor but owns its own roof state.
		var sibling=ROOM.new();world.get_node("GroundSort").add_child(sibling)
		sibling.configure({"id":label+"-adjacent-fixture","subregion":room.subregion_id,"origin":[room.origin.x-160,room.origin.y+80],"elevation":room.elevation,"material":room.biome_material,"size_cubes":[8,8]},world.get_node("GroundSort"));world.room_cutaway.add_room(sibling)
		check(room.occupied and not sibling.occupied and roofs(sibling),"adjacent-room isolation "+label)
		sibling.queue_free();await settle()
		# Hidden front solid: real body movement and logical/elevated Fire remain blocked.
		var from: Vector2=room.point(Vector2(3,depth-1.6));var beyond: Vector2=room.point(Vector2(3,depth+1.3))
		check(world.activate(room.subregion_id,from),"hidden-wall approach "+label);await settle()
		check(not await walk(beyond),"hidden solid blocks movement "+label)
		check(room.coordinates(world.player.position).y<depth,"cannot move across hidden wall "+label)
		check(not world.valid_landing(room.point(Vector2(3,depth))),"solid rejects invalid saved landing "+label)
		check(not world.world_contact_allowed(from,beyond),"hidden wall blocks target exposure "+label)
		var query:=PhysicsRayQueryParameters2D.create(from,beyond,11,[world.player.get_rid()])
		check(not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"hidden body retained in Fire mask "+label)
		for h in [0,40,120,240]:
			var beam_origin: Vector2=from-Vector2(0,h);var end: Vector2=beyond-Vector2(0,h)
			check(world.world_emission_endpoint(from,beam_origin,end).distance_to(beam_origin)<beam_origin.distance_to(end),"raised untargeted Fire clipped "+label+":"+str(h))
		var probe:=Probe.new();probe._source=world;probe.position=beyond;world.add_child(probe)
		check(probe.geometry_reason(world.player.device_muzzle())=="locked_border","shared target independently rejects hidden wall "+label);probe.queue_free()
		for body in room.bodies:check(body.collision_layer==1,"cutaway never changes collider "+label)
		if label=="snow-workshop":
			check(world.activate(room.subregion_id,from),"actual emitter wall approach")
			profile.fire_probe=true
			for mode in ["thermal","cryo","vacuum","pressure"]:
				profile.probe_mode=mode;profile.changed.emit();await settle()
				var emitter=world.input_adapter.emitter;emitter.facing=(beyond-from).normalized();emitter.release()
				check(emitter.available() and emitter.press(),"actual isolated Fire starts "+mode)
				for tick in range(10):await physics_frame
				var shot: Dictionary=emitter.snapshot()
				check(not shot.is_empty() and world.room_cutaway.ray_fraction(world.player.position,world.player.position+shot.point-shot.origin)>.99,"actual Fire ends at hidden wall "+mode)
				emitter.release()
			profile.fire_probe=false;profile.changed.emit()
		check(world.activate(room.subregion_id,outside),"cargo exterior "+label);world.player.carrying=true
		check(not world.player.request_jump(),"carried item cannot jump "+label)
		check(await walk(inside),"cargo doorway entry "+label)
		check(await walk(outside),"cargo safe exit "+label);world.player.carrying=false;await settle()
		check(roofs(room) and not room.occupied,"exit restores exterior "+label)
		check(world.activate(room.subregion_id,inside),"save interior "+label)
		check(profile.enter_world_subregion(world,room.subregion_id) and profile.save_world_location(world),"commit disposable interior location "+label)
		world.activate(room.subregion_id,outside);profile.load_profile()
		check(world.restore_saved_world(world.access),"Continue restores grounded room "+label)
		check(room.occupied and not roofs(room),"Continue recomputes cutaway synchronously "+label)
		world.dead=true;world.room_cutaway.recompute();check(not room.occupied,"death restores roof "+label)
		check(world.recover_world_checkpoint(world.access),"death restores latest checkpoint "+label);await settle()
		check(not room.occupied,"checkpoint outside restores exterior "+label)
		observations.append({"room":label,"height":room.elevation,"pieces":room.pieces.size(),"bodies":room.bodies.size(),"door_cubes":3,"physical_entry_exit_cargo":true})
	Engine.time_scale=1
	# Chunk unload owns all room pieces; remount recreates fresh occupancy, no saved visibility.
	world.activate("Z1L1",WS.anchor("Z1L1","C0"));await settle()
	var chunk=world.chunks["Z2L3.shell"];var model=chunk.geometry;var old_pieces: Array=[]
	for room in world.room_cutaway.rooms:
		if room.subregion_id=="Z2L3":old_pieces=room.pieces.duplicate()
	check(world.unmount_chunk("Z2L3.shell"),"unload inactive room chunk");await settle()
	for piece in old_pieces:check(not is_instance_valid(piece),"unload frees separately sorted artwork")
	for cycle in range(3):
		chunk=load("res://World/Zone2/Z2L3Shell.tscn").instantiate();chunk.configure_geometry(model)
		check(world.mount_chunk(chunk),"reload owning chunk "+str(cycle));await settle()
		check(world.room_cutaway.rooms.size()==3 and world.geometry.room_solids.size()==85,"reload keeps bounded ownership "+str(cycle))
		if cycle<2:check(world.unmount_chunk("Z2L3.shell"),"repeat unload "+str(cycle));await settle()
	for room in world.room_cutaway.rooms:
		if room.subregion_id=="Z2L3":
			check(world.activate(room.subregion_id,room.point(Vector2(room.size_cubes.x-3,3.5))),"enter reloaded room")
			check(room.occupied,"reload recomputes current occupancy")
	check(not world.unmount_chunk(world._active_chunk_id),"active chunk unload rejected")
	check([world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]==identities,"all checks retain original actor/HUD/camera")
	check(profile.data.completed==baseline_completed,"geometry grants no science/completion")
	check(WS.REGISTRY.READY_CHUNKS.is_empty(),"normal campaign readiness remains empty")
	for number in range(1,4):
		var access_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/zone%d-access.json"%number))
		for record in access_data.access:
			var at:=Vector2(record.safe_ground[0],record.safe_ground[1])
			check(world.geometry.standable(at,false,true) and world.valid_landing(at),"retained intended station approach "+record.id)
		for region in world.models[number-1].data.regions:
			for route in region.get("local_cargo_paths",[]):
				for p in route.get("sampled_points",route.get("points",[])):
					var at:=Vector2(p[0],p[1])
					if region.id in ["Z1L1","Z1L2"]:
						# These old authored polylines include protected scientific gaps.
						# Check additive room intrusion, never fill gaps to pass a reserve line.
						var box:=SUPPORT.cargo_clearance_rect(at);var polygon:=PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
						var clear:=true
						for record in world.geometry.room_solids:
							if not Geometry2D.intersect_polygons(polygon,record.polygon).is_empty():clear=false
						check(clear,"new rooms preserve original source cargo reserve "+route.id)
					else:check(world.geometry.standable(at,true,true),"retained local cargo clearance "+route.id)
	FileAccess.open("res://../evidence/check-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"rooms":observations,"scope":"Headless real physics, separate-piece ownership, support, cargo, logical Fire and disposable save/reload lifecycle; no Android/visual claim"},"\t"))
	print("WORLD022 ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
