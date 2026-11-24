extends SceneTree
const PS=preload("res://Scripts/Autoload/player_save.gd")
const WS=preload("res://Scripts/Content/world_save.gd")
const ACCESS=preload("res://Scripts/World/Navigation/world_access.gd")
const LEDGER=preload("res://Scripts/World/Navigation/world_discovery.gd")
var checks:=0
var failures: Array=[]
var cases: Array=[]
var world: Node
class Store extends PS:
	var fail_commit:=false
	func _ready() -> void:pass
	func _commit_save_file(from: String,to: String) -> Error:
		return ERR_CANT_CREATE if fail_commit else super._commit_save_file(from,to)
class ItemProvider extends Node:
	var restored: Dictionary={}
	func restore_world_attempt(record: Dictionary) -> void:restored=record.duplicate(true)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func write_value(path: String,value: Variant) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(value);file.close()
func fresh() -> Dictionary:
	return {"version":1,"player_name":"Original name","completed":{},"active_run":{},"extras":{}}
func run_for(id: String,state: Dictionary) -> Dictionary:
	var row:=WS.REGISTRY.definition(id)
	return {"zone":row.zone_id,"level":int(row.level),"state":state.duplicate(true),"attempt_id":"attempt-"+id,"achievement_history_known":false,"future_attempt":{"keep":true}}
func fixture_matrix() -> void:
	var inputs: Array=[]
	inputs.append({"name":"fresh","data":fresh()})
	for module in ["ground","carried","docked"]:
		for heat in [0.0,0.42,1.0]:
			var input:=fresh()
			input.active_run=run_for("Z1L1",{"current":{"position":Vector2(-699,-272),"circular_route_version":2,"melted":[heat,0.0,0.0],"waypoints":[true,false,false],"module_state":module,"carry_item":"module" if module=="carried" else "","legacy_first_heat":heat if heat<1.0 else 0.0,"device_retrofit_version":1,"collected":[0,2,5],"crystals":[true,false,true,false,false,true]},"health":6.5,"warmth":28.0})
			inputs.append({"name":"garden-"+module+"-"+str(heat),"data":input})
	for part in ["encased","released","held","placed","legacy-complete"]:
		var input:=fresh();input.completed["melting_and_freezing:1"]=true
		input.active_run=run_for("Z1L2",{"position":Vector2(-220,380),"clear":true,"gear_thawed":part=="legacy-complete","latch_thawed":part=="legacy-complete","workshop_parts":[2,1,0],"workshop_held":1 if part=="held" else -1,"part":part,"crank":"held" if part=="held" else "installed","cache_thawed":true})
		inputs.append({"name":"mill-"+part,"data":input})
	for n in [1,2,3]:
		var input:=fresh()
		input.active_run=run_for("Z%dL6"%n,{"craft":{"unique_parts":["keel:original","sail:original"]},"finn":{"conversation":"interrupted"},"checkpoint_progress":{"version":1,"unlock_sequence":["C0","C2","C1"]}})
		for row in WS.REGISTRY.definitions().slice(0, n * PS.LEVELS_PER_ZONE):
			input.completed[row.completion_key] = true
		inputs.append({"name":"completed-zone%d-craft-finn"%n,"data":input})
	var malformed:=fresh();malformed.active_run={"zone":{},"level":[],"state":"broken"};inputs.append({"name":"malformed-run","data":malformed})
	for case in inputs:
		var input: Dictionary=case.data
		input.future_root={"keep":[1,2,3]}
		input.completed["future:unknown"]={"earned":true}
		input.extras={"inventory":{"part:stable-id":{"owner":"player","count":1}},"currency":73,"lessons_seen":{"legacy-lesson":true},"guides_unlocked":{"legacy-guide":{"topic":"melting"}},"solved_puzzle_ids":{"old:first":"melt_direct"},"independent_phase_evidence":{"old:outcome":{"item":"part:stable-id"}},"explained_puzzle_types":{"melt_direct":true},"pending_explanations":["melt_solar_relay"],"achievement_unlocks":{"legacy:badge":true},"study":{"version":99,"submitted":["original-attempt"]},"phase_device":{"version":99,"future":{"keep":true}}}
		var path: String="res://../fixtures/"+case.name+"-"+Crypto.new().generate_random_bytes(5).hex_encode()+".save"
		write_value(path,input)
		var original_hash:=FileAccess.get_sha256(path)
		var store:=Store.new();store.save_path=path;root.add_child(store);store.load_profile()
		check(not store.read_only,"load "+case.name)
		check(FileAccess.get_sha256(path)==original_hash,"migration load never writes "+case.name)
		check(store.data.active_run==input.active_run and store.data.completed==input.completed and store.data.future_root==input.future_root,"legacy IDs/run/root retained "+case.name)
		for key in input.extras:
			if key != "achievement_unlocks":
				check(store.data.extras[key] == input.extras[key], "earned "+case.name+":"+key)
		var completions: int = store.total_stars()
		var unlocks: Dictionary = store.data.extras.achievement_unlocks.duplicate(true)
		var explorer: Dictionary = unlocks.get("phase_explorer", {})
		unlocks.erase("phase_explorer")
		check(unlocks == input.extras.achievement_unlocks, "prior awards retained "+case.name)
		check(store.achievement_count("phase_explorer") == completions
			and (int(explorer.get("timestamp", 0)) > 0) == (completions == 18),
			"reconcile only earned Phase Explorer progress "+case.name)
		var migrated: Dictionary=store.data.duplicate(true)
		check(WS.migrate(migrated)==migrated,"pure migration idempotent "+case.name)
		check(store.save_profile(),"first migrated save "+case.name)
		check(FileAccess.get_sha256(path+".bak")==original_hash,"original migration backup "+case.name)
		store.load_profile();check(store.data==migrated,"second load idempotent "+case.name)
		check(store.save_profile(),"second save "+case.name)
		store.load_profile();check(store.data==migrated,"third load idempotent "+case.name)
		if not WS.region_for_run(input.active_run).is_empty():
			var id:=WS.region_for_run(input.active_run)
			check(store.world_record().attempts[id].attempt==input.active_run,"unique item snapshot retained "+case.name)
		cases.append(case.name);store.free()
