extends Node
## Shared provider boundary; authored subregion tasks supply contracts, not duplicated services.
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const DEVICE=preload("res://Scripts/Content/phase_device_progress.gd")
const TARGET=preload("res://Scripts/World/phase_device_target_2d.gd")
const ASSEMBLY=preload("res://Scripts/World/Learning/puzzle_assembly.gd")
const CONTENT=preload("res://Scripts/World/Learning/professor_content.gd")
const RULES=preload("res://Scripts/Content/phase_transition_rules.gd")
const STATE_KEY:="modular_puzzles"
class AttemptEvents extends RefCounted:
	var attempt_id:=""
var world: Node2D
var chunk: Node2D
var store: Node
var subregion_id:=""
var contract: Dictionary={}
var assemblies: Dictionary={}
var targets: Dictionary={}
var achievement_events:=AttemptEvents.new()
var completion_verifier: Callable
var _state: Dictionary={}
var _attempt:=""
var _pending_finish:=false
var _was_active:=false
var _held: Sprite2D
var _open_explanation:=""
var _professor_help: Marker2D
var _professor_topic: String
var last_error:=""
func bind(host: Node2D,owner_chunk: Node2D,definition: Dictionary,completion: Callable=Callable()) -> bool:
	if world!=null or owner_chunk.runtime_provider!=null or definition.get("subregion")!=owner_chunk.subregion_id or REGISTRY.definition(owner_chunk.subregion_id).is_empty():return false
	if not definition.get("assemblies") is Array or not definition.get("actions",{}) is Dictionary or not definition.get("targets",{}) is Dictionary or not definition.get("items",{}) is Dictionary:return false
	world=host;chunk=owner_chunk;store=world.get_node("/root/PlayerSave");subregion_id=chunk.subregion_id;contract=definition.duplicate(true);completion_verifier=completion
	if get_parent()!=chunk:return _reject("Provider must belong to its authored chunk.")
	for spec in contract.assemblies:
		if not spec is Dictionary or assemblies.has(spec.get("id","")):return _reject("Invalid/duplicate assembly ID.")
		var assembly=ASSEMBLY.new();assembly.name=str(spec.get("id","Assembly")).validate_node_name();add_child(assembly)
		if not assembly.configure(spec,world,chunk):return _reject(assembly.error)
		assemblies[assembly.assembly_id]=assembly
	for key in contract.actions:
		var action: Variant=contract.actions[key]
		if not action is Dictionary or not ASSEMBLY.safe_id(key) or component(action.get("component",""))==null:return _reject("Invalid action owner.")
		if not action.get("kind","") in ["set","pickup","place"]:return _reject("Unknown contextual action.")
		if action.kind=="set" and (not action.get("field") is String or not action.has("value")):return _reject("Invalid control state binding.")
		if action.kind in ["pickup","place"] and not contract.items.has(action.get("item","")):return _reject("Unknown unique item.")
	for item in contract.items:
		var spec: Variant=contract.items[item]
		if not ASSEMBLY.safe_id(item) or not spec is Dictionary or not spec.get("initial_owner") is String or not spec.get("source") is String or component(spec.source)==null:return _reject("Invalid unique item owner/source.")
		if not component(spec.source).visuals.get_node("Artwork") is Sprite2D:return _reject("Carried item requires its original sprite.")
	var row:=REGISTRY.definition(subregion_id)
	if not contract.get("introductions",[]) is Array:return _reject("Invalid introduction list.")
	for id in contract.targets:
		var binding: Variant=contract.targets[id]
		if not id is String or id.is_empty() or not binding is Dictionary or component(binding.get("component",""))==null or not binding.get("spec") is Dictionary or not binding.get("sample") is Dictionary:return _reject("Invalid target/component binding.")
		var spec: Dictionary=binding.spec.duplicate(true);spec.id=id
		if not RULES.definition_error(spec).is_empty() or spec.zone!=row.zone_id or spec.level!=row.level:return _reject("Target science/owner mismatch.")
		for flag in spec.required_flags:
			var condition: Variant=binding.get("flags",{}).get(flag)
			if not condition is Dictionary or component(condition.get("component",""))==null or not condition.get("field") is String or not condition.has("value"):return _reject("Missing authoritative apparatus flag.")
		if binding.has("checkpoint") and not row.checkpoint_anchors.has(binding.checkpoint):return _reject("Unknown checkpoint binding.")
		if binding.has("occlusion_component"):
			var key: String=binding.occlusion_component
			if not assemblies.has(key.get_slice("/",0)) or not assemblies[key.get_slice("/",0)].bodies.has(key.get_slice("/",1)):return _reject("Missing authored endpoint collider.")
		for field in binding.get("sample_bindings",{}):
			var input: Variant=binding.sample_bindings[field]
			if not input is Dictionary or component(input.get("component",""))==null or not input.get("field") is String:return _reject("Invalid sample condition source.")
	if not _supported_state(default_state()):return _reject("Invalid default component/item state.")
	chunk.runtime_provider=self;chunk.context_provider=self
	store.changed.connect(refresh_binding);store.restored.connect(_restored);world.subregion_changed.connect(_region_changed)
	refresh_binding();return true
