extends "res://Scripts/World/Learning/subregion_adapter.gd"
## Live condensation and freezing use separate samples, targets and receipt IDs.
const PARTS = preload("res://Scripts/World/Zone2/dewglass_assembly.gd")
const REGION := PARTS.REGION
const ROOM := "dewglass-workroom"
const CHECKPOINTS := ["C0","C1","C2"]
const COLLECTION_SECONDS := 2.0
const SOURCE_QUESTION := {"choices":["Water leaked through the glass","Water vapor in nearby air","Ice formed on the glass"],"correct":1,
	"feedback":"Water vapor from humid air lost heat and became liquid on the air side of sealed glass. The pane stayed above freezing."}
const REPLACED := ["greenhouse_clear","humidity_source_off","cooled_pane_warm","gutter_straight",
	"collector_tank_empty","cooling_pack_empty","cooling_jacket_empty"]
var points := {}
var _reserved_art: Array[Node2D] = []
var _retired_bodies: Array[Dictionary] = []
var _labels := {}
var _help: Marker2D
var _elapsed := 0.0
var _presented_frame := ""

func bind_dewglass(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	var owner := get_parent()
	var room: Node2D = owner.get_node_or_null(ROOM)
	if room == null:
		return _reject("Dewglass requires its modular workroom.")
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	var reserves := {}
	for placement in model.data.equipment:
		if placement.subregion == REGION:
			reserves[placement.asset] = model.v(placement.at)
	# Put the feed, gutter and tank at the glass. Their original shell placeholders
	# were staged in different courts and could not form a continuous working path.
	var pane: Vector2 = points.court1 + Vector2(-90,-30)
	points.merge({"pane":pane,"cup":pane+Vector2(3,25),"source":pane+Vector2(91,8),"gutter":pane+Vector2(-50,31),
		"elbow":pane+Vector2(-87,48),"tank":pane+Vector2(-124,66),"jacket":pane+Vector2(46,53),
		"pack":room.point(Vector2(2.6,2.8))})
	if not bind(host,owner,PARTS.definition(points),_completion_ready):
		return false
	for prop in world.props:
		if str(prop.get_meta("station_id","")).begins_with(REGION+".") and prop.get_meta("asset_id","") in REPLACED:
			_reserved_art.append(prop)
			prop.hide()
	for record in model.blockers:
		if not str(record.get("station","")).begins_with(REGION+".") or not is_instance_valid(record.get("body")):
			continue
		for asset in REPLACED:
			if reserves.has(asset) and record.bounds.get_center().distance_to(reserves[asset]) < 1:
				_retired_bodies.append(record)
				record.layer = 0
				record.body.collision_layer = 0
				break
	_help = Marker2D.new()
	_help.position = points.professor - chunk.ground_origin - Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_help)
	for id in ["source","pane","tank","pack","jacket"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-77,6)
		if id == "source": label.position.y = -40
		if id == "pane": label.position += Vector2(-10,16)
		label.size.x = 154
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_outline_color",Color("23383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw):
		return false
	var owner: String = raw.items[PARTS.CARTRIDGE]
	var droplets := phase(raw,"pane") == "liquid"
	var tank := phase(raw,"tank")
	var regulated := phase(raw,"jacket") == "regulated"
	return (owner in [PARTS.SOURCE,"player",PARTS.INSTALLED]
		and (not droplets or phase(raw,"source") == "humid")
		and raw.components["pane/control"].get("proof",{}) == (PARTS.proof(1) if droplets else {})
		and (phase(raw,"gutter") == "missing" or droplets)
		and (phase(raw,"elbow") == "loose" or phase(raw,"gutter") == "joined")
		and (tank == "unseated" or phase(raw,"elbow") == "fitted")
		and (phase(raw,"pack") == "empty" or tank != "unseated")
		and (owner == PARTS.SOURCE or phase(raw,"pack") == "solid")
		and regulated == (owner == PARTS.INSTALLED)
		and (tank != "full" or regulated)
		and raw.components["tank/control"].get("proof",{}) == (PARTS.proof(PARTS.IRRIGATION_MEASURES) if tank == "full" else {})
		and (phase(raw,"exit") == "locked" or tank == "full"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].components["exit/control"].phase = "released"
	var earned := ["C0"]
	if phase(state,"pane") == "liquid": earned.append("C1")
	if phase(state,"tank") != "unseated": earned.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,earned)
	result.checkpoint = earned.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _near(id: String) -> bool:
	var from: Vector2 = world.player.position
	var at: Vector2 = points[id]
	if from.distance_to(at) > 45 or not world.world_contact_allowed(from,at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if assemblies.has(id) and assemblies[id].bodies.has("control"):
		exclude.append(assemblies[id].bodies.control.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(from,at,1|8,exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _lesson_seen() -> bool:
	return DEVICE.has_lesson(store.data,DEVICE.MILESTONES[PARTS.MILESTONE])

func action_allowed(id: String) -> bool:
	if id == "professor":
		return _can_write() and not world.player.carrying and world.player.jump_elapsed < 0 and world.player.action_elapsed < 0 and _near(id)
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"source": return _lesson_seen()
		"fill", "lift": return world.room_cutaway.occupied_id == ROOM and (id == "lift" or phase(_state,"pack") == "empty")
		"collect": return _elapsed >= COLLECTION_SECONDS and _receipt_matches(PARTS.PANE,"condensation","gas","liquid")
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_help) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Reed","enabled":true,"target":_help,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func _receipt_matches(id: String, process: String, before: String, after: String) -> bool:
	var outcomes: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	if not outcomes is Dictionary:
		return false
	var receipt: Variant = outcomes.get(id)
	return (receipt is Dictionary and receipt.get("version") == 1 and receipt.get("id") == id and receipt.get("process") == process
		and receipt.get("material") == "water" and receipt.get("from_state") == before and receipt.get("to_state") == after)

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("condensation",PARTS.MILESTONE)
		"observe": return _show_source_question()
		"exit": return finish()
		"fit", "collect":
			world.input_adapter.stop_all("context_action",true)
			if not action_allowed(id):
				return false
			var next := _state.duplicate(true)
			var events: Array = contract.actions[id].get("events",[])
			if id == "fit":
				if not _receipt_matches(PARTS.PACK,"freezing","liquid","solid"):
					return false
				next.items[PARTS.CARTRIDGE] = PARTS.INSTALLED
				next.components["jacket/control"].phase = "regulated"
			else:
				next.components["tank/control"].phase = "full"
				next.components["tank/control"].proof = PARTS.proof(PARTS.IRRIGATION_MEASURES)
				events = [{"id":"dew_detective","members":[]}]
			if _supported_state(next) and store.update_run_with_events(snapshot(next),[],_events(events,id),world):
				return true
			world.input_adapter.feedback = "Could not save the setup. Try again."
			return false
	return super.commit_action(id)

func _show_source_question(feedback := "") -> bool:
	var actions := []
	for index in SOURCE_QUESTION.choices.size():
		actions.append({"id":str(index),"label":SOURCE_QUESTION.choices[index]})
	actions.append({"id":"close","label":"Return to greenhouse"})
	return world.input_adapter.open_provider_panel(self,_answer_source.bind(_attempt),"guides.library",
		{"title":"Where did these droplets come from?","body":feedback,"speaker":"professor_z2","rows":[],"search":false,"actions":actions})

func _answer_source(id: String, _payload: Variant, attempt: String) -> void:
	if attempt != _attempt or not id.is_valid_int():
		return
	var answer := CONTENT.answer(REGION,SOURCE_QUESTION,int(id))
	if not answer.is_empty():
		_show_source_question(answer.feedback)

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	if id == PARTS.PANE:
		sample.amount = 1 if phase(_state,"source") == "humid" else 0
		sample.pane_c = PARTS.PANE_C
		sample.dew_point_c = PARTS.DEW_POINT_C
		if sample.pane_c <= 0 or sample.pane_c >= sample.dew_point_c:
			sample.phase_region = "unsuitable_pane"
	else:
		sample.amount = 1 if phase(_state,"pack") == "liquid" else 0
	return sample

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var binding: Dictionary = contract.targets[outcome.id]
	var next := _state.duplicate(true)
	next.components[binding.component].phase = outcome.to_state
	if outcome.id == PARTS.PANE:
		next.components[binding.component].proof = PARTS.proof(1)
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(binding.events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	world.input_adapter.feedback = "Observation could not be saved. Hold Cryo again."
	return false

func _completion_ready(state: Dictionary) -> bool:
	return (phase(state,"tank") == "full" and state.components["tank/control"].get("proof") == PARTS.proof(PARTS.IRRIGATION_MEASURES)
		and _receipt_matches(PARTS.PANE,"condensation","gas","liquid") and _receipt_matches(PARTS.PACK,"freezing","liquid","solid"))

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit")

func _art(id: String, asset: String) -> void:
	var sprite: Sprite2D = component(id+"/control").visuals.get_node("Artwork")
	var art := PARTS.KIT.art(asset)
	sprite.texture = load(art.path)
	sprite.scale = Vector2.ONE*float(art.scale)
	sprite.position = -Vector2(art.pivot_px[0],art.pivot_px[1])*sprite.scale

func _apparatus(state: Dictionary) -> void:
	if _labels.is_empty():
		return
	var owner: String = state.items[PARTS.CARTRIDGE]
	var wet := phase(state,"pane") == "liquid"
	var humid := phase(state,"source") == "humid"
	var regulated := owner == PARTS.INSTALLED
	var full := phase(state,"tank") == "full"
	component("pack/control").visible = owner == PARTS.SOURCE
	assemblies.pack.bodies.control.collision_layer = 1 if owner == PARTS.SOURCE else 0
	_labels.source.text = "HUMID AIR MODEL" if humid else "HUMID FEED OFF"
	_labels.pane.text = "+6°C · LIQUID" if wet else "WARM PANE · DRY"
	_labels.tank.text = "3 MEASURES · LIQUID" if full else ("TANK SEATED" if phase(state,"tank") == "seated" else "TANK UNSEATED")
	_labels.pack.visible = owner == PARTS.SOURCE
	_labels.pack.text = {"empty":"EMPTY CARTRIDGE","liquid":"CARTRIDGE · LIQUID","solid":"CARTRIDGE · SOLID ICE"}[phase(state,"pack")]
	_labels.jacket.text = "JACKET · +6°C" if regulated else "JACKET EMPTY"
	if wet:
		_art("cup","dew_cup_circle_full")
	if full:
		_art("gutter","gutter_flowing")
	if world.access.completed(REGION):
		_art("exit","float_latch_latched")
	_presented_frame = ""

func present() -> void:
	super.present()
	if _labels.is_empty():
		return
	_apparatus(_state)
	var task := "Ask Professor Reed"
	if _lesson_seen(): task = "Open humid-air feed"
	if phase(_state,"source") == "humid": task = "Cool the pane with Cryo"
	if phase(_state,"pane") == "liquid": task = "Join gutter and fit elbow"
	if phase(_state,"elbow") == "fitted": task = "Seat irrigation tank"
	if phase(_state,"tank") == "seated": task = "Fill cartridge in Dewglass workroom"
	if phase(_state,"pack") == "liquid": task = "Freeze filled cartridge with Cryo"
	if phase(_state,"pack") == "solid": task = "Lift frozen cartridge"
	if _state.items[PARTS.CARTRIDGE] == "player": task = "Walk cartridge to pane jacket"
	if phase(_state,"jacket") == "regulated": task = "Measure liquid in irrigation tank"
	if phase(_state,"tank") == "full": task = "Release greenhouse latch"
	var complete: bool = world.access.completed(REGION)
	chunk.quests = [{"text":"Greenhouse latch released" if complete else task,"state":"done" if complete else "active"}]
	chunk.tutorial = ""

func _process(delta: float) -> void:
	if not _can_write():
		return
	var collecting := phase(_state,"jacket") == "regulated" and phase(_state,"tank") == "seated"
	_elapsed = minf(COLLECTION_SECONDS,_elapsed+delta) if collecting else 0.0
	var pane: Node = targets.get(PARTS.PANE)
	var pack: Node = targets.get(PARTS.PACK)
	var cooling: bool = is_instance_valid(pane) and not pane.is_committed() and pane.exposure() > 0
	var freezing: bool = is_instance_valid(pack) and not pack.is_committed() and pack.exposure() > 0
	var frame := "%s:%s:%s" % [cooling,freezing,collecting]
	if frame == _presented_frame:
		return
	_presented_frame = frame
	if cooling:
		_art("pane","cooled_pane_cooled")
		_labels.pane.text = "+6°C · COOLING"
	if freezing:
		_art("pack","cooling_pack_freezing")
		_labels.pack.text = "CARTRIDGE · FREEZING"
	if collecting:
		_art("pane","cooled_pane_collecting")
		_art("gutter","gutter_flowing")
		_art("tank","collector_tank_collecting")
		_labels.tank.text = "COLLECTING LIQUID"

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	var state: Dictionary = raw if _supported_state(raw) else default_state()
	for assembly in assemblies.values():
		assembly.present(state.components,state.items)
	_apparatus(state)

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_checkpoints() -> Array:
	var result := []
	for id in CHECKPOINTS:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor(REGION,id),"attuned":_travel_allowed(id),"allowed":_travel_allowed.bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION,world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	return world.recover_world_checkpoint(world.access)

func suspend() -> void:
	_elapsed = 0.0
	super.suspend()

func _exit_tree() -> void:
	for record in _retired_bodies:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.collision_layer = record.layer
	for art in _reserved_art:
		if is_instance_valid(art): art.show()
	if is_instance_valid(_help): _help.queue_free()
	super._exit_tree()