func storage_checks() -> void:
	var base:="res://../fixtures/storage-"+Crypto.new().generate_random_bytes(5).hex_encode()+".save"
	var store:=Store.new();store.save_path=base;root.add_child(store)
	write_value(base,fresh());store.load_profile();check(store.save_profile(),"create good primary/backup")
	var good_hash:=FileAccess.get_sha256(base+".bak")
	write_value(base,["malformed primary"]);var corrupt_hash:=FileAccess.get_sha256(base)
	store.load_profile();check(store.recovered_backup and not store.read_only,"malformed primary recovers backup")
	check(store.save_profile() and FileAccess.get_sha256(base+".bak")==good_hash and FileAccess.get_sha256(base+".corrupt")==corrupt_hash,"repair keeps good backup and corrupt evidence")
	var before:=store.data.duplicate(true);var primary_hash:=FileAccess.get_sha256(base)
	store.fail_commit=true
	check(not store.set_player_name("Failed replacement") and store.data==before,"failed commit rolls name/data back")
	check(FileAccess.get_sha256(base)==primary_hash and FileAccess.get_sha256(base+".bak")==primary_hash,"rename failure restores prior primary and keeps backup")
	store.fail_commit=false;check(store.set_player_name("Retried replacement"),"failed transaction retries")
	var absent_backup:=base+"-missing-primary";write_value(absent_backup+".bak",fresh());store.save_path=absent_backup;store.load_profile()
	check(store.recovered_backup and store.save_profile(),"missing primary restores backup")
	for value in [["invalid"],{"version":1,"player_name":"Keep","completed":{},"extras":[]}, {"version":99,"future":{"keep":"everything"}}]:
		var path:=base+"-"+str(checks);write_value(path,value)
		write_value(path+".bak",fresh());var hash:=FileAccess.get_sha256(path)
		store.save_path=path;store.load_profile()
		if value is Dictionary and value.get("version")==99:
			check(store.read_only and store.retained_document==value and not store.save_profile() and FileAccess.get_sha256(path)==hash,"future root refuses downgrade despite valid old backup")
		else:check(store.recovered_backup,"malformed structural fixture recovers backup")
	var bad_path:=base+"-bad";write_value(bad_path,{"version":1,"player_name":"Keep","completed":[],"extras":{}});store.save_path=bad_path;store.load_profile()
	var hash:=FileAccess.get_sha256(bad_path)
	check(store.read_only and not store.save_profile() and FileAccess.get_sha256(bad_path)==hash,"unrecoverable malformed profile retained read-only")
	for raw in [{"version":99,"future":["keep"]},{"version":1,"attempts":[]},{"version":1,"location":{"version":99,"keep":true}},{"version":1,"discovery":{"version":99,"keep":true}},{"version":1,"attempts":{"Z1L1":{"checkpoint_progress":{"version":88,"future":true}}}}]:
		var input:=fresh();input.extras[WS.KEY]=raw;var next:=WS.migrate(input)
		check(next==input,"unknown/malformed world envelope retained")
		store.read_only=false;store.data=input;store.save_path=base+"-nested-"+str(checks)
		check(store.save_profile() and store.data.extras[WS.KEY]==raw and store.world_discovery_namespace().is_empty(),"unrelated profile save retains unsupported world; discovery refuses")
	var truncated:=base+"-truncated";var file:=FileAccess.open(truncated,FileAccess.WRITE);file.store_32(900);file.store_32(TYPE_DICTIONARY);file.close()
	write_value(truncated+".bak",fresh());store.save_path=truncated;store.load_profile()
	check(store.recovered_backup and store.save_profile(),"truncated binary header safely recovers backup")
	store.save_path=base+"-missing-parent/profile.save";store.read_only=false;store.data=fresh();var state_before:=store.data.duplicate(true)
	check(not store.save_profile() and store.data==state_before,"cannot open temp: in-memory profile retained for retry")
	store.save_path=base+"-backup-failure";write_value(store.save_path,fresh());DirAccess.make_dir_absolute(ProjectSettings.globalize_path(store.save_path+".bak"))
	var before_hash:=FileAccess.get_sha256(store.save_path)
	check(not store.save_profile() and FileAccess.get_sha256(store.save_path)==before_hash,"backup failure leaves primary untouched")
	store.free()
