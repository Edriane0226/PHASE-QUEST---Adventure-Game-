extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(ProjectSettings.load_resource_pack(args[0]),"mount exported Android-preset pack in empty project")
	check(FileAccess.file_exists("res://World/Data/subregions.json"),"world index JSON shipped")
	var registry=load("res://Scripts/Content/world_subregions.gd")
	check(registry!=null,"world registry reloads from pack")
	if registry:
		check(registry.definitions().size()==18,"all eighteen identities reload from exported JSON")
		for row in registry.definitions():check(not registry.definition(row.id).world_ready,"pack does not register unfinished world "+row.id)
	check(load("res://World/PhaseWorld.tscn") is PackedScene,"world scene and shared player/HUD dependencies reload")
	for file in ["fixture_profile.gd","review.gd","fixture_provider.gd","legacy-check.gd"]:check(not FileAccess.file_exists("res://"+file) and not FileAccess.file_exists("res://"+file+".remap"),"review fixture excluded "+file)
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"Android-preset ZIP exported from isolated project with real service autoloads, mounted in empty project; no APK/signing/device execution"}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("R3 015 PACKAGE ",result.status," / ",checks," checks");quit(0 if failures.is_empty() else 1)
