extends "res://check.gd"
## Narrow failure/retry regression. C1 is explicitly seeded; native heat is real.
func run() -> void:
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;world=current_scene;await ticks()
	store=root.get_node("PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L2")
	world.activate("Z1L2",Vector2(row.entry[0],row.entry[1]));store.enter_world_subregion(world,"Z1L2")
	provider=PROVIDER.new();world.chunks["Z1L2.shell"].add_child(provider);check(provider.bind_mill(world),"fall fixture binds")
	await ticks();var next: Dictionary=provider._state.duplicate(true);next.legacy.clear=true;next.legacy.bell_count=3;next.legacy.furnace_on=true
	check(provider._commit(next),"explicit disposable C1 fixture")
	check(await aim(0),"real target approach")
	fire(true);await create_timer(.8).timeout;fire(false)
	check(target_for(0).exposure()>0 and target_for(0).exposure()<4,"native incomplete heat before fall")
	var before: Dictionary=store.data.duplicate(true);var hash: String=FileAccess.get_sha256(store.save_path)
	store.fail_commit=true;world.traversal_fall()
	check(world.dead and store.data==before and FileAccess.get_sha256(store.save_path)==hash,"failed fall write blocks recovery and preserves exact committed profile")
	store.fail_commit=false;await create_timer(1.3).timeout;await ticks()
	check(not world.dead and world.player.position.distance_to(store.WORLD_SAVE.anchor("Z1L2","C1"))<2 and target_for(0).exposure()==0 and provider._state.legacy.deaths==1 and not provider._state.legacy.death_pending,"actual fall retries to newest checkpoint and resets only unfinished heat")
	FileAccess.open("res://../evidence/fall-results.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures},"\t"))
	print("FALL025 ","PASS" if failures.is_empty() else "FAIL"," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