func checkpoint_checks() -> void:
	var progress:=WS.checkpoint_progress("Z1L1",{"checkpoint_progress":{"unlock_sequence":["C0","C2","C1","removed","C2"]}})
	check(progress.unlock_sequence==["C0","C2","C1"] and progress.latest_unlocked_checkpoint_id=="C1","first unlock order survives authored-order differences")
	for visit in ["C0","C2","C1","C0"]:
		progress=WS.checkpoint_progress("Z1L1",{"checkpoint_progress":{"unlock_sequence":["C0",visit]}},progress)
		check(progress.latest_unlocked_checkpoint_id=="C1","older visit never replaces respawn target "+visit)
	var input:=fresh();input.active_run=run_for("Z1L1",{"current":{"position":Vector2(-699,-272),"circular_route_version":2},"checkpoint_progress":progress})
	var migrated:=WS.migrate(input)
	check(migrated.extras[WS.KEY].location.position==WS.anchor("Z1L1","C0"),"current local ground translates exactly once")
	input.active_run.state.current.circular_route_version=1
	var older:=WS.migrate(input)
	check(older.extras[WS.KEY].location.position==WS.anchor("Z1L1","C1"),"retired scene geometry falls back to newest checkpoint")
	for row in WS.REGISTRY.definitions():
		for cp in row.checkpoint_anchors:
			check(WS.anchor(row.id,cp).is_finite() and WS.REGISTRY.ground_to_local(row.id,WS.anchor(row.id,cp)) + Vector2(row.origin[0],row.origin[1]) == WS.anchor(row.id,cp),"stable anchor mapping "+row.id+":"+cp)
