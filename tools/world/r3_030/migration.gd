extends RefCounted

var t: RefCounted
var world: Node2D
var profile: Node
const ZONE := "melting_and_freezing"

func verify(driver: RefCounted) -> void:
	t=driver
	world=t.world
	profile=t.profile
	await garden_cases()
	await mill_cases()

func load_case(id: String,level: int,state: Dictionary,complete: int,earned: Dictionary = {}) -> bool:
	world.input_adapter.close_panel()
	profile.save_path="res://../fixtures/migration-"+id+"-"+Crypto.new().generate_random_bytes(5).hex_encode()+".save"
	var completed: Dictionary={}
	for i in range(1,complete+1):completed[ZONE+":"+str(i)]=true
	var payload := {
		"version":1,"player_name":"Legacy "+id,"completed":completed,"future_root":{"retained":true},
		"active_run":{"zone":ZONE,"level":level,"attempt_id":"legacy:"+id,"state":state.duplicate(true),"achievement_history_known":false},
		"extras":{"future_field":{"retain":[1,2,3]},"explained_puzzle_types":{"melt_direct":true},
			"achievement_unlocks":{"good_question":{"timestamp":42}}},
	}
	payload.extras.merge(earned, true)
	var file:=FileAccess.open(profile.save_path,FileAccess.WRITE)
	if not t.check(file!=null,"write isolated legacy document "+id):return false
	file.store_var(payload)
	file.close()
	profile.load_profile()
	var okay: bool=world.restore_saved_world(world.access)
	await t.ticks(8)
	if not t.check(okay and world.active_subregion_id=="Z1L%d"%level and world.learning_provider()!=null,"binary world restore "+id):return false
	t.check(profile.data.future_root==payload.future_root and profile.data.extras.future_field==payload.extras.future_field,"unknown data preserved "+id)
	t.check(profile.achievement_state().unlocks.has("good_question") and profile.total_stars()==complete,"earned sets preserved "+id)
	t.check(profile.data.extras.get("independent_phase_evidence",{}) == earned.get("independent_phase_evidence",{}),
		"native evidence is preserved without additions "+id)
	return true

func idempotent(id: String) -> void:
	var before: Dictionary=profile.data.duplicate(true)
	var module: Dictionary=world.learning_provider()._state.duplicate(true)
	world.input_adapter.close_panel()
	profile.load_profile()
	var okay: bool=world.restore_saved_world(world.access)
	await t.ticks(5)
	t.check(okay and profile.data.completed==before.completed and module==world.learning_provider()._state,"migration stable across second binary restore "+id)
	t.check(profile.data.extras.get("independent_phase_evidence",{})==before.extras.get("independent_phase_evidence",{}),"second restore adds no phase proof "+id)

