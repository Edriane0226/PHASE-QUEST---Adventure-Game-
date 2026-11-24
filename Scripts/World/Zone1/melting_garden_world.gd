extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Z1L1 retrofit provider. Reuses authored world pieces, bodies and legacy receipts.
## Normal readiness remains gated. Never creates another player, HUD or camera.
const FIRST_ID := "garden_first_barrier"
const RETROFIT := "garden_thermal_world"
const TYPES := ["melt_direct", "melt_fueled_airflow", "melt_solar_relay"]
const GATE_CLOSED = preload("res://assets/zones/zone_1/flat_v1/props/gate_closed.tres")
const GATE_OPEN = preload("res://assets/zones/zone_1/flat_v1/props/gate_open.tres")
var pieces: Dictionary = {}
var bodies: Array = []
var _retry := 0.0
var _machine_heat := [0.0,0.0,0.0]
var _receiver_charge := 0.0
var _warming := -1
var _warm_charge := 0.0
var _context_markers: Dictionary = {}
var _jumps: Array = []
var _recovering := false

func bind_garden(host: Node2D) -> bool:
	var owned = host.chunks.get("Z1L1.shell")
	if owned == null: return false
	for piece in host.props:
		var station: String = piece.get_meta("station_id", "")
		if station.begins_with("Z1L1.legacy_"): pieces[station.trim_prefix("Z1L1.legacy_")] = piece
	pieces.professor=host.professors[0]
	for i in range(3):
		var body = host.source_bodies.get("Z1L1:Actors/ice%d/CollisionBody" % i)
		if body == null: return false
		bodies.append(body)
	var okay := bind(host, owned, {"subregion":"Z1L1", "assemblies":[], "actions":{}, "targets":{}, "items":{}, "introductions":["z1l1_melting"], "guide_topics":["melting","fuel_air","reflection"]}, func(_candidate):return action_allowed("exit"))
	if okay:
		chunk.checkpoint_provider=self
		_bind_sanctuary()
		for id in pieces:
			var marker:=Marker2D.new();marker.position=chunk.to_local(pieces[id].global_position);chunk.add_child(marker);_context_markers[id]=marker
		for source in host.models[0].data.sources:
			if source.subregion=="Z1L1":_jumps=source.get("jumps",[])
		world.player.landed.connect(_landed)
	return okay

func _bind_sanctuary() -> void:
	var row:=REGISTRY.definition("Z1L1")
	var anchor=preload("res://Scripts/World/Runtime/grounded_visual.gd").new()
	anchor.name="SanctuaryGate"
	var authored_exit := chunk.get_node_or_null("Layout/Exit") as Marker2D
	anchor.position=authored_exit.global_position if authored_exit else Vector2(row.exit[0],row.exit[1])
	anchor.elevation=world.raised_surface(anchor.position).get("height",0)
	var sprite:=Sprite2D.new()
	sprite.name="Artwork"
	anchor.visuals.add_child(sprite)
	world.district_art_parent(chunk).add_child(anchor)
	pieces.exit=anchor
	_present_sanctuary_gate()

func _present_sanctuary_gate() -> void:
	if not pieces.has("exit"):return
	var opened: bool=store.is_level_complete("melting_and_freezing",1)
	var sprite: Sprite2D=pieces.exit.visuals.get_node("Artwork")
	sprite.texture=GATE_OPEN if opened else GATE_CLOSED
	sprite.position.y=-197.77576 if opened else -184.76196
	sprite.scale=Vector2.ONE*(1.0194625 if opened else .95238096)

func default_state() -> Dictionary:
	var run: Dictionary = store.data.active_run
	return _legacy_state(run.get("state",{}) if store.WORLD_SAVE.region_for_run(run)=="Z1L1" else {})