func _reject(message: String) -> bool:
	last_error=message
	for child in get_children():
		if child is ASSEMBLY:child.dispose();child.queue_free()
	assemblies.clear();return false
func component(key: String) -> Node2D:
	var site: String=key.get_slice("/",0);var part: String=key.get_slice("/",1)
	return assemblies[site].marker(part) if key.count("/")==1 and assemblies.has(site) else null
func default_state() -> Dictionary:
	var parts: Dictionary={};var items: Dictionary={}
	for assembly in assemblies.values():parts.merge(assembly.initial_state())
	for id in contract.items:items[id]=contract.items[id].initial_owner
	return {"version":1,"subregion":subregion_id,"components":parts,"items":items}
func _supported_state(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version")!=1 or raw.get("subregion")!=subregion_id or not raw.get("components") is Dictionary or not raw.get("items") is Dictionary:return false
	var defaults:=default_state()
	for key in defaults.components:
		if not raw.components.get(key) is Dictionary:return false
		var assembly=assemblies[key.get_slice("/",0)];var spec: Dictionary=assembly.specs[key.get_slice("/",1)]
		if not spec.variants.has(str(raw.components[key].get(spec.get("visual_field","phase"),spec.get("default_variant","default")))):return false
	for id in defaults.items:
		var owner: Variant=raw.items.get(id)
		if not owner is String or not (owner=="player" or owner.begins_with("world:") or owner.begins_with("installed:")):return false
		if owner!="player" and component(owner.get_slice(":",1))==null:return false
	for id in raw.items:
		if not contract.items.has(id) and raw.items[id]=="player":return false
	return raw.items.values().count("player")<=1
func active() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(world) or not is_instance_valid(chunk) or chunk.is_queued_for_deletion():return false
	if chunk.runtime_provider!=self or not chunk.frame_valid() or world.active_chunk()!=chunk or world.active_subregion_id!=subregion_id or world.demonstration_mode:return false
	var row:=REGISTRY.definition(subregion_id)
	return store.session_active and not store.read_only and not _attempt.is_empty() and _attempt==store.data.active_run.get("attempt_id","") and store.campaign_source(world,row.zone_id,int(row.level))
func refresh_binding() -> void:
	if world==null:return
	var run: Dictionary=store.data.active_run
	var owner: bool=world.active_chunk()==chunk and REGISTRY.definition(subregion_id).completion_key=="%s:%d"%[run.get("zone",""),int(run.get("level",0))]
	if owner and not str(run.get("attempt_id","")).is_empty():
		var changed: bool=_attempt!=run.attempt_id
		_attempt=run.attempt_id;achievement_events.attempt_id=_attempt
		var saved: Variant=run.get("state",{})
		var raw: Variant=saved.get(STATE_KEY,default_state()) if saved is Dictionary else null
		if not _supported_state(raw):last_error="Unsupported modular state retained; adapter writes disabled.";_state={};suspend();return
		_state=raw.duplicate(true)
		if active():
			var resuming:=not _was_active
			_was_active=true
			if changed or resuming or targets.is_empty():_bind_targets()
			present();return
	if _was_active:suspend()
func _region_changed(_id: String) -> void:refresh_binding.call_deferred()
func _restored() -> void:
	suspend()
	for target in targets.values():
		if is_instance_valid(target):target.queue_free()
	targets.clear();_attempt="";refresh_binding()
func restore_world_attempt(_record: Dictionary) -> void:_restored()
func snapshot(next: Dictionary={}) -> Dictionary:
	var result: Dictionary=store.data.active_run.get("state",{}).duplicate(true)
	result[STATE_KEY]=(next if not next.is_empty() else _state).duplicate(true)
	return result
func _can_write() -> bool:
	if not active() or _state.is_empty() or not world.player_controls_allowed() or get_tree().paused:return false
	var learning: Variant=store.data.extras.get("learning_version",1)
	return learning==1 and DEVICE.supports_record(store.data.extras.get(DEVICE.SAVE_KEY))
func introduce(milestone_id: String) -> bool:
	if not _can_write() or not DEVICE.MILESTONES.has(milestone_id):return false
	var m: Dictionary=DEVICE.MILESTONES[milestone_id];var row:=REGISTRY.definition(subregion_id)
	if m.zone!=row.zone_id or m.level!=row.level or milestone_id not in contract.get("introductions",[]):return false
	# Existing service stages mode access from lesson; no learned-capability flag.
	return store.commit_world_lesson(row.zone_id,int(row.level),m.lesson,"lesson_"+m.lesson,world)
func owns_target(target: Node) -> bool:
	return active() and target in targets.values() and chunk.is_ancestor_of(target) and not target.is_queued_for_deletion()
func introduction_authorized(target: Node,milestone_id: String) -> bool:
	if not owns_target(target) or not contract.targets.has(target.definition().id):return false
	var spec: Dictionary=target.definition();var binding: Dictionary=contract.targets[spec.id]
	if spec.get("introductory_milestone","")!=milestone_id or binding.get("milestone","")!=milestone_id or milestone_id not in contract.get("introductions",[]):return false
	var m: Dictionary=DEVICE.MILESTONES.get(milestone_id,{})
	return not m.is_empty() and m.zone==spec.zone and m.level==spec.level and DEVICE.has_lesson(store.data,m)
func intro_receipt(target: Node) -> String:
	var id: String=target.definition().get("introductory_milestone","")
	return id if introduction_authorized(target,id) and not target.verified_outcome(store,world).is_empty() else ""
func _bind_targets() -> void:
	for target in targets.values():
		if is_instance_valid(target):target.queue_free()
	targets.clear()
	for id in contract.targets:
		var binding: Dictionary=contract.targets[id];var key: String=binding.get("component","");var anchor=component(key)
		if anchor==null:continue
		var target=TARGET.new();target.name=id.validate_node_name()
		var parent: Node2D=chunk
		var collider_key: String=binding.get("occlusion_component","")
		if not collider_key.is_empty() and assemblies.has(collider_key.get_slice("/",0)):
			parent=assemblies[collider_key.get_slice("/",0)].bodies.get(collider_key.get_slice("/",1),chunk)
		parent.add_child(target);target.global_position=anchor.position-Vector2(0,anchor.elevation)
		if parent is CollisionObject2D:target.hit_collider=parent
		target.set_meta("ground_xy",anchor.position);targets[id]=target
		var spec: Dictionary=binding.get("spec",{}).duplicate(true);spec.id=id
		if not target.configure(spec,world,store):targets.erase(id);target.queue_free();continue
		target.bind_live_context(Callable(self,"sample_for").bind(id),Callable(self,"flags_for").bind(id))
		target.outcome_ready.connect(func(_outcome):commit_target(target))
func sample_for(id: String) -> Dictionary:
	var binding: Dictionary=contract.targets[id];var result: Dictionary=binding.get("sample",{}).duplicate(true)
	var state: Dictionary=_state.components.get(binding.component,{})
	result.state=state.get("phase",result.get("state",""))
	for field in binding.get("sample_bindings",{}):
		var source: Dictionary=binding.sample_bindings[field];result[field]=_state.components.get(source.component,{}).get(source.field)
	return result
func flags_for(id: String) -> Dictionary:
	var result: Dictionary={}
	for flag in contract.targets[id].get("flags",{}):
		var condition: Dictionary=contract.targets[id].flags[flag]
		result[flag]=_state.components.get(condition.component,{}).get(condition.field)==condition.value
	return result
func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):return false
	var outcome: Dictionary=target.verified_outcome(store,world)
	if outcome.is_empty() or not contract.targets.has(outcome.id):return false
	var binding: Dictionary=contract.targets[outcome.id];var next:=_state.duplicate(true)
	if not next.components.has(binding.component):return false
	next.components[binding.component].phase=outcome.to_state
	var success: Dictionary={"puzzle":binding.get("puzzle",outcome.id),"type":outcome.puzzle_type,"topic":outcome.capability,"object":outcome.id}
	var candidate:=snapshot(next)
	if binding.has("checkpoint"):
		var ids: Array=REGISTRY.definition(subregion_id).checkpoint_anchors.keys()
		candidate.checkpoint_progress=store.unlock_checkpoint(candidate.get("checkpoint_progress",{}),binding.checkpoint,ids)
	var okay: bool=store.commit_device_outcome(target,candidate,world,[success],_events(binding.get("events",[]),outcome.id))
	if okay:refresh_binding()
	else:last_error=store.last_error
	return okay
