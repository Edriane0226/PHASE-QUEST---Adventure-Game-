extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(ProjectSettings.load_resource_pack(args[0]),"mount isolated Android-preset package in empty project")
	var geometry_script=load("res://Scripts/World/Zone3/zone3_geometry.gd")
	var geometry=geometry_script.new();check(geometry.load_data(),"baked terrain JSON reloads")
	check(geometry.data.chambers.size()>10 and geometry.data.shelters.size()==38,"sealed chamber/service aisles and19 two-prop checkpoint shelters ship")
	for platform in geometry.data.platforms:check(platform.material=="permanent metal housing" and not platform.frost_support,"packaged support is permanent metal, never frost")
	for chamber in geometry.data.chambers:
		check(not chamber.frost_support and chamber.service_loop.size()==5,"packaged sealed observation/service ring "+chamber.id)
	check(geometry.data.regions.size()==6 and geometry.data.stations.size()==61,"six shells and61station records ship")
	var hash:=FileAccess.get_sha256("res://World/Data/zone3-shells.json")
	for file in ["zone3-routes.json","zone3-access.json"]:
		check(FileAccess.file_exists("res://World/Data/"+file),"derived runtime data ships "+file)
		var value=JSON.parse_string(FileAccess.get_file_as_string("res://World/Data/"+file))
		check(value.geometry_hash==hash,"derived data matches terrain hash "+file)
		if file=="zone3-access.json":check(value.equipment_access.size()==geometry.data.equipment.size(),"all normal-touch device approaches ship")
	check(load("res://World/Zone3/Zone3ShellWorld.tscn") is PackedScene,"shared actor/HUD and shell-world dependencies reload")
	for number in range(1,7):
		var scene=load("res://World/Zone3/Z3L%dShell.tscn"%number)
		check(scene is PackedScene,"shell resource reloads "+str(number))
		if not scene:continue
		var chunk=scene.instantiate();chunk.configure_geometry(geometry);chunk._ready()
		check(chunk.shell_number==number and chunk.fixture_only,"shell remains unready/fixture-only "+str(number))
		var count:=0
		for marker in chunk.anchors.values():
			if marker.has_node("SafeApproach"):count+=1
		check(count>=8,"hashed safe approaches bind to shell anchors "+str(number));chunk.free()
	var registry=load("res://Scripts/Content/world_subregions.gd")
	for row in registry.definitions():check(not registry.definition(row.id).world_ready,"no campaign readiness grant in pack "+row.id)
	for file in ["fixture_profile.gd","review.gd","path_planner.gd","manual_driver.gd","build.gd","legacy-check.gd"]:check(not FileAccess.file_exists("res://"+file) and not FileAccess.file_exists("res://"+file+".remap"),"development fixture excluded "+file)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"isolated Android-preset ZIP mounted in empty project; six shell scenes, native art/physics, terrain/route/access JSON, strict readiness and fixture exclusion; no APK or device certification"}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 018 PACKAGE ",result.status," / ",checks," checks");quit(0 if failures.is_empty() else 1)