func _legacy_state(saved: Dictionary) -> Dictionary:
	var original: Variant=saved.get("current", saved.get("checkpoint", {}))
	if not original is Dictionary:return {"version":99,"legacy_record":original}
	var raw: Dictionary = original.duplicate(true)
	if raw.is_empty():
		raw = {"position":Vector2.ZERO, "melted":[0.0,0.0,0.0], "lit":[false,false,true], "collected":{}, "wood":false, "blades":false, "fan_installed":false, "vent":0, "mirror":3, "relays":[0,6], "receiver_lit":false, "ignition":0.0, "crystals":[0.0,0.0,0.0,0.0,0.0,0.0], "waypoints":[true,false,false], "module_state":"ground", "carry_item":""}
		# Finishing old L1 cleared active_run. On world backtracking, its actual
		# completion predicate proves all three gates and six crystals; do not
		# turn that archived completion into an unsolicited fresh replay.
		if store.is_level_complete("melting_and_freezing",1):
			raw.merge({"melted":[1.0,1.0,1.0],"lit":[false,true,true],"collected":{0:true,1:true,2:true,3:true,4:true,5:true},"wood":true,"blades":true,"fan_installed":true,"vent":1,"receiver_lit":true,"ignition":1.0,"crystals":[1.0,1.0,1.0,1.0,1.0,1.0],"waypoints":[true,true,true],"completion_only_recovery":true},true)
	# Refuse malformed/unknown contracts before normalizing any obsolete field.
	for pair in [["melted",3],["lit",3],["crystals",6],["waypoints",3]]:
		if not raw.get(pair[0]) is Array or raw[pair[0]].size()!=pair[1]:return {"version":99,"legacy":raw}
	if raw.get("device_retrofit_version",1)!=1 or raw.get("expedition_version",2) not in [1,2] or raw.get("module_state","ground") not in ["ground","carried","docked"]:return {"version":99,"legacy":raw}
	# Preserve the entire original record, including future/dormant fields.
	var first: Variant=raw.melted[0]
	if not (first is int or first is float):return {"version":99,"legacy":raw}
	var credit: Variant = raw.get("legacy_first_heat", first if first<1 else 0.0)
	var carry: String = str(raw.get("carry_item", ""))
	if not raw.has("carry_item"):
		carry = "wood" if raw.get("wood",false) and not raw.lit[1] else ("blades" if raw.get("blades",false) and not raw.get("fan_installed",false) else "")
	# Pre-carry saves could hold both supplies. Same recovery rule as the legacy
	# expedition: carry one, recover the other at its original pickup, never hide it.
	if int(raw.get("expedition_version",0))<2:
		if raw.get("wood",false) and not raw.lit[1] and carry!="wood":raw.wood=false
		if raw.get("blades",false) and not raw.get("fan_installed",false) and carry!="blades":raw.blades=false
	raw.module_state = "docked"
	raw.carry_item = "" if carry=="module" else carry
	if raw.get("lit") is Array and raw.lit.size()==3: raw.lit[0] = false
	raw.device_retrofit_version = 1
	raw.legacy_first_heat = credit
	return {"version":1, "subregion":"Z1L1", "components":{}, "items":{}, "legacy":raw, "legacy_original":original.duplicate(true)}

