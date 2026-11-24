extends SceneTree
const ROOM=preload("res://Scripts/World/Runtime/modular_room.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var world=current_scene;root.get_node("PlayerSave").set_completed_prefix(18);await physics_frame
	world.geometry.room_solids.clear() # Site audit excludes rooms already installed at those sites.
	var result: Array=[]
	for spec in [{"id":"snow-workshop","subregion":"Z1L5","reserve":"Z1L5.C1","near":Vector2(4240,5055),"material":"snow","replaces_node":"Z1L5_C1_Shelter"},{"id":"dewglass-workroom","subregion":"Z2L3","reserve":"Z2L3.court1","near":Vector2(12148.77,4736.88),"material":"vale","replaces_node":"Z2L3_court1_greenhouse_clear"},{"id":"lab-service-room","subregion":"Z3L1","reserve":"Z3L1.C1","near":Vector2(14473.585,3673.705),"material":"lab","replaces_node":""}]:
		var found:=false
		var size:=6 if spec.material=="vale" else 8
		if spec.material=="vale":spec.near=Vector2(10925.89,6559.48);spec.reserve="Z2L3.court3";spec.replaces_node=""
		for radius in [0,40,80,120,160,200,240,280,320,360,400,440,480]:
			if found:break
			for offset in [Vector2.ZERO,Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1),Vector2(-1,-1),Vector2(1,-1)]:
				var center: Vector2=spec.near+offset*radius
				var grid=preload("res://Scripts/World/terrain_relief.gd")
				var origin: Vector2=grid.center(grid.cell_at(center-Vector2(0,size*10)))
				var h: float=float(world.geometry.height_record(origin+Vector2(0,size*10)).get("height",-999))
				var okay:=true
				for u in range(size+1):
					if not okay:break
					for v in range(size+1):
						var p: Vector2=origin+ROOM.project(Vector2(u,v))
						if world.access.region_at(p)!=spec.subregion or not world.geometry.standable(p,true) or absf(float(world.geometry.height_record(p).get("height",-999))-h)>.1:okay=false;break
				for u in [size+0.0,size+.5,size+1.0,size+1.5,size+2.0]:
					var p: Vector2=origin+ROOM.project(Vector2(u,3.5))
					if not world.geometry.standable(p,true) or absf(float(world.geometry.height_record(p).get("height",-999))-h)>.1:okay=false
				if not okay:continue
				result.append({"id":spec.id,"subregion":spec.subregion,"reserve":spec.reserve,"origin":[origin.x,origin.y],"elevation":h,"material":spec.material,"replaces_node":spec.replaces_node,"size_cubes":[size,size],"height_layers":3,"door":{"edge":"u="+str(size),"v":[2,5]},"support":"existing actual 20px stacked ground; floor tiles do not add support"});found=true;break
		if not found:push_error("No flat supported room site "+spec.id)
	FileAccess.open("res://../evidence/room-sites.json",FileAccess.WRITE).store_string(JSON.stringify({"version":1,"rooms":result},"\t"))
	print(JSON.stringify(result));quit(0 if result.size()==3 else 1)
