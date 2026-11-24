extends "res://Scripts/World/Learning/subregion_adapter.gd"
## One working-water batch and one independent coolant charge.
const PARTS = preload("res://Scripts/World/Zone2/steamworks_assembly.gd")
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const REGION := PARTS.REGION
const CHECKPOINTS := ["C0","C1","C2"]
const BLUEPRINT_ID := "vaporization_and_condensation:5:engine_blueprint"
const BLUEPRINT_TYPE := "boiler_reservoir_return"
const DRY_SECONDS := 2.0
const DRIVE_SECONDS := 1.4
const RESERVES := ["stream_inlet","drying_rack","drive_belt","cooling_pack","pack_socket",
	"boiler","model_turbine","cooling_jacket","return_collector","return_reservoir","engine_blueprint"]
const LOCAL := {
	"inlet":Vector2(-216,-76), "boiler":Vector2(-120,-76), "turbine":Vector2(-21,-76),
	"condenser":Vector2(77,-76), "reservoir":Vector2(175,-76),
	"rack":Vector2(-216,24), "belt":Vector2(-216,41), "fan":Vector2(-139,26), "shutter":Vector2(-139,97),
	"drive":Vector2(-21,-30), "jacket":Vector2(77,-26), "pack":Vector2(77,76),
}
var points := {}
var _labels := {}
var _help: Marker2D
var _pipes: Node2D
var _feed: Line2D
var _exhaust: Line2D
var _return: Line2D
var _vapor: Array[Polygon2D] = []
var _hidden_reserves: Array[Node2D] = []
var _disabled_reserves: Array[Dictionary] = []
var _dry_time := 0.0
var _drive_time := 0.0

static func engine_blueprint_unlocked(profile: Dictionary) -> bool:
	var extras: Variant = profile.get("extras")
	if not extras is Dictionary:
		return false
	var receipts: Variant = extras.get("independent_puzzle_ids")
	return receipts is Dictionary and receipts.get(BLUEPRINT_ID) == BLUEPRINT_TYPE