func _supported_state(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version")!=1 or raw.get("subregion")!="Z1L1" or not raw.get("legacy") is Dictionary: return false
	if store.data.active_run.get("state",{}).get(RETROFIT,1)!=1:return false
	var s: Dictionary = raw.legacy
	for pair in [["melted",3],["lit",3],["crystals",6],["waypoints",3],["relays",2]]:
		if not s.get(pair[0]) is Array or s[pair[0]].size()!=pair[1]: return false
	for field in ["melted","crystals"]:
		for value in s[field]:
			if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>1: return false
	for field in ["lit","waypoints"]:
		for value in s[field]:
			if not value is bool: return false
	for field in ["wood","blades","fan_installed","receiver_lit"]:
		if not s.get(field) is bool: return false
	for value in [s.get("mirror")]+s.relays:
		if not value is int or value<0 or value>7: return false
	var credit: Variant = s.get("legacy_first_heat")
	return (credit is float or credit is int) and is_finite(float(credit)) and credit>=0 and credit<1 and s.get("carry_item") in ["","wood","blades"] and s.get("collected") is Dictionary

func snapshot(next: Dictionary = {}) -> Dictionary:
	var result: Dictionary = store.data.active_run.get("state", {}).duplicate(true)
	var value: Dictionary = _state if next.is_empty() else next
	result[STATE_KEY] = value.duplicate(true)
	result[RETROFIT] = 1
	result.current = value.legacy.duplicate(true)
	result.current.position = world.player.safe_save_position()-chunk.ground_origin
	result.current.circular_route_version = 2
	result.checkpoint_progress=store.WORLD_SAVE.checkpoint_progress("Z1L1",result)
	for i in range(3):
		if value.legacy.melted[i]>=1:result.checkpoint_progress=store.unlock_checkpoint(result.checkpoint_progress,"C%d"%(i+1),["C0","C1","C2","C3"])
	var prior: Variant=result.get("checkpoint",{})
	result.checkpoint=prior.duplicate(true) if prior is Dictionary else {}
	result.checkpoint.merge(result.current,true)
	result.checkpoint.position = world.checkpoint_anchor("Z1L1", result.get("checkpoint_progress",{}).get("latest_unlocked_checkpoint_id","C0"))-chunk.ground_origin
	return result

func campaign_legacy_snapshot() -> Dictionary:
	return snapshot() if not _state.is_empty() else {}

func introduce(id: String) -> bool:
	if id!="z1l1_melting" or not _can_write(): return false
	return store.introduce_thermal_melting(world,"lesson_melting")

func introduction_authorized(target: Node, id: String) -> bool:
	return id=="z1l1_melting" and owns_target(target) and store.data.extras.get("thermal_introduction_version")==1

func intro_receipt(_target: Node) -> String: return ""

func _bind_targets() -> void:
	_machine_heat = _state.legacy.melted.duplicate()
	_receiver_charge = float(_state.legacy.get("ignition",0))
	for target in targets.values():
		if is_instance_valid(target): target.free()
	targets.clear()
	if _state.legacy.melted[0]>=1: return
	var target = TARGET.new()
	bodies[0].add_child(target)
	var at: Vector2 = pieces.ice0.global_position
	target.global_position = at-Vector2(0, pieces.ice0.elevation+25)
	target.set_meta("ground_xy", at)
	target.hit_collider = bodies[0]
	targets[FIRST_ID] = target
	var spec := {"id":FIRST_ID,"zone":"melting_and_freezing","level":1,"material":"water","process":"melting","allowed_modes":["thermal"],"required_exposure":3.0*(1.0-_state.legacy.legacy_first_heat),"max_range":100.0,"required_flags":["introduced"],"introductory_milestone":"z1l1_melting"}
	if not target.configure(spec, world, store): targets.erase(FIRST_ID);target.queue_free();return
	target.bind_live_context(func():return {"material":"water","state":"solid","amount":1.0,"phase_region":"melting","heat_flow":"in"}, func():return {"introduced":store.data.extras.get("thermal_introduction_version")==1})
	target.outcome_ready.connect(func(_outcome):commit_target(target))

func suspend() -> void:
	_warming=-1
	_warm_charge=0
	super.suspend()

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target) or target.verified_outcome(store,world).is_empty() or _state.legacy.melted[0]>=1: return false
	var next := _state.duplicate(true)
	next.legacy.melted[0] = 1.0
	var candidate := snapshot(next)
	candidate.checkpoint_progress = store.unlock_checkpoint(candidate.get("checkpoint_progress",{}),"C1",["C0","C1","C2","C3"])
	candidate.checkpoint.position=world.checkpoint_anchor("Z1L1","C1")-chunk.ground_origin
	var okay: bool = store.commit_device_outcome(target,candidate,world,[{"puzzle":"puzzle0","type":"melt_direct","topic":"melting","object":FIRST_ID}],_puzzle_events(0))
	if not okay:
		last_error=store.last_error;_retry=1.0
		world.input_adapter.feedback="Could not save thaw. Barrier stays closed; retrying. "+last_error
	else:world.input_adapter.feedback=""
	return okay

