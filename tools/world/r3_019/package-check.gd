extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(ProjectSettings.load_resource_pack(args[0]),"mount Android-preset world package in empty project")
	check(load("res://World/Navigation/ConnectedWorld.tscn") is PackedScene,"connected-world actor/HUD/input/fog dependencies reload")
	var connections=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/world-connections.json"))
	check(connections.connections.size()==17,"17 canonical connections ship")
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/navigation-routes.json"))
	check(routes.routes.size()==15,"15 minimum-unlock measured walking connections ship")
	for n in range(1,4):
		var model=load("res://Scripts/World/Zone%d/zone%d_geometry.gd"%[n,n]).new();check(model.load_data(),"owned terrain model reloads "+str(n))
		check(routes.source_hashes["zone%d-shells.json"%n]==FileAccess.get_sha256("res://World/Data/zone%d-shells.json"%n),"walking routes match packaged terrain "+str(n))
		for level in range(1,7):check(load("res://World/Zone%d/Z%dL%dShell.tscn"%[n,n,level]) is PackedScene,"authored shell resource "+str(n)+":"+str(level))
	var store=load("res://Scripts/Autoload/player_save.gd").new();store.data.completed={}
	var registry=load("res://Scripts/Content/world_subregions.gd");var policy=load("res://Scripts/World/Navigation/world_access.gd").new();policy.bind(store,false)
	for row in registry.definitions():check(not policy.allowed(row.id) and not registry.definition(row.id).world_ready,"normal world readiness stays closed "+row.id)
	# Real prerequisite predicate with every missing-earlier-level combination.
	policy.bind(store,true)
	for destination in range(1,18):
		for hole in range(destination):
			store.data.completed={}
			for i in range(18):
				if i!=hole:store.data.completed["%s:%d"%[store.ZONES[i/6],i%6+1]]=true
			policy.refresh();check(not policy.allowed("Z%dL%d"%[destination/6+1,destination%6+1]),"missing prerequisite rejects destination "+str(destination)+":"+str(hole))
	store.free()
	check(load("res://assets/shaders/world/navigation_fog.gdshader") is Shader,"atmospheric shader ships")
	check(load("res://Scripts/World/Navigation/world_discovery.gd") is Script,"separate bounded discovery provider ships")
	for file in ["fixture_profile.gd","review.gd","manual_driver.gd","path_planner.gd","legacy-check.gd","package-check.gd","render-review.gd"]:check(not FileAccess.file_exists("res://"+file) and not FileAccess.file_exists("res://"+file+".remap"),"developer fixture excluded "+file)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Android-preset ZIP resource probe,18 shell/shared dependencies,17 connections,15 hashed routes,strict real prerequisites/readiness,shader/discovery and fixture exclusion; no APK/device certification"}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 019 PACKAGE ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