func _events(entries: Array,identity: String) -> Array:
	var result: Array=[]
	for entry in entries:
		var event: Dictionary=entry.duplicate(true);event.event=_attempt+":"+subregion_id+":"+identity+":"+str(event.get("event","commit"));result.append(event)
	return result
func action_allowed(id: String) -> bool:
	if not _can_write() or not contract.actions.has(id) or world.player.jump_elapsed>=0 or world.player.action_elapsed>=0:return false
	var a: Dictionary=contract.actions[id];var key: String=a.component;var anchor=component(key)
	if anchor==null:return false
	var assembly=assemblies[key.get_slice("/",0)]
	if not assembly.contains_interaction(key.get_slice("/",1),world.player.position):return false
	if world.has_method("world_contact_allowed") and not world.world_contact_allowed(world.player.position,anchor.position):return false
	for condition in a.get("requires",[]):
		if _state.components.get(condition.component,{}).get(condition.field)!=condition.value:return false
	if a.kind=="pickup":return not _state.items.values().has("player") and _state.items.get(a.item)=="world:"+key
	if a.kind=="place":return _state.items.get(a.item)=="player" and not _state.items.values().has("installed:"+key)
	return not world.player.carrying and _state.components.get(key,{}).get(a.field)!=a.value
func commit_action(id: String) -> bool:
	if not action_allowed(id):return false
	world.input_adapter.stop_all("context_action",true)
	# Release/callback can change authority; recheck at actual commit boundary.
	if not action_allowed(id):return false
	var a: Dictionary=contract.actions[id];var next:=_state.duplicate(true)
	match a.kind:
		"set":next.components[a.component][a.field]=a.value
		"pickup":next.items[a.item]="player"
		"place":next.items[a.item]="installed:"+a.component
	var okay: bool=store.update_run_with_events(snapshot(next),[],_events(a.get("events",[]),id),world)
	if okay:refresh_binding()
	else:last_error=store.last_error
	return okay