func _puzzle_events(index: int) -> Array:
	var waypoint := "melting_and_freezing:1:waypoint%d" % (index+1)
	return _events([{"id":["first_thaw","helping_breeze","follow_light"][index],"event":"puzzle%d"%index,"members":[]},{"id":"six_changes","event":"observe-melting","members":["melting"]},{"id":"field_notes","event":"lesson-melting","members":["melting"],"guide":{"topic":"melting","object":"lesson_melting"}},{"id":"trail_mapper","event":"attune","members":[waypoint]}],"puzzle%d"%index)

func present() -> void:
	if _state.is_empty(): return
	var s: Dictionary = _state.legacy
	_present_apparatus(s)
	_update_carry()
	chunk.quests=[{"text":"First thaw · select Thermal, aim, hold Fire","state":"done" if s.melted[0]>=1 else "active"},{"text":"Fuel heater and repair fan","state":"done" if s.melted[1]>=1 else "active"},{"text":"Align three mirrors","state":"done" if s.melted[2]>=1 else "active"},{"text":"Crystals %d/6"%s.collected.size(),"state":"done" if s.collected.size()==6 else "active"}]
	chunk.tutorial="Guides: free lessons and demonstrations. Thermal cannot power fan or mirror relay."
	if store.is_level_complete("melting_and_freezing",1):
		chunk.tutorial="Follow the trail to Frozen Mill."
	elif _solved(s):
		chunk.tutorial="Open the sanctuary gate."

func sync_world_permissions() -> void:
	if world.active_chunk()==chunk:
		refresh_binding()
		if active() and not _state.is_empty():return
	var saved: Dictionary = store.world_record().get("attempts",{}).get("Z1L1",{}).get("attempt",{}).get("state",{})
	var state: Variant = saved.get(STATE_KEY)
	if state==null:state=_legacy_state(saved)
	if _supported_state(state):
		_present_apparatus(state.legacy)

func _present_apparatus(s: Dictionary) -> void:
	_present_sanctuary_gate()
	for i in range(3):
		var open: bool = s.melted[i]>=1
		bodies[i].collision_layer = 0 if open else 1
		pieces["ice%d"%i].show()
		for record in world.models[0].blockers:
			if record.source_path=="Actors/ice%d/CollisionBody"%i: record.layer=0 if open else record.get("original_layer",1)
	# Only obsolete first-heater/module/dock pieces retire. Other machines stay.
	if pieces.has("brazier0"): pieces.brazier0.hide()
	for key in ["Actors/brazier0/CollisionBody","Actors/HeaterModule/Body","Actors/HeaterDock/Body"]:
		var body=world.source_bodies.get("Z1L1:"+key)
		if is_instance_valid(body): body.collision_layer=0
		for record in world.models[0].blockers:
			if record.source_path==key:record.layer=0
	for id in ["wood","blades"]:
		pieces[id].visible = not s[id]
		var path: String="Actors/"+id+"/CollisionBody"
		var body=world.source_bodies.get("Z1L1:"+path)
		if is_instance_valid(body):body.collision_layer=0 if s[id] else 1
		for record in world.models[0].blockers:
			if record.source_path==path:record.layer=0 if s[id] else record.get("original_layer",1)
	for index in range(6): pieces["crystal%d"%index].visible = not s.collected.has(index)
	for i in range(3):
		var group: String=["barrier_direct","barrier_fan","barrier_relay"][i]
		_set_art("ice%d"%i,group+"_4" if s.melted[i]>=1 else group+"_0")
	_set_art("vent","fan_turn_a" if s.fan_installed else "fan_off")
	_set_art("brazier1","heater_active" if s.lit[1] and s.fan_installed else ("heater_fueled" if s.lit[1] else "heater_empty"))
	_set_art("receiver","receiver_on" if s.receiver_lit else "receiver_off")
	for i in range(3): _set_art(["mirror","mirror2","mirror3"][i],"mirror_%d"%([s.mirror]+s.relays)[i])