func garden_cases() -> void:
	var garden: Node=world.chunks["Z1L1.shell"].runtime_provider
	var base: Dictionary=garden._legacy_state({}).legacy
	base.erase("legacy_first_heat")
	base.erase("device_retrofit_version")
	base.melted=[.6,0.0,0.0]
	base.lit=[true,false,true]
	base.collected={0:true,2:true}
	base.relays=[4,3]
	base.future_state={"source":"original"}
	for owner in ["carried","docked"]:
		var old: Dictionary=base.duplicate(true)
		old.module_state=owner
		old.carry_item="module" if owner=="carried" else ""
		if not await load_case("L1-"+owner,1,{"current":old},0):continue
		if not t.check(not garden._state.is_empty(),"Garden migration accepts "+owner):continue
		var s: Dictionary=garden._state.legacy
		var target: Node=garden.targets.get(garden.FIRST_ID)
		t.check(s.legacy_first_heat==.6 and is_instance_valid(target) and is_equal_approx(target.definition().required_exposure,1.2),"only remaining first heat required "+owner)
		t.check(s.collected==old.collected and s.relays==old.relays and s.future_state==old.future_state and garden._state.legacy_original==old,"exact Garden legacy evidence retained "+owner)
		t.check(not world.player.carrying and garden.bodies[0].collision_layer!=0 and not profile.has_device_capability("melting"),"retired module frees hands without opening barrier or granting mastery "+owner)
		await idempotent(owner)
	var versioned := base.duplicate(true)
	versioned.device_retrofit_version = 1
	versioned.legacy_first_heat = 0.6
	versioned.module_state = "docked"
	versioned.lit[0] = false
	var lesson := {"thermal_introduction_version":1,"lessons_seen":{ZONE+":1:melting":true}}
	if await load_case("R2-partial-Thermal",1,{"current":versioned},0,lesson):
		var target: Node = garden.targets.get(garden.FIRST_ID)
		t.check(garden._state.legacy_original == versioned and is_instance_valid(target)
			and is_equal_approx(target.definition().required_exposure,1.2) and target.exposure() == 0.0,
			"versioned R2 heat credit survives with zero in-flight Fire")
		t.check(profile.is_device_mode_unlocked("thermal") and not profile.has_device_capability("freezing")
			and garden.bodies[0].collision_layer != 0, "R2 partial barrier remains playable and closed")
		await idempotent("R2 partial Thermal")
	versioned.melted[0] = 1.0
	var outcome := {"version":1,"id":garden.FIRST_ID,"process":"melting","material":"water",
		"from_state":"solid","to_state":"liquid","capability":"melting","puzzle_type":"melt_direct"}
	var earned := lesson.duplicate(true)
	earned.independent_phase_evidence = {ZONE+":1:"+garden.FIRST_ID:outcome}
	earned.solved_puzzle_ids = {ZONE+":1:puzzle0":"melt_direct"}
	if await load_case("R2-completed-Thermal",1,{"current":versioned,"device_outcomes":{garden.FIRST_ID:outcome}},0,earned):
		t.check(garden.bodies[0].collision_layer == 0 and garden.targets.is_empty()
			and garden.snapshot().device_outcomes == {garden.FIRST_ID:outcome}, "one preserved R2 thaw receipt and open barrier")
		t.check(profile.total_stars() == 0 and not profile.has_device_capability("freezing")
			and not world.access.allowed("Z1L2"), "R2 first thaw alone earns no district or future mode")
		await idempotent("R2 completed Thermal")
	if await load_case("L1-completed",1,{},1):
		t.check(garden.bodies.all(func(body):return body.collision_layer==0) and garden._state.legacy.collected.size()==6 and garden.targets.is_empty(),"completed Garden stays open with all six crystals")
		t.check(world.input_adapter.modal.is_empty() and not garden.finish() and profile.pending_explanations().is_empty(),"completed Garden adds no replay, award or explanation")
		await idempotent("Garden completion")

func mill_cases() -> void:
	var mill: Node=world.chunks["Z1L2.shell"].runtime_provider
	var cases := [
		{"id":"old-held-opening-module","raw":{"part":"held","clear":false},"parts":[0,0,0],"held":-1,"carry":""},
		{"id":"old-partial-thaw","raw":{"part":"docked","clear":true,"gear_thawed":true,"checkpoint":"C1"},"parts":[1,0,0],"held":-1,"carry":""},
		{"id":"partial-sort","raw":{"route_version":2,"part":"docked","clear":true,"bell_count":3,"workshop_version":1,"workshop_parts":[2,1,0],"workshop_held":1},"parts":[2,1,0],"held":1,"carry":"crank"},
		{"id":"old-brake-pin","raw":{"part":"docked","clear":true,"gear_thawed":true,"latch_thawed":true,"cache_thawed":true,"walkback_open":true,"crank":"held","checkpoint":"C2"},"parts":[2,2,2],"held":-1,"carry":"brake_pin"},
	]
	for row in cases:
		if not await load_case(row.id,2,row.raw,1):continue
		if not t.check(not mill._state.is_empty(),"Mill migration accepts "+row.id):continue
		var s: Dictionary=mill._state.legacy
		t.check(s.workshop_parts==row.parts and s.workshop_held==row.held and mill._state.legacy_original==row.raw,"exact Mill stages retained "+row.id)
		var actual: String=mill._held.get_meta("unique_item_id","") if is_instance_valid(mill._held) else ""
		t.check(actual==row.carry and world.player.carrying==(not row.carry.is_empty()),"exact one or no carried part "+row.id)
		t.check(not profile.has_device_capability("freezing") and not world.access.allowed("Z1L3"),"migration cannot unlock next district "+row.id)
		await idempotent(row.id)
	if await load_case("L2-completed",2,{},2):
		t.check(mill.PROGRESS.complete(mill._state.legacy) and mill.targets.is_empty() and world.access.allowed("Z1L3"),"completed Mill retains route and permissions")
		t.check(not profile.has_device_capability("freezing") and profile.pending_explanations().is_empty(),"completed Mill adds no freezing or replay explanation")
		await idempotent("Mill completion")