func runtime_checks() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await physics_frame
	var profile=root.get_node("PlayerSave")
	check(world.geometry!=null and world.chunks.size()==18,"actual18-shell restoration host composes")
	var ids: Array=[world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]
	profile.set_completed_prefix(18)
	check(profile.save_profile(), "write the legacy completion prefix before reconciliation")
	profile.load_profile()
	var initial: Dictionary=profile.data.duplicate(true)
	for row in WS.REGISTRY.definitions():
		var at:=WS.anchor(row.id,"C0")
		check(world.activate(row.id,at),"activate eligible "+row.id)
		check(profile.enter_world_subregion(world,row.id),"persist scoped attempt "+row.id)
		var attempt: String=profile.data.active_run.attempt_id
		profile.data.active_run.state={"unique_item":{"id":row.id+":original-part","owner":"carried"},"health":6.5,"warmth":28.0,"checkpoint_progress":{"version":1,"unlock_sequence":["C0","C2","C1"]}}
		check(profile.save_world_location(world),"persist current zone/ground "+row.id)
		var saved: Dictionary=profile.data.duplicate(true);profile.load_profile()
		check(profile.data==saved and profile.active_world_zone()==row.zone_id,"reload current zone "+row.id)
		world.player.position=Vector2(-9999,-9999)
		check(world.restore_saved_world(world.access) and world.active_subregion_id==row.id and world.player.position==at,"restore allowed grounded "+row.id)
		check(world.hp==6.5 and world.warmth==28.0,"restore HP/Warmth "+row.id)
		check(profile.enter_world_subregion(world,row.id) and profile.data.active_run.attempt_id==attempt and profile.data.active_run.state.unique_item.id==row.id+":original-part","ordinary return keeps attempt and item identity "+row.id)
		check(world.recover_world_checkpoint(world.access) and world.player.position==WS.anchor(row.id,"C1"),"death uses newest first unlock "+row.id)
		check(world.hp==10.0 and world.warmth==100.0,"checkpoint recovery resets survival state "+row.id)
	check(profile.world_record().attempts.size()==18,"all18 independent attempts retained")
	var retained: Dictionary=profile.world_record().attempts.duplicate(true)
	profile.set_completed_prefix(0)
	check(world.restore_saved_world(world.access) and world.active_subregion_id=="Z1L1","locked saved destination falls back to eligible mounted C0")
	check(profile.active_world_zone()==PS.ZONES[0] and profile.data.active_run.zone==PS.ZONES[0],"recovery synchronizes durable active zone/attempt")
	check(profile.world_record().attempts==retained,"relocking never erases attempts/items")
	for id in world.permissions:
		for body in world.permissions[id]:check(body.collision_layer==(0 if id=="Z1L1" else 8),"barriers derived after reload/relock "+id)
	var record: Dictionary=profile.world_record()
	for bad in [Vector2(NAN,0),Vector2(INF,INF),Vector2(-20000,30000),WS.anchor("Z3L6","C0")]:
		record.location={"version":1,"subregion":"Z1L1","position":bad,"grounded":true}
		profile.data.extras[WS.KEY]=record
		check(world.restore_saved_world(world.access) and world.active_subregion_id=="Z1L1" and world.valid_landing(world.player.position),"invalid/foreign ground recovers safely")
	record.location={"version":1,"subregion":"Z1L1","position":WS.anchor("Z1L1","C0"),"grounded":false};profile.data.extras[WS.KEY]=record
	world.player._jump_origin=WS.anchor("Z1L1","C0");world.player.jump_elapsed=.2;world.player.position+=Vector2(30,0);world.input_adapter._fire_down=true
	check(world.restore_saved_world(world.access) and world.player.jump_elapsed<0 and not world.input_adapter._fire_down and world.player.velocity==Vector2.ZERO,"airborne/firing restore clears transient motion/input")
	profile.fail_commit=true
	var failed_state: Dictionary=profile.data.duplicate(true)
	check(not world.restore_saved_world(world.access) and world.restoration_pending and not world.player_controls_allowed() and profile.data==failed_state,"failed restore commit preserves state and suspends controls")
	profile.fail_commit=false
	check(world.restore_saved_world(world.access) and not world.restoration_pending,"failed restore commit safely retries")
	var chunk: Node=world.active_chunk();var provider:=ItemProvider.new();chunk.add_child(provider);chunk.runtime_provider=provider
	world.player.carrying=true
	check(world.restore_saved_world(world.access) and provider.restored.attempt.state.unique_item.id=="Z1L1:original-part","provider receives same carried item ID, no world duplicate")
	chunk.runtime_provider=null;provider.queue_free();world.player.carrying=false
	var unmounted: String=world._active_chunk_id;world._active_chunk_id="";world.active_subregion_id=""
	check(world.unmount_chunk(unmounted),"unload active fixture after detaching identity")
	check(not world.restore_saved_world(world.access) and not world.player_controls_allowed(),"unloaded only eligible chunk suspends safely")
	profile.set_completed_prefix(18)
	check(world.restore_saved_world(world.access) and world.active_subregion_id!="Z1L1","unloaded destination uses eligible mounted fallback")
	check([world.player.get_instance_id(),world.hud.get_instance_id(),world.player.get_node("Camera2D").get_instance_id()]==ids,"restore retains same actor/HUD/camera")
	var earned: Dictionary = profile.data.extras.duplicate(true)
	var previous_earned: Dictionary = initial.extras.duplicate(true)
	earned.erase(WS.KEY)
	previous_earned.erase(WS.KEY)
	check(profile.data.completed == initial.completed and earned == previous_earned,
		"restoration creates no learning/rewards after legacy reconciliation")
	var guard:=Store.new();guard.save_path="res://../fixtures/guard.save";root.add_child(guard)
	check(not guard.world_navigation_source(world,world.active_subregion_id) and not guard.enter_world_subregion(world,world.active_subregion_id) and not guard.save_world_location(world),"production service rejects fixture navigation/save authority")
	guard.free()
