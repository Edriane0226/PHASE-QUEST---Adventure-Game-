extends SceneTree
const PROGRESS=preload("res://Scripts/World/Zone1/frozen_mill_progress.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var old: Dictionary={"route_version":2,"part":"docked","clear":true,"bell_count":3,"workshop_parts":[2,2,2],"workshop_version":1,"gear_thawed":true,"latch_thawed":true,"cache_thawed":true,"crank":"held","walkback_open":true,"jump_records":{"old_marker":true},"unknown_nested":{"keep":[1,2,3]}}
	var before:=old.duplicate(true)
	var migrated: Dictionary=PROGRESS.migrate(old,false)
	check(old==before,"migration read cannot mutate source profile before successful save")
	check(migrated.legacy_original==before,"exact original snapshot predates migration normalization")
	check(PROGRESS.supported(migrated) and migrated.legacy.jump_records.get("z1_l2_j2",false) and migrated.legacy.jump_records.old_marker,"earned opened return maps legacy landing without losing old marker")
	migrated.legacy.workshop_parts[0]=0;migrated.legacy.unknown_nested.keep.append(4)
	check(old==before and migrated.legacy_original==before,"migrated mutable collections never alias source or retained original")
	for raw in [{"route_version":99,"custom":{"retain":true}},{"workshop_version":99},{"jump_records":"future"}]:
		var retained: Dictionary=raw.duplicate(true);var result:=PROGRESS.migrate(raw,false)
		check(not PROGRESS.supported(result) and raw==retained,"unsupported legacy record preserved without mutation")
	FileAccess.open("res://../evidence/migration-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures},"\t"))
	print("MIGRATION025 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