func _set_art(id: String,asset: String) -> void:
	var texture=world.kits[0].get_meta("tiles",{}).get(asset)
	if texture!=null: pieces[id].visuals.get_node("Artwork").texture=texture

func _reachable(id: String) -> bool:
	if not pieces.has(id) or not _can_write() or world.player.jump_elapsed>=0 or world.player.action_elapsed>=0: return false
	var at: Vector2=pieces[id].global_position
	var reach:=66.0 if id=="exit" else 38.0
	if world.player.position.distance_to(at)>reach or not world.world_contact_allowed(world.player.position,at): return false
	var exclusions: Array[RID]=[world.player.get_rid()]
	var support: Dictionary=world.raised_surface(world.player.position)
	if is_instance_valid(support.get("body")): exclusions.append(support.body.get_rid())
	var query:=PhysicsRayQueryParameters2D.create(world.player.position,at,1|2|8,exclusions);query.hit_from_inside=true
	var hit:=world.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or str(hit.collider.get_meta("source_path","")).begins_with("Actors/"+id+"/")

func action_allowed(id: String) -> bool:
	if not _reachable(id): return false
	var s: Dictionary=_state.legacy
	if id=="professor": return not world.player.carrying
	if id in ["wood","blades"]: return not world.player.carrying and not s[id]
	if id=="brazier1": return s.carry_item=="wood" and not s.lit[1]
	if id=="vent": return s.carry_item=="blades" and not s.fan_installed
	if world.player.carrying: return false
	if id=="exit":return _solved(s) and not store.is_level_complete(world.SAVE_ZONE,world.SAVE_LEVEL)
	if id in ["mirror","mirror2","mirror3"]: return not s.receiver_lit
	if id.begins_with("crystal"): return not s.collected.has(int(id.trim_prefix("crystal"))) and _warming<0
	return false

func world_context() -> Dictionary:
	if not active(): return {}
	var chosen:="";var distance:=INF
	for id in pieces:
		if action_allowed(id) and world.player.position.distance_to(pieces[id].global_position)<distance:
			chosen=id;distance=world.player.position.distance_to(pieces[id].global_position)
	if chosen.is_empty(): return {}
	var caption: String={"professor":"Free lesson / help","wood":"Carry dry wood","blades":"Carry fan blades","brazier1":"Place fuel","vent":"Install fan blades","exit":"Open sanctuary gate"}.get(chosen,"Rotate mirror")
	if chosen.begins_with("crystal"):caption="Collect crystal" if _state.legacy.crystals[int(chosen.trim_prefix("crystal"))]>=1 else "Warm crystal frost"
	return {"key":"Z1L1:"+chosen,"caption":caption,"target":_context_markers[chosen],"enabled":true,"allowed":Callable(self,"action_allowed").bind(chosen),"invoke":Callable(self,"commit_action").bind(chosen)}

func commit_action(id: String) -> bool:
	if not action_allowed(id): return false
	if id=="professor":
		if _needs_intro(): return world.input_adapter.open_lesson("melting","z1l1_melting")
		return world.input_adapter.open_lesson("melting" if _state.legacy.melted[0]<1 else ("fuel_air" if _state.legacy.melted[1]<1 else "reflection"))
	if id=="exit":return finish()
	var next:=_state.duplicate(true);var s: Dictionary=next.legacy;var events: Array=[]
	if id in ["wood","blades"]: s[id]=true;s.carry_item=id
	elif id=="brazier1" or id=="vent":
		var part: String=s.carry_item;s.carry_item=""
		if id=="brazier1": s.lit[1]=true
		else:s.fan_installed=true;s.vent=1
		events=_events([{"id":"hands_on","event":"delivery:"+part,"members":[]}],"delivery:"+part)
	elif id in ["mirror","mirror2","mirror3"]:
		if id=="mirror":s.mirror=(s.mirror+1)%8
		else:var index:=int(id.right(1))-2;s.relays[index]=(s.relays[index]+1)%8
	elif id.begins_with("crystal"):
		var index:=int(id.trim_prefix("crystal"))
		if s.crystals[index]<1:_warming=index;_warm_charge=0;return true
		s.collected[index]=true
		events=_events([{"id":"pocket_scientist","event":id,"members":["melting_and_freezing:1:"+id]}],id)
	var okay: bool=store.update_run_with_events(snapshot(next),[],events,world)
	if not okay:last_error=store.last_error;world.input_adapter.feedback=last_error
	else:world.input_adapter.feedback=""
	return okay