func bind_steamworks(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	# Place the working modules on the same supported terrace so the feed,
	# steam and liquid paths can be traced directly between their endpoints.
	for id in LOCAL:
		points[id] = points.C1 + LOCAL[id]
	points.desk = points.C2 + Vector2(0,-57)
	if not bind(host,get_parent(),PARTS.definition(points),_completion_ready):
		return false
	_hide_reserves(model)
	_help = Marker2D.new()
	_help.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_help)
	for id in ["rack","boiler","turbine","condenser","reservoir"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-69,5)
		label.size.x = 138
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("263e40"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	_build_pipes()
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _hide_reserves(model: RefCounted) -> void:
	var courts := [REGION+".court1",REGION+".court2",REGION+".court3"]
	for placement in model.data.equipment:
		if placement.station not in courts or placement.group not in RESERVES:
			continue
		var at: Vector2 = model.v(placement.at)
		for prop in world.props:
			if (prop.get_meta("station_id","") == placement.station and prop.get_meta("asset_id","") == placement.asset
					and prop.position.distance_to(at) < 1.0):
				prop.hide()
				_hidden_reserves.append(prop)
		for record in model.blockers:
			if (record.get("station","") == placement.station and record.bounds.get_center().distance_to(at) < 1.0
					and is_instance_valid(record.get("body"))):
				_disabled_reserves.append({"record":record,"layer":record.layer,"body_layer":record.body.collision_layer})
				record.layer = 0
				record.body.collision_layer = 0

func _line(path: Array, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	for point in path:
		line.add_point(point-_pipes.position)
	line.width = width
	line.default_color = color
	line.antialiased = true
	_pipes.visuals.add_child(line)
	return line

func _build_pipes() -> void:
	_pipes = ANCHOR.new()
	_pipes.position = points.turbine
	_pipes.elevation = component("turbine/control").elevation
	_pipes.z_index = -1
	world.district_art_parent(chunk).add_child(_pipes)
	var feed := [points.inlet,points.boiler]
	var return_line := [points.condenser,points.reservoir]
	_line(feed,10,Color("6e795f"))
	_line([points.boiler,points.turbine,points.condenser],12,Color("b2b7a1"))
	_line(return_line,10,Color("6e795f"))
	_line([points.turbine,points.drive],6,Color("75644d"))
	_line([points.condenser,points.jacket],7,Color("62838a"))
	_feed = _line(feed,4,Color("7dc2d4"))
	_exhaust = _line([points.turbine,points.condenser],4,Color("e0c9a0"))
	_return = _line(return_line,4,Color("7dc2d4"))
	for i in 4:
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-2,0),Vector2(0,-2),Vector2(2,0),Vector2(0,2)])
		dot.color = Color("fff2ce")
		dot.hide()
		_pipes.visuals.add_child(dot)
		_vapor.append(dot)

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw) or raw.items.size() != 2:
		return false
	var belt: String = raw.items[PARTS.BELT]
	var pack: String = raw.items[PARTS.PACK]
	var rack := phase(raw,"rack")
	var jacket := phase(raw,"jacket")
	var boiler := phase(raw,"boiler")
	var turbine := phase(raw,"turbine")
	var condenser := phase(raw,"condenser")
	var returned := phase(raw,"reservoir") == "returned"
	return (belt in [PARTS.BELT_SOURCE,"player",PARTS.BELT_SOCKET]
		and pack in [PARTS.PACK_SOURCE,"player",PARTS.PACK_SOCKET]
		and (rack == "wet" or phase(raw,"inlet") != "solid")
		and (rack not in ["drying","dry"] or (phase(raw,"fan") == "air" and phase(raw,"shutter") == "open"))
		and (belt == PARTS.BELT_SOURCE or rack == "dry")
		and (phase(raw,"pack") == "liquid" or rack == "dry")
		and (pack == PARTS.PACK_SOURCE or phase(raw,"pack") != "liquid")
		and (jacket != "empty") == (pack == PARTS.PACK_SOCKET)
		and (phase(raw,"inlet") == "fed") == (boiler != "empty")
		and (boiler == "empty" or (belt == PARTS.BELT_SOCKET and pack == PARTS.PACK_SOCKET))
		and (boiler == "spent") == (turbine != "idle")
		and (turbine == "stopped") == (condenser != "empty")
		and (phase(raw,"pack") == "spent") == (condenser in ["liquid","drained"])
		and (jacket == "spent") == (phase(raw,"pack") == "spent")
		and returned == (condenser == "drained")
		and (phase(raw,"desk") == "locked" or returned)
		and (phase(raw,"exit") == "closed" or phase(raw,"desk") == "recorded"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].components["exit/control"].phase = "open"
	var unlocked := ["C0"]
	if phase(state,"rack") == "dry": unlocked.append("C1")
	if phase(state,"reservoir") == "returned": unlocked.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,unlocked)
	result.checkpoint = unlocked.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _near(id: String) -> bool:
	var from: Vector2 = world.player.position
	var at: Vector2 = points[id]
	if from.distance_to(at) > 45 or not world.world_contact_allowed(from,at):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	var owner := "rack" if id == "belt" else id
	if assemblies.has(owner) and assemblies[owner].bodies.has("control"):
		exclude.append(assemblies[owner].bodies.control.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from,at,1|8,exclude)
	query.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func action_allowed(id: String) -> bool:
	if id == "professor":
		return (_can_write() and not world.player.carrying and world.player.jump_elapsed < 0
			and world.player.action_elapsed < 0 and _near(id))
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"dry": return _dry_time >= DRY_SECONDS
		"fill": return _state.items[PARTS.BELT] == PARTS.BELT_SOCKET
		"route": return _has_outcome(PARTS.BOILER,"boiling")
		"exhaust": return _drive_time <= 0.0
		"drain", "blueprint": return _verified_batch()
		"exit": return not world.access.completed(REGION) and _completion_ready(_state)
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_help) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Reed","enabled":true,"target":_help,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	if id == "professor":
		return world.input_adapter.open_lesson("steamworks")
	if id == "exit":
		return finish()
	world.input_adapter.stop_all("context_action",true)
	if not action_allowed(id):
		return false
	var action: Dictionary = contract.actions[id]
	var next := _state.duplicate(true)
	var parts: Dictionary = next.components
	var successes := []
	var events := []
	match action.kind:
		"pickup": next.items[action.item] = "player"
		"place": next.items[action.item] = "installed:"+action.component
		"set": parts[action.component][action.field] = action.value
	match id:
		"dry":
			successes.append({"puzzle":"steamworks_belt_drying","type":"evaporate_drying",
				"topic":"vaporization","object":"steamworks_rack"})
		"fit_pack": parts["jacket/control"].phase = "fitted"
		"fill": parts["inlet/control"].phase = "fed"
		"route": parts["boiler/control"].phase = "spent"
		"exhaust": parts["condenser/control"].phase = "gas"
		"drain":
			parts["condenser/control"].phase = "drained"
			events.append({"id":"round_trip","members":[]})
		"blueprint":
			if not engine_blueprint_unlocked(store.data):
				successes.append({"puzzle":"engine_blueprint","type":BLUEPRINT_TYPE})
	if not _supported_state(next) or not store.update_run_with_events(snapshot(next),successes,_events(events,id),world):
		world.input_adapter.feedback = "Could not save the Steamworks setup. Try again."
		return false
	if id == "route":
		_drive_time = DRIVE_SECONDS
	return true

