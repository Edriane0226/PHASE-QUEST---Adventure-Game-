extends "res://check.gd"
## Isolated real jump loop; C2 apparatus explicitly seeded, no synthetic landing receipt.
var observations: Array=[]
func run() -> void:
	walking=true;root.size=Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await ticks()
	store=root.get_node("PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L2")
	world.activate("Z1L2",Vector2(row.entry[0],row.entry[1]));store.enter_world_subregion(world,"Z1L2")
	provider=PROVIDER.new();world.chunks["Z1L2.shell"].add_child(provider);check(provider.bind_mill(world),"jump fixture binds")
	await ticks();var next: Dictionary=provider._state.duplicate(true)
	next.legacy.merge({"clear":true,"bell_count":3,"furnace_on":true,"workshop_parts":[2,2,2],"gear_thawed":true,"latch_thawed":true},true)
	check(provider._commit(next),"explicit disposable C2 apparatus")
	world.player.landed.connect(func(origin,destination):
		var origin_inside: bool=Geometry2D.is_point_in_polygon(origin,world.models[0].polygon(provider._jump.takeoff,provider.chunk.ground_origin))
		var dest_inside: bool=Geometry2D.is_point_in_polygon(destination,world.models[0].polygon(provider._jump.landing,provider.chunk.ground_origin))
		observations.append({"origin":origin,"destination":destination,"takeoff":origin_inside,"landing":dest_inside,"valid":world.valid_landing(destination),"receipt":provider._state.legacy.get("jump_records",{}).get("z1_l2_j2",false)})
		print("JUMP025 LANDED ",observations.back()))
	for trial in range(6):
		var start: Vector2=store.WORLD_SAVE.anchor("Z1L2","C2")
		world.activate("Z1L2",start);world.player.cancel_motion()
		var s: Dictionary=provider._state.duplicate(true);s.legacy.jump_records={};provider._commit(s);await ticks()
		var from: Vector2=world.models[0].v(provider._jump.from)+provider.chunk.ground_origin
		check(await move_to(from),"walk to original J2 takeoff "+str(trial))
		var direction: Vector2=(world.models[0].v(provider._jump.toward)-world.models[0].v(provider._jump.from)).normalized()
		world.input_adapter._move(direction);await ticks(2)
		print("JUMP025 START ",trial," pos=",world.player.position," velocity=",world.player.velocity," direction=",direction," allowed=",world.input_adapter.allowed()," floor=",world.player._floor_height," targetfloor=",world.raised_surface(world.player.position+direction*world.player.jump_speed*world.player.jump_duration))
		world.input_adapter.action("jump")
		for i in range(65):
			await physics_frame
			if world.player.jump_elapsed<0:break
		world.input_adapter._move(Vector2.ZERO);await ticks()
		check(provider._state.legacy.get("jump_records",{}).get("z1_l2_j2",false),"real original J2 accepted "+str(trial))
		print("JUMP025 END ",trial," pos=",world.player.position," dead=",world.dead," falls=",world.fall_count," elapsed=",world.player.jump_elapsed)
	FileAccess.open("res://../evidence/jump-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"observations":observations},"\t"))
	print("JUMP025 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