func _mirror_aligned() -> bool:
	var directions: Array=[_state.legacy.mirror]+_state.legacy.relays
	var names: Array=["mirror","mirror2","mirror3","receiver"]
	for i in range(3):
		var origin: Vector2=pieces[names[i]].global_position+Vector2(0,-42)
		var end: Vector2=pieces[names[i+1]].global_position+Vector2(0,-26 if i==2 else -42)
		var angle: float=directions[i]*PI/4
		if Vector2(sin(angle),cos(angle)*.5).normalized().dot(origin.direction_to(end))<=.999:return false
	return true

func _environmental(delta: float) -> void:
	var s: Dictionary=_state.legacy
	if _warming>=0:
		if not _reachable("crystal%d"%_warming):_warming=-1;_warm_charge=0
		else:
			_warm_charge+=delta/2.5
			if _warm_charge>=1:
				var next:=_state.duplicate(true);next.legacy.crystals[_warming]=1.0
				if store.update_run_with_events(snapshot(next),[],[],world):_warming=-1;_warm_charge=0
	if not s.receiver_lit:
		_receiver_charge=clampf(_receiver_charge+delta/3.0 if s.lit[2] and _mirror_aligned() else _receiver_charge-delta/2.0,0,1)
		if _receiver_charge>=1:
			var next:=_state.duplicate(true);next.legacy.receiver_lit=true;next.legacy.ignition=1.0
			store.update_run_with_events(snapshot(next),[],[],world)
	for i in [1,2]:
		var ready: bool=s.lit[i] and (s.fan_installed if i==1 else s.receiver_lit)
		if not ready or s.melted[i]>=1:continue
		_machine_heat[i]=minf(1,_machine_heat[i]+delta/(4.0 if i==1 else 8.0))
		if _machine_heat[i]<1:continue
		var next:=_state.duplicate(true);next.legacy.melted[i]=1.0
		var candidate:=snapshot(next)
		candidate.checkpoint_progress=store.unlock_checkpoint(candidate.get("checkpoint_progress",{}),"C%d"%(i+1),["C0","C1","C2","C3"])
		candidate.checkpoint.position=world.checkpoint_anchor("Z1L1","C%d"%(i+1))-chunk.ground_origin
		store.update_run_with_events(candidate,[{"puzzle":"puzzle%d"%i,"type":TYPES[i],"topic":"fuel_air" if i==1 else "reflection","object":"vent" if i==1 else "mirror"}],_puzzle_events(i),world)

func _update_carry() -> void:
	var carry: String = _state.legacy.carry_item if not _state.is_empty() else ""
	if is_instance_valid(_held) and _held.get_meta("unique_item_id","")==carry: return
	if is_instance_valid(_held):
		world.player._grip_offsets.erase(_held.get_instance_id());_held.get_parent().remove_child(_held);_held.queue_free();_held=null
	world.player.carrying = not carry.is_empty()
	if carry.is_empty():world.player._sync_carry_socket();return
	var original: Sprite2D = pieces[carry].visuals.get_node("Artwork")
	_held=Sprite2D.new();_held.texture=original.texture;_held.scale=original.scale;_held.set_meta("unique_item_id",carry)
	world.player.get_node("CarriedModule").add_child(_held);world.player._fit_carried_objects()
	world.player._play("carry_idle");world.player._sync_carry_socket()