func commit_target(target: Node) -> bool:
	if not _can_write() or not owns_target(target):
		return false
	var outcome: Dictionary = target.verified_outcome(store,world)
	if outcome.is_empty():
		return false
	var binding: Dictionary = contract.targets[outcome.id]
	var next := _state.duplicate(true)
	next.components[binding.component].phase = outcome.to_state
	if outcome.id == PARTS.CONDENSER:
		next.components["pack/control"].phase = "spent"
		next.components["jacket/control"].phase = "spent"
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(binding.events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	world.input_adapter.feedback = "Observation could not be saved. Apply the device again."
	return false

func _has_outcome(id: String, process: String) -> bool:
	var records: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	var receipt: Variant = records.get(id) if records is Dictionary else null
	var rule: Dictionary = RULES.PROCESSES[process]
	return (receipt is Dictionary and receipt.get("version") == 1 and receipt.get("id") == id
		and receipt.get("process") == process and receipt.get("material") == "water"
		and receipt.get("from_state") == rule.from and receipt.get("to_state") == rule.to)

func _verified_batch() -> bool:
	return (_has_outcome(PARTS.INLET,"melting") and _has_outcome(PARTS.FREEZER,"freezing")
		and _has_outcome(PARTS.BOILER,"boiling") and _has_outcome(PARTS.CONDENSER,"condensation"))

func _completion_ready(state: Dictionary) -> bool:
	return (phase(state,"desk") == "recorded" and phase(state,"reservoir") == "returned"
		and engine_blueprint_unlocked(store.data) and _verified_batch())

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
	var belt: String = state.items[PARTS.BELT]
	var pack: String = state.items[PARTS.PACK]
	component("belt/control").visible = belt == PARTS.BELT_SOCKET
	if belt != PARTS.BELT_SOURCE:
		_art("rack","drying_rack_cleared")
	component("pack/control").visible = pack == PARTS.PACK_SOURCE
	if pack == PARTS.PACK_SOCKET:
		assemblies.pack.bodies.control.collision_layer = 0
	var rack_status := {"wet":"WET BELT","spread":"BELT SPREAD","drying":"EVAPORATING","dry":"DRY BELT"}
	_labels.rack.text = rack_status[phase(state,"rack")] if belt == PARTS.BELT_SOURCE else "RACK EMPTY"
	_labels.boiler.text = {"empty":"BOILER EMPTY","filled":"GUARD OPEN","liquid":"ADD HEAT",
		"gas":"VAPOR READY","spent":"HEAT OFF"}[phase(state,"boiler")]
	_labels.turbine.text = "TURBINE IDLE" if phase(state,"turbine") == "idle" else "TURBINE STOPPED"
	_labels.condenser.text = {"empty":"CONDENSER","gas":"EXHAUST GAS",
		"liquid":"LIQUID DROPS","drained":"DRAINED"}[phase(state,"condenser")]
	_labels.reservoir.text = "2 MEASURES" if phase(state,"reservoir") == "returned" else "RESERVOIR EMPTY"
	_feed.visible = phase(state,"boiler") in ["filled","liquid"]
	_exhaust.visible = phase(state,"condenser") == "gas"
	_return.visible = phase(state,"reservoir") == "returned"
	var task := "Meet Professor Reed, then use Thermal on the C1 inlet"
	if phase(state,"inlet") == "liquid":
		task = "Spread belt, open shutter and run fan"
	if phase(state,"rack") == "dry":
		task = "Fit belt. Freeze and fit cooling pack."
	if phase(state,"jacket") == "fitted" and belt == PARTS.BELT_SOCKET:
		task = "Feed thawed inlet water to the boiler"
	match phase(state,"boiler"):
		"filled": task = "Close boiler guard, keep vent open"
		"liquid": task = "Add external heat with Thermal"
		"gas": task = "Send boiler vapor through turbine"
		"spent": task = "Route turbine exhaust to condenser"
	match phase(state,"condenser"):
		"gas": task = "Remove exhaust heat with Cryo at the condenser"
		"liquid": task = "Drain condensate into the reservoir"
		"drained": task = "Record engine blueprint at C2"
	if phase(state,"desk") == "recorded":
		task = "Follow the trail to the Steamworks exit"
	var done: bool = phase(state,"exit") == "open" or world.access.completed(REGION)
	chunk.quests = [{"text":"Steamworks exit open" if done else task,"state":"done" if done else "active"}]
	chunk.tutorial = ""

func present() -> void:
	super.present()
	if not _state.is_empty():
		_apparatus(_state)

func _process(delta: float) -> void:
	if not _can_write() or not is_instance_valid(_pipes):
		return
	if phase(_state,"rack") == "drying":
		_dry_time = minf(_dry_time+delta,DRY_SECONDS)
	if _drive_time <= 0.0:
		return
	_drive_time = maxf(0.0,_drive_time-delta)
	var moving := _drive_time > 0.0
	var elapsed := 1.0-_drive_time/DRIVE_SECONDS
	_art("turbine",("model_turbine_turn_a" if int(elapsed*18)%2 == 0 else "model_turbine_turn_b") if moving else "model_turbine_idle")
	_labels.turbine.text = "VAPOR MODEL" if moving else "TURBINE STOPPED"
	for i in _vapor.size():
		var dot: Polygon2D = _vapor[i]
		var fraction := elapsed*1.4-float(i)*.13
		dot.visible = moving and fraction >= 0.0 and fraction <= 1.0
		dot.position = points.boiler.lerp(points.turbine,clampf(fraction,0,1))-_pipes.position

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty():
			return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	var state: Dictionary = raw if _supported_state(raw) else default_state()
	var locations := {}
	for id in assemblies:
		locations[id+"/control"] = points[id]
	for assembly in assemblies.values():
		assembly.present(state.components,state.items,locations)
	_apparatus(state)

func _travel_allowed(id: String) -> bool:
	return active() and not _state.is_empty() and not world.player.carrying and id in snapshot().checkpoint_progress.unlock_sequence

func world_checkpoints() -> Array:
	var result := []
	for id in CHECKPOINTS:
		result.append({"id":id,"name":id,"position":world.checkpoint_anchor(REGION,id),
			"attuned":_travel_allowed(id),"allowed":_travel_allowed.bind(id)})
	return result

func world_travel_checkpoint(id: String) -> bool:
	return _travel_allowed(id) and world.activate(REGION,world.checkpoint_anchor(REGION,id))

func recover_world_fall() -> bool:
	return world.recover_world_checkpoint(world.access)

func suspend() -> void:
	_dry_time = 0.0
	_drive_time = 0.0
	for dot in _vapor:
		if is_instance_valid(dot):
			dot.hide()
	super.suspend()

func _exit_tree() -> void:
	for entry in _disabled_reserves:
		entry.record.layer = entry.layer
		if is_instance_valid(entry.record.body):
			entry.record.body.collision_layer = entry.body_layer
	for prop in _hidden_reserves:
		if is_instance_valid(prop):
			prop.show()
	if is_instance_valid(_help): _help.queue_free()
	if is_instance_valid(_pipes): _pipes.queue_free()
	super._exit_tree()
