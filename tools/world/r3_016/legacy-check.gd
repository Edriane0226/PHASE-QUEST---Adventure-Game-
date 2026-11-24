extends SceneTree
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);print("FAIL ",message)
func run() -> void:
	var store=root.get_node("PlayerSave")
	store.save_path="user://r3-015-legacy-only.save"
	for number in [1,2]:
		if current_scene:current_scene.queue_free();current_scene=null;await process_frame
		store.data={"version":1,"player_name":"Legacy recovery","completed":{"melting_and_freezing:1":true} if number==2 else {},"active_run":{},"extras":{"melting_gardens_welcome_seen":true}}
		check(store.begin_level("melting_and_freezing",number),"real PlayerSave begins existing level "+str(number))
		var path: String=store.scene_for_level("melting_and_freezing",number)
		check(change_scene_to_file(path)==OK,"legacy scene opens "+str(number));await scene_changed
		await create_timer(.5).timeout
		var scene=current_scene
		check(scene.scene_file_path==path and store.campaign_source(scene,"melting_and_freezing",number),"unchanged legacy source remains authorized "+str(number))
		check(scene.has_node("Actors/Player") and scene.has_node("GameplayHUD"),"legacy player/HUD remain available "+str(number))
		var player=scene.get_node("Actors/Player")
		check(player.animated_sprite.scale.is_equal_approx(Vector2.ONE*.2923077),"legacy scale unchanged "+str(number))
		check(not store.campaign_source(scene,"vaporization_and_condensation",1),"foreign zone cannot use legacy source "+str(number))
		var previous: bool=scene.development_preview;scene.development_preview=true
		check(not store.campaign_source(scene,"melting_and_freezing",number),"development source still rejected "+str(number));scene.development_preview=previous
		check(store.data.active_run.get("state",{}).get("device_outcomes",{}).is_empty(),"opening does not fabricate device outcome "+str(number))
	for zone in store.ZONES:
		for number in range(1,7):
			if zone=="melting_and_freezing" and number<=2:continue
			check(store.scene_for_level(zone,number).is_empty(),"future campaign unavailable "+zone+":"+str(number))
	var probe=load("res://Scripts/Autoload/player_save.gd").new()
	var zones: Array=Array(probe.ZONES)
	for prefix in range(19):
		probe.data={"completed":{}}
		for index in range(prefix):probe.data.completed["%s:%d"%[zones[index/6],index%6+1]]=true
		for index in range(18):check(probe.is_level_unlocked(zones[index/6],index%6+1)==(index<=prefix),"actual prerequisite prefix "+str(prefix)+" / "+str(index))
	for destination in range(1,18):
		for hole in range(destination):
			probe.data={"completed":{}}
			for index in range(18):
				if index!=hole:probe.data.completed["%s:%d"%[zones[index/6],index%6+1]]=true
			check(not probe.is_level_unlocked(zones[destination/6],destination%6+1),"missing earlier prerequisite "+str(destination)+" / "+str(hole))
	for index in range(18):check(probe.scene_for_level(zones[index/6],index%6+1).is_empty()==(index>=2),"actual registration "+str(index))
	probe.free()
	if current_scene:current_scene.queue_free();current_scene=null;await process_frame
	var before: Dictionary=store.data.duplicate(true)
	check(change_scene_to_file("res://World/Zone1/Zone1ShellWorld.tscn")==OK,"unready shell resource loads with real profile service")
	await scene_changed;await process_frame
	var shells=current_scene
	check(shells.geometry==null and shells.chunks.is_empty(),"normal profile cannot mount terrain fixture")
	check(not shells.fixture_session() and not shells.set_fixture_permissions(6,true),"normal profile cannot request isolated test permissions")
	check(not shells.player_controls_allowed(),"unmounted normal-profile shell cannot move")
	check(not store.campaign_source(shells,"melting_and_freezing",1),"shell cannot impersonate a campaign source")
	check(not store.begin_level("melting_and_freezing",1),"development shell cannot create a new campaign attempt")
	check(store.data==before,"opening unready shells preserves real-service profile state")
	var path:=ProjectSettings.globalize_path("res://../evidence/legacy-results.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"assertions":checks,"scope":"live L1/L2 boot/source/scale, actual prerequisites/registration, normal-profile shell isolation; not closure of partial R2 012 regressions"},"\t"))
	print("R3 016 LEGACY ",checks.size()," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