func world_checkpoints() -> Array:
	var result: Array=[]
	var progress: Dictionary=store.data.active_run.get("state",{}).get("checkpoint_progress",{})
	for id in REGISTRY.definition("Z1L1").checkpoint_anchors:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor("Z1L1",id),"attuned":id in progress.get("unlock_sequence",["C0"]),"allowed":Callable(self,"_travel_allowed").bind(id)})
	return result

func _travel_allowed(id: String) -> bool:
	return active() and not world.player.carrying and id in store.data.active_run.get("state",{}).get("checkpoint_progress",{}).get("unlock_sequence",["C0"])

func world_travel_checkpoint(id: String) -> bool:
	if not _travel_allowed(id): return false
	for entry in world_checkpoints():
		if entry.id==id and entry.attuned: return world.activate("Z1L1",entry.position)
	return false

func _needs_intro() -> bool:
	return _state.legacy.melted[0]<1 and store.data.extras.get("thermal_introduction_version")!=1

func acknowledge_help(topic: String) -> bool:
	var index: int = ["melting","fuel_air","reflection"].find(topic)
	if index < 0 or _state.legacy.melted[index] >= 1: return super.acknowledge_help(topic)
	return _can_write() and store.update_run_with_events(snapshot(),[],_events([{"id":"good_question","event":"help","members":[],"guide":{"topic":topic,"object":"professor"}}],"puzzle%d" % index),world)

func _process(delta: float) -> void:
	if not active() or _state.is_empty(): return
	_retry=maxf(0,_retry-delta)
	if _recovering:
		if _retry==0:_recover()
		return
	if not _can_write(): return
	if store.data.active_run.get("state",{}).get(RETROFIT)!=1:
		if not store.update_run_with_events(snapshot(),[],[],world):return
	if _needs_intro():
		world.input_adapter.offer_intro("melting","z1l1_melting")
		return
	if store.data.extras.get("thermal_introduction_version")==1:discover("melting","lesson_melting")
	if targets.has(FIRST_ID) and _retry==0 and not targets[FIRST_ID].verified_outcome(store,world).is_empty(): commit_target(targets[FIRST_ID])
	_environmental(delta)

func _solved(state: Dictionary) -> bool:
	if not state.melted.all(func(amount):return amount>=1) or not state.wood or not state.fan_installed:
		return false
	for index in range(6):
		if state.collected.get(index)!=true:return false
	return true

func finish() -> bool:
	var okay:=super.finish()
	if not okay:world.input_adapter.feedback=store.last_error
	else:chunk.tutorial="Follow the trail to Frozen Mill."
	return okay

func _landed(origin: Vector2,destination: Vector2) -> void:
	if not _can_write() or world.player.carrying:return
	var model: RefCounted=world.models[0]
	var records: Dictionary=_state.legacy.get("traversal_completed",{})
	for route in _jumps:
		if records.has(route.id) or (route.id=="z1_l1_j2" and _state.legacy.melted[2]<1):continue
		if not Geometry2D.is_point_in_polygon(origin,model.polygon(route.takeoff,chunk.ground_origin)) or not Geometry2D.is_point_in_polygon(destination,model.polygon(route.landing,chunk.ground_origin)):continue
		var next:=_state.duplicate(true)
		next.legacy.traversal_completed=records.duplicate()
		next.legacy.traversal_completed[route.id]=true
		if route.id=="z1_l1_j1":next.legacy.jump_practiced=true
		if store.update_run_with_events(snapshot(next),[],[],world) and route.id=="z1_l1_j1":
			if store.mark_jump_tutorial_seen():world.input_adapter.feedback="Nice jump!"
		break

func recover_world_fall() -> bool:
	if not active() or _state.is_empty():return false
	world.input_adapter.stop_all("garden_fall",true)
	world.dead=true
	_recovering=true
	_recover()
	return true

func _recover() -> void:
	_recovering=not world.recover_world_checkpoint(world.access)
	if _recovering:
		world.dead=true
		_retry=1.0

func _exit_tree() -> void:
	if is_instance_valid(pieces.get("exit")):pieces.exit.queue_free()
	super._exit_tree()