func discovery_checks() -> void:
	var store=root.get_node("PlayerSave")
	var identity: String=store.world_discovery_namespace();var path: String=world.discovery.path
	check(store.set_player_name("Renamed explorer") and store.world_discovery_namespace()==identity,"rename retains profile/discovery identity")
	store.load_profile();check(store.world_discovery_namespace()==identity,"identity durable across reload")
	var ledger:=LEDGER.new();check(ledger.bind_profile(store) and ledger.path==path,"same stable discovery namespace after rename")
	ledger.cells[Vector2i(2,3)]=true;ledger.revision+=1;check(ledger.save_ledger(),"discovery commits independently")
	var again:=LEDGER.new();check(again.bind_profile(store) and again.cells.has(Vector2i(2,3)),"discovery restores independently of completion")
	var separate:=Store.new();separate.save_path="res://../fixtures/new-profile.save";root.add_child(separate);separate.data=fresh()
	check(separate.world_discovery_namespace()!=identity,"fresh profile gets distinct discovery identity")
	var future_path:="user://world-discovery/"+separate.world_discovery_namespace()+".json"
	FileAccess.open(future_path,FileAccess.WRITE).store_string('{"version":99,"future":{"keep":true}}')
	var hash:=FileAccess.get_sha256(future_path);var future:=LEDGER.new()
	check(not future.bind_profile(separate) and future.read_only and not future.save_ledger() and FileAccess.get_sha256(future_path)==hash,"future discovery remains byte-identical through profile binding")
	separate.data=fresh();separate.data.player_name="019 import";separate.set_meta("r3_015_fixture",true)
	var legacy: String=(separate.save_path+":"+separate.data.player_name+":isolated019").sha256_text()
	var old_path:="user://world-discovery/"+legacy+".json"
	FileAccess.open(old_path,FileAccess.WRITE).store_string('{"version":1,"cell_size":96,"cells":[[7,8]],"unknown":{"keep":17}}')
	var old_hash:=FileAccess.get_sha256(old_path);var imported:=LEDGER.new()
	check(imported.bind_profile(separate) and imported.cells.has(Vector2i(7,8)) and imported.save_ledger() and FileAccess.get_sha256(old_path)==old_hash,"019 discovery imports once into stable identity; source retained")
	check(imported.document().unknown.keep==17,"019 import retains unknown discovery fields")
	separate.free()
func run() -> void:
	check(ProjectSettings.globalize_path("user://").contains("r3-prompt020") and ProjectSettings.globalize_path("res://").ends_with("/review/"),"runner isolates project and entire user storage")
	var sentinel:="user://phasequest_profile.save";write_value(sentinel,{"fixture_sentinel":"never touch"});var sentinel_hash:=FileAccess.get_sha256(sentinel)
	if "--manual" in OS.get_cmdline_user_args():
		change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene
		var driver=load("res://manual_driver.gd").new();driver.world=world;root.add_child(driver)
		print("MANUAL020: +/- fixture completions;1/2/3 eligible arrivals;F5 save;F9 load;T checkpoint-order fixture;O old C0;R newest checkpoint;C carry;J jump;K simulate commit failure;F1/F2 viewport. Disposable only.");return
	fixture_matrix();storage_checks();checkpoint_checks()
	await runtime_checks();discovery_checks()
	check(FileAccess.get_sha256(sentinel)==sentinel_hash,"normal-profile sentinel unchanged by every fixture")
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"fixtures":cases,"user_storage":ProjectSettings.globalize_path("user://"),"profile_path":root.get_node("PlayerSave").save_path}
	FileAccess.open("res://../evidence/check-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("World020 ",result.status," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