func world_context() -> Dictionary:
	if not active():return {}
	var chosen:="";var best:=INF
	for id in contract.actions:
		if not action_allowed(id):continue
		var anchor=component(contract.actions[id].component);var distance: float=world.player.position.distance_to(anchor.position)
		if distance<best:chosen=id;best=distance
	if chosen.is_empty():return _professor_context()
	var key: String=contract.actions[chosen].component
	var marker=assemblies[key.get_slice("/",0)].interaction_markers[key.get_slice("/",1)]
	return {"key":subregion_id+":"+chosen,"caption":contract.actions[chosen].get("caption","Use"),"target":marker,"enabled":true,"allowed":Callable(self,"action_allowed").bind(chosen),"invoke":Callable(self,"commit_action").bind(chosen)}

func bind_professor_help(ground: Vector2, topic: String) -> void:
	_professor_topic = topic
	_professor_help = Marker2D.new()
	_professor_help.position = ground - chunk.ground_origin - Vector2(0,world.raised_surface(ground).get("height",0))
	_professor_help.set_meta("ground_xy",ground)
	add_child(_professor_help)

func _professor_reachable() -> bool:
	if not is_instance_valid(_professor_help) or not _can_write() or world.player.carrying or world.player.jump_elapsed >= 0 or world.player.action_elapsed >= 0: return false
	var ground: Vector2 = _professor_help.get_meta("ground_xy")
	return world.player.position.distance_to(ground) <= 42 and world.world_contact_allowed(world.player.position,ground)

