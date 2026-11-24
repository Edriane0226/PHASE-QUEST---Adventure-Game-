extends SceneTree
const PROVIDER=preload("res://Scripts/World/Zone1/stillwater_world.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run() -> void:
	var store=root.get_node("PlayerSave")
	check(store.save_path=="res://../fixtures/relaunch.save","separate process loads actual tested fixture file")
	check(store.is_level_complete("melting_and_freezing",3) and store.total_stars()==3,"completion and exactly three stars survive process restart")
	check(store.has_device_capability("freezing") and store.has_device_capability("melting"),"new freezing and prior melting survive restart")
	check(store.data.extras.lessons_seen.get("melting_and_freezing:3:freezing",false),"acknowledged freezing lesson persists")
	check(store.data.extras.world_intro_receipts.milestones.z1l3_freezing.freezing=="melting_and_freezing:3:first_ice","native introductory receipt persists separately from completion")
	check(store.data.extras.independent_phase_evidence.has("melting_and_freezing:3:first_ice"),"verified native water phase evidence survives restart")
	check(store.guide_records().has("melting_and_freezing:3:cooling_tool:freezing"),"cooling-tool Guide persists")
	check(store.data.extras.explained_puzzle_types.get("freeze_controlled",false) and store.data.extras.explained_puzzle_types.get("stillwater_latch",false),"both acknowledged first-success explanations persist")
	check(not store.pending_explanations().any(func(entry):return entry.type in ["freeze_controlled","stillwater_latch"]),"acknowledged explanations never requeue on restart")
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var world=current_scene;var row: Dictionary=world.REGISTRY.definition("Z1L3")
	check(world.activate("Z1L3",Vector2(row.entry[0],row.entry[1])) and store.enter_world_subregion(world,"Z1L3"),"ordinary cold-process return opens archived attempt")
	var provider=PROVIDER.new();world.chunks["Z1L3.shell"].add_child(provider);check(provider.bind_crossing(world),"cold-process provider rebuilds independent modules")
	await physics_frame;await process_frame
	check(provider._state.crossed and provider._state.components["crossing/latch"].phase=="latched","mechanical latch and real hop persist")
	check(provider._state.components["supply/water"].amount==0 and provider._state.components["crossing/left"].amount==1 and provider._state.components["crossing/right"].amount==1,"water remains conserved across process restart")
	check(store.data.active_run.state.checkpoint_progress.unlock_sequence==["C0","C1","C2"],"checkpoint unlock order persists")
	check(world.valid_landing(provider.points.court3+Vector2(-56,0)) and world.valid_landing(provider.points.court3+Vector2(56,0)),"secured support rebuilt from saved state after restart")
	check(store.data.active_run.state.device_outcomes.size()==4,"four native outcomes remain once-only")
	check(world.REGISTRY.READY_CHUNKS.is_empty(),"relaunch never enables normal unready content")
	FileAccess.open("res://../evidence/restore-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures},"\t"));print("RESTORE026 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
