extends SceneTree
var checks:=0
var failures: Array=[]
var inventory: Array=[]
var coverage: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	for n in range(1,4):
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_%d/world_v1/kit_catalog.json"%n))
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/zone%d-shells.json"%n))
		var groups: Dictionary={};var ids: Dictionary={}
		for entry in catalog.entries:
			groups[entry.group]=true;ids[entry.id]=true
			var texture=load(entry.path)
			check(texture is Texture2D,"module import "+entry.id)
			var used: Rect2i=texture.get_image().get_used_rect()
			var pivot:=Vector2(entry.pivot_px[0],entry.pivot_px[1]);var scale_value:=float(entry.world_scale)
			var bounds:=Rect2(Vector2(used.position)*scale_value-pivot*scale_value,Vector2(used.size)*scale_value)
			var fp: Array=entry.footprint_world
			var ground:=Rect2(fp[0],fp[1],fp[2],fp[3]);var uv_min:=Vector2(INF,INF);var uv_max:=Vector2(-INF,-INF)
			for at in [ground.position,ground.end,Vector2(ground.position.x,ground.end.y),Vector2(ground.end.x,ground.position.y)]:
				var uv:=Vector2(at.x/40+at.y/20,at.y/20-at.x/40);uv_min=uv_min.min(uv);uv_max=uv_max.max(uv)
			inventory.append({"id":entry.id,"owner":"R3 00%d"%(n+3),"group":entry.group,"path":entry.path,"ground_envelope_cubes":[uv_max.x-uv_min.x,uv_max.y-uv_min.y],"anchor_offset_cubes":[uv_min.x,uv_min.y],"height_envelope_layers":maxi(0,ceili((ground.position.y-bounds.position.y)/20)),"ground_rect_world":fp,"pivot_px":entry.pivot_px,"world_scale":scale_value,"visual_bounds_world":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"scope":"Conservative existing module envelope; preserve art/legacy anchors, no rescale or invented puzzle collision","sha256":FileAccess.get_sha256(entry.path)})
		for station in data.stations:
			var modules: Array=[]
			for group in station.required_groups:
				var matches: Array=[]
				for entry in catalog.entries:
					if entry.group==group:matches.append(entry.id)
				for placement in data.get("equipment",[]):
					if placement.station==station.id and placement.group==group and ids.has(placement.asset) and not matches.has(placement.asset):matches.append(placement.asset)
				check(not matches.is_empty(),"station piece coverage "+station.id+":"+group)
				modules.append({"group":group,"assets":matches})
			coverage.append({"station":station.id,"subregion":station.subregion,"modules":modules})
	var shared: Array=[]
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/shared_terrain/v1/support_profiles.json"));var by_profile: Dictionary={}
	for profile in profiles.profiles:by_profile[profile.id]=profile
	for file in ["terrain_catalog.json","cave_catalog.json"]:
		var terrain: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/shared_terrain/v1/"+file))
		for entry in terrain.entries:
			check(load(entry.path) is Texture2D,"shared terrain/cave module "+entry.id)
			var profile: Dictionary=by_profile.get(entry.profile_id,{})
			var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
			for p in profile.get("support_polygon",[]):
				var uv:=Vector2(float(p[0])/40+float(p[1])/20,float(p[1])/20-float(p[0])/40);minimum=minimum.min(uv);maximum=maximum.max(uv)
			var dimensions:=maximum-minimum if is_finite(minimum.x) else Vector2.ZERO
			shared.append({"id":entry.id,"owner":"R3 003 retained compatibility","path":entry.path,"support_envelope_cubes":[dimensions.x,dimensions.y],"height_layers":maxf(float(entry.get("side_depth_world_units",0)),float(profile.get("rise_world_units",0)))/20,"pivot_px":entry.pivot_px,"world_scale":entry.world_scale,"support_profile":profile,"scope":"Old80x40 caps occupy2x2 current cubes; no rescale, support/conditional activation remains authoritative; zero support envelope means decorative/barrier-only","sha256":FileAccess.get_sha256(entry.path)})
	shared.append({"id":"runtime-stacked-cube","owner":"R3 003 compatibility / stacked-ground correction retained","footprint_cubes":[1,1],"height_layers":1,"cap_px":[40,20],"rise_px":20,"source":"Scripts/World/stacked_ground.gd","support":"Actual generated20px layers/relief and source floor rules; render bake never grants support"})
	var modules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/modular_v1/catalog.json"))
	for entry in modules.entries:
		check(load(entry.path) is Texture2D,"new independent module "+entry.id)
		check(FileAccess.get_sha256(entry.path).to_upper()==entry.sha256,"editable source hash "+entry.id)
		check(entry.pivot_px==[64.0,96.0] and entry.world_scale==1,"exact pivot and common cube unit "+entry.id)
	FileAccess.open("res://../evidence/cube-inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"unit_px":20,"cap_px":[40,20],"rise_px":20,"shared_terrain":shared,"existing_modules":inventory,"new_modules":modules.entries,"stations":coverage},"\t"))
	FileAccess.open("res://../evidence/assets-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"shared_terrain":shared.size(),"existing_modules":inventory.size(),"new_modules":modules.entries.size(),"stations":coverage.size()},"\t"))
	print("ASSETS022 ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