func _professor_context() -> Dictionary:
	if not _professor_reachable(): return {}
	return {"key":subregion_id+":professor","caption":"Ask Professor Scaldwell","target":_professor_help,
		"enabled":true,"allowed":_professor_reachable,"invoke":func():
			return _professor_reachable() and world.input_adapter.open_lesson(_professor_topic)}
func present() -> void:
	if _state.is_empty():return
	var locations: Dictionary={}
	for assembly in assemblies.values():
		for id in assembly.specs:locations[assembly.assembly_id+"/"+id]=assembly.ground_point(assembly.specs[id])
	for assembly in assemblies.values():assembly.present(_state.components,_state.items,locations)
	_update_carry()
func _update_carry() -> void:
	if is_instance_valid(chunk.optional_activity) and chunk.optional_activity.holding_item():return
	var carried: String=""
	for id in contract.items:
		if _state.items[id]=="player":carried=id;break
	if is_instance_valid(_held) and _held.get_meta("unique_item_id","")==carried:return
	if is_instance_valid(_held):
		world.player._grip_offsets.erase(_held.get_instance_id());_held.get_parent().remove_child(_held);_held.queue_free();_held=null
	world.player.carrying=false
	for id in contract.items:
		if _state.items[id]!="player":continue
		var source=component(contract.items[id].source);var original: Sprite2D=source.visuals.get_node("Artwork")
		_held=Sprite2D.new();_held.name="WorldCarriedPart";_held.texture=original.texture;_held.scale=original.scale;_held.set_meta("unique_item_id",id)
		world.player.get_node("CarriedModule").add_child(_held);world.player._fit_carried_objects();world.player.carrying=true
func completion_authorized() -> bool:return _pending_finish and active() and not _state.is_empty() and completion_verifier.is_valid() and completion_verifier.call(_state.duplicate(true))==true
func finish() -> bool:
	if not _can_write() or not completion_verifier.is_valid() or completion_verifier.call(_state.duplicate(true))!=true:return false
	var previous: Dictionary=store.data.duplicate(true);var session: bool=store.session_active
	world.input_adapter.stop_all("completion",true);_pending_finish=true
	store.data.active_run.state=snapshot()
	var row:=REGISTRY.definition(subregion_id);var okay: bool=store.finish_level(row.zone_id,int(row.level),_events(contract.get("completion_events",[]),"completion"),world)
	_pending_finish=false
	if not okay:store.data=previous;store.session_active=session;last_error=store.last_error
	refresh_binding();return okay
func explanation() -> Dictionary:
	if not active():return {}
	for entry in store.pending_explanations():
		var content:=CONTENT.explanation(entry,contract.get("explanations",{}))
		if content.get("available",false):_open_explanation=entry.type;return content
	return {}
func lesson(topic: String) -> Dictionary:return CONTENT.lesson(subregion_id,topic,contract.get("lessons",{}))
func acknowledge_help(topic: String) -> bool:
	if not _can_write() or not lesson(topic).get("available",false): return false
	var row := REGISTRY.definition(subregion_id)
	return store.discover_guide(topic,row.level,"professor",row.zone_id)
func acknowledge_explanation(type_id: String) -> bool:
	if not active() or _open_explanation!=type_id:return false
	var okay: bool=store.acknowledge_explanation(type_id)
	if okay:_open_explanation=""
	return okay
func discover(topic: String,object_id: String) -> bool:
	if not _can_write() or topic not in contract.get("guide_topics",[]):return false
	var row:=REGISTRY.definition(subregion_id);return store.discover_guide(topic,int(row.level),object_id,row.zone_id)
func suspend() -> void:
	if is_instance_valid(world) and is_instance_valid(world.input_adapter):world.input_adapter.stop_all("provider_suspended",true)
	for target in targets.values():
		if is_instance_valid(target):target.remove_from_group(TARGET.TARGET_GROUP)
	if is_instance_valid(_held):
		world.player._grip_offsets.erase(_held.get_instance_id());_held.get_parent().remove_child(_held);_held.queue_free();_held=null
	if _was_active and is_instance_valid(world):world.player.carrying=false
	_was_active=false;_open_explanation=""
func _exit_tree() -> void:
	suspend()
	for target in targets.values():
		if is_instance_valid(target):target.queue_free()
