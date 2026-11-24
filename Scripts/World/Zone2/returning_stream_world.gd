extends "res://Scripts/World/Learning/subregion_adapter.gd"
## One finite water batch. Only measured liquid authorizes the physical lift.
const PARTS = preload("res://Scripts/World/Zone2/stream_circuit_assembly.gd")
const LIFT = preload("res://Scripts/World/Zone2/stream_lift.gd")
const ANCHOR = preload("res://Scripts/World/Runtime/grounded_visual.gd")
const REGION := PARTS.REGION
const CHECKPOINTS := ["C0","C1","C2"]
const SUN_SECONDS := 2.0
const RETIRED := ["stream_inlet_frozen","solar_tray_empty","solar_shutter_closed","vapor_channel_gap",
	"channel_fitting","return_collector_warm","collector_tank_empty","water_lift_lowered"]
const LOCAL := {"inlet":Vector2(-190,-70),"basin":Vector2(-96,-70),"channel":Vector2(-3,-70),
	"plate":Vector2(94,-70),"tank":Vector2(184,-70),"shutter":Vector2(-90,5),"fitting":Vector2(-17,12),
	"lift":Vector2(-94,127),"exit":Vector2(144,127)}
var points := {}
var lift_layout: LIFT
var _retired_art: Array[Node2D] = []
var _retired_bodies: Array[Dictionary] = []
var _help: Marker2D
var _labels := {}
var _pipes: Node2D
var _feed: Line2D
var _cover_join: Line2D
var _vapor: Array[Polygon2D] = []
var _return: Line2D
var _drive_water: Line2D
var _sun_time := 0.0
var _flow_time := 0.0

func bind_stream(host: Node2D) -> bool:
	var model: RefCounted = host.geometry.region_models[REGION]
	for site in model.data.stations:
		if site.subregion == REGION:
			points[site.id.get_slice(".",1)] = model.v(site.ground_xy)
	# The original court reserves straddle graded and wet ground. Place their
	# working modules together on the measured common-height C1 apron.
	for id in LOCAL:
		points[id] = points.C1+LOCAL[id]
	if not bind(host,get_parent(),PARTS.definition(points),_completion_ready):
		return false
	_retire_reserves(model)
	lift_layout = LIFT.new()
	add_child(lift_layout)
	lift_layout.install(world,chunk,points.lift)
	component("exit/control").elevation += LIFT.RISE
	assemblies.exit.interaction_markers.control.position.y -= LIFT.RISE
	_help = Marker2D.new()
	_help.position = points.professor-chunk.ground_origin-Vector2(0,world.raised_surface(points.professor).height)
	chunk.add_child(_help)
	for id in ["basin","channel","plate","tank","lift"]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-68,14)
		if id == "plate": label.position.y = -80
		if id == "tank": label.position.y = -62
		label.size.x = 136
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_outline_color",Color("23383a"))
		label.add_theme_constant_override("outline_size",4)
		component(id+"/control").visuals.add_child(label)
		_labels[id] = label
	_install_pipes()
	chunk.checkpoint_provider = self
	sync_world_permissions()
	return true

func _retire_reserves(model: RefCounted) -> void:
	var courts := [REGION+".court1", REGION+".court2", REGION+".court3"]
	for prop in world.props:
		if prop.get_meta("station_id","") in courts and prop.get_meta("asset_id","") in RETIRED:
			_retired_art.append(prop)
			prop.hide()
	for record in model.blockers:
		if record.get("station","") not in courts or not is_instance_valid(record.get("body")):
			continue
		for placement in model.data.equipment:
			if placement.station in courts and placement.asset in RETIRED and record.bounds.get_center().distance_to(model.v(placement.at)) < 1:
				_retired_bodies.append(record)
				record.layer = 0
				record.body.collision_layer = 0
				break

func _pipe(from: String, to: String, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([points[from]-_pipes.position,points[to]-_pipes.position])
	line.width = width
	line.default_color = color
	line.antialiased = true
	_pipes.visuals.add_child(line)
	return line

func _install_pipes() -> void:
	_pipes = ANCHOR.new()
	_pipes.position = points.channel+Vector2(0,2)
	_pipes.elevation = component("basin/control").elevation
	_pipes.z_index = -1
	world.district_art_parent(chunk).add_child(_pipes)
	_pipe("inlet","basin",12,Color("6e7968"))
	_feed = _pipe("inlet","basin",5,Color("80c9d8"))
	var middle: Vector2 = points.channel-_pipes.position
	var before := _pipe("basin","channel",13,Color("acc7af"))
	before.set_point_position(1,middle-Vector2(12,0))
	var after := _pipe("channel","plate",13,Color("acc7af"))
	after.set_point_position(0,middle+Vector2(12,0))
	_cover_join = _pipe("basin","plate",13,Color("acc7af"))
	_cover_join.points = PackedVector2Array([middle-Vector2(13,0),middle+Vector2(13,0)])
	for i in 6:
		var dot := Polygon2D.new()
		dot.color = Color("e8f5d9")
		dot.polygon = PackedVector2Array([Vector2(-2,0),Vector2(0,-2),Vector2(2,0),Vector2(0,2)])
		_pipes.visuals.add_child(dot)
		_vapor.append(dot)
	_pipe("plate","tank",12,Color("6e7968"))
	_return = _pipe("plate","tank",5,Color("80c9d8"))
	var drive := _pipe("tank","lift",9,Color("6e7968"))
	var start: Vector2 = points.tank-_pipes.position
	var end: Vector2 = points.lift-_pipes.position
	drive.points = PackedVector2Array([start,Vector2(start.x,end.y-47),Vector2(end.x,end.y-47),end])
	_drive_water = _pipe("tank","lift",4,Color("80c9d8"))
	_drive_water.points = drive.points

func phase(state: Dictionary, id: String) -> String:
	return state.components[id+"/control"].phase

func compared(state: Dictionary) -> bool:
	return state.components["plate/control"].get("comparison","") == "warm_dry"

func _supported_state(raw: Variant) -> bool:
	if not super._supported_state(raw):
		return false
	var fitting: String = raw.items[PARTS.FITTING]
	var basin := phase(raw,"basin")
	var plate := phase(raw,"plate")
	var tank := phase(raw,"tank")
	return (fitting in [PARTS.BENCH,"player",PARTS.INSTALLED]
		and (fitting == PARTS.BENCH or basin != "empty")
		and (phase(raw,"inlet") == "routed") == (basin != "empty")
		and (phase(raw,"shutter") == "closed" or basin != "empty")
		and (phase(raw,"channel") == "gap" or fitting == PARTS.INSTALLED)
		and (basin != "spent" or (phase(raw,"shutter") == "open" and phase(raw,"channel") == "sealed"))
		and (plate != "empty") == (basin == "spent")
		and (not compared(raw) or plate != "empty")
		and (plate not in ["liquid","drained"] or compared(raw))
		and (plate == "drained") == (tank != "empty")
		and raw.components["tank/control"].get("proof",{}) == (PARTS.measurement() if tank == "measured" else {})
		and (phase(raw,"lift") == "lowered" or tank == "measured")
		and (phase(raw,"exit") == "closed" or phase(raw,"lift") == "locked"))

func snapshot(next: Dictionary = {}) -> Dictionary:
	var state := _state if next.is_empty() else next
	var result := super.snapshot(state)
	if _pending_finish:
		result[STATE_KEY].components["exit/control"].phase = "open"
	var earned := ["C0"]
	if phase(state,"basin") != "empty": earned.append("C1")
	if phase(state,"channel") == "sealed": earned.append("C2")
	result.checkpoint_progress = store.normalize_checkpoint_progress({},CHECKPOINTS,earned)
	result.checkpoint = earned.back()
	result.position = REGISTRY.ground_to_local(REGION,world.player.safe_save_position())
	return result

func _near(id: String) -> bool:
	var from: Vector2 = world.player.position
	var to: Vector2 = points[id]
	if from.distance_to(to) > 45 or not world.world_contact_allowed(from,to):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	if assemblies.has(id) and assemblies[id].bodies.has("control"):
		exclude.append(assemblies[id].bodies.control.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(from,to,1|8,exclude)
	ray.hit_from_inside = true
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func action_allowed(id: String) -> bool:
	if id == "professor":
		return _can_write() and not world.player.carrying and world.player.jump_elapsed < 0 and world.player.action_elapsed < 0 and _near(id)
	if not super.action_allowed(id) or not _near(contract.actions[id].component.get_slice("/",0)):
		return false
	match id:
		"seal": return _state.items[PARTS.FITTING] == PARTS.INSTALLED
		"capture": return _sun_time >= SUN_SECONDS
		"compare": return PARTS.WARM_C >= PARTS.DEW_C and phase(_state,"tank") == "empty"
		"measure": return _has_water_receipts()
		"ride": return lift_layout.boarded(world.player.position)
		"lock": return lift_layout.docked(world.player)
		"exit": return not world.access.completed(REGION) and _completion_ready(_state) and _on_exit_deck()
	return true

func world_context() -> Dictionary:
	if is_instance_valid(_help) and action_allowed("professor"):
		return {"key":REGION+":professor","caption":"Ask Professor Reed","enabled":true,"target":_help,
			"allowed":action_allowed.bind("professor"),"invoke":commit_action.bind("professor")}
	return super.world_context()

func commit_action(id: String) -> bool:
	if not action_allowed(id):
		return false
	match id:
		"professor": return world.input_adapter.open_lesson("return_circuit")
		"exit": return finish()
		"supply", "capture", "drain", "measure", "compare":
			world.input_adapter.stop_all("context_action",true)
			if not action_allowed(id):
				return false
			var next := _state.duplicate(true)
			var changes: Dictionary = next.components
			var successes := []
			match id:
				"supply":
					changes["inlet/control"].phase = "routed"
					changes["basin/control"].phase = "liquid"
				"capture":
					changes["basin/control"].phase = "spent"
					changes["plate/control"].phase = "gas"
				"compare": changes["plate/control"].comparison = "warm_dry"
				"drain":
					changes["plate/control"].phase = "drained"
					changes["tank/control"].phase = "full"
				"measure":
					changes["tank/control"].phase = "measured"
					changes["tank/control"].proof = PARTS.measurement()
					successes.append({"puzzle":"stream_return","type":"evaporate_condense_route"})
			if _supported_state(next) and store.update_run_with_events(snapshot(next),successes,[],world):
				if id == "compare": world.input_adapter.feedback = "+22°C warm plate · zero liquid"
				return true
			world.input_adapter.feedback = "Could not save the circuit. Try again."
			return false
	return super.commit_action(id)

func sample_for(id: String) -> Dictionary:
	var sample := super.sample_for(id)
	if id == PARTS.INLET:
		sample.amount = PARTS.MEASURES if phase(_state,"inlet") == "solid" else 0
	else:
		sample.amount = PARTS.MEASURES if phase(_state,"plate") == "gas" else 0
		if PARTS.COOL_C <= 0 or PARTS.COOL_C >= PARTS.DEW_C:
			sample.phase_region = "unsuitable_plate"
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
	if _supported_state(next) and store.commit_device_outcome(target,snapshot(next),world,[],_events(binding.events,outcome.id)):
		return true
	target.reset_after_restore(world,store)
	world.input_adapter.feedback = "Observation could not be saved. Apply the device again."
	return false

func _has_water_receipts() -> bool:
	var outcomes: Variant = store.data.active_run.get("state",{}).get("device_outcomes")
	return (outcomes is Dictionary and _receipt_matches(outcomes.get(PARTS.INLET),PARTS.INLET,"melting","solid","liquid")
		and _receipt_matches(outcomes.get(PARTS.COLLECTOR),PARTS.COLLECTOR,"condensation","gas","liquid"))

func _receipt_matches(record: Variant, id: String, process: String, from: String, to: String) -> bool:
	return (record is Dictionary and record.get("version") == 1 and record.get("id") == id and record.get("material") == "water"
		and record.get("process") == process and record.get("from_state") == from and record.get("to_state") == to)

func _completion_ready(state: Dictionary) -> bool:
	return phase(state,"lift") == "locked" and phase(state,"tank") == "measured" and _has_water_receipts()

func _on_exit_deck() -> bool:
	return world.raised_surface(world.player.position).get("body_path") == LIFT.EXIT_PATH

func completion_authorized() -> bool:
	return super.completion_authorized() and _near("exit") and _on_exit_deck()

func _apparatus(state: Dictionary, snap: bool) -> void:
	if not is_instance_valid(lift_layout) or _labels.is_empty():
		return
	var lift := phase(state,"lift")
	var plate := phase(state,"plate")
	var tank := phase(state,"tank")
	lift_layout.apply(tank == "measured",lift,snap)
	component("fitting/control").visible = state.items[PARTS.FITTING] == PARTS.BENCH
	_labels.basin.text = {"empty":"BASIN EMPTY","liquid":"BASIN · LIQUID","spent":"BASIN · DRAINED"}[phase(state,"basin")]
	_labels.channel.text = "COVER SEALED" if phase(state,"channel") == "sealed" else "COVER GAP"
	if plate == "gas": _labels.channel.text = "VAPOR MODEL"
	_labels.plate.text = {"empty":"WARM PLATE","gas":"+22°C · DRY" if compared(state) else "WARM PLATE",
		"liquid":"+7°C · DROPLETS","drained":"+7°C · RETURN"}[plate]
	_labels.tank.text = {"empty":"TANK · ZERO","full":"TANK · LIQUID","measured":"2 MEASURES"}[tank]
	_labels.lift.text = {"lowered":"LIFT READY" if tank == "measured" else "LIFT · NO WATER","raised":"LIFT · LOCK OPEN","locked":"LIFT LOCKED"}[lift]
	if world.access.completed(REGION): component("exit/control").visuals.get_node("Artwork").texture = load(PARTS.KIT.art("float_latch_latched").path)
	if is_instance_valid(_feed):
		_feed.visible = phase(state,"basin") == "liquid"
		_cover_join.visible = phase(state,"channel") == "sealed"
		for dot in _vapor: dot.visible = plate == "gas"
		_return.visible = plate in ["liquid","drained"]
		_drive_water.visible = tank == "measured"

func present() -> void:
	super.present()
	if not is_instance_valid(lift_layout):
		return
	_apparatus(_state,false)
	var task := "Melt inlet at C1 with Thermal"
	if phase(_state,"inlet") == "liquid": task = "Route meltwater to basin"
	if phase(_state,"basin") == "liquid": task = "Fit and clamp channel cover, open shutter"
	if phase(_state,"channel") == "sealed" and phase(_state,"shutter") == "open": task = "Send captured vapor to plate"
	if phase(_state,"plate") == "gas": task = "Cool plate with Cryo" if compared(_state) else "Test uncooled plate"
	if phase(_state,"plate") == "liquid": task = "Drain droplets into measuring tank"
	if phase(_state,"tank") == "full": task = "Measure returned liquid"
	if phase(_state,"tank") == "measured": task = "Board and raise water lift"
	if phase(_state,"lift") == "raised": task = "Lock lift at upper landing"
	if phase(_state,"lift") == "locked": task = "Walk off lift, then jump fixed gap"
	var complete: bool = world.access.completed(REGION)
	chunk.quests = [{"text":"Stream exit open" if complete else task,"state":"done" if complete else "active"}]
	chunk.tutorial = ""

func _process(delta: float) -> void:
	if is_instance_valid(lift_layout): lift_layout.advance(delta)
	if not _can_write():
		return
	var sunny := phase(_state,"basin") == "liquid" and phase(_state,"channel") == "sealed" and phase(_state,"shutter") == "open"
	_sun_time = minf(SUN_SECONDS,_sun_time+delta) if sunny else 0.0
	if phase(_state,"plate") == "gas":
		_flow_time = fmod(_flow_time+delta,1.8)
		var from: Vector2 = points.basin-_pipes.position
		var to: Vector2 = points.plate-_pipes.position
		for i in _vapor.size(): _vapor[i].position = from.lerp(to,fmod(_flow_time/1.8+float(i)/_vapor.size(),1.0))

func sync_world_permissions() -> void:
	if world.active_chunk() == chunk:
		refresh_binding()
		if active() and not _state.is_empty(): return
	var raw: Variant = store.world_record().get("attempts",{}).get(REGION,{}).get("attempt",{}).get("state",{}).get(STATE_KEY)
	var state: Dictionary = raw if _supported_state(raw) else default_state()
	for assembly in assemblies.values(): assembly.present(state.components,state.items)
	_apparatus(state,true)

func restore_world_attempt(record: Dictionary) -> void:
	super.restore_world_attempt(record)
	if not _state.is_empty(): _apparatus(_state,true)

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
	_sun_time = 0.0
	super.suspend()

func _exit_tree() -> void:
	for record in _retired_bodies:
		record.layer = record.original_layer
		if is_instance_valid(record.body): record.body.collision_layer = record.layer
	for art in _retired_art:
		if is_instance_valid(art): art.show()
	if is_instance_valid(_help): _help.queue_free()
	if is_instance_valid(_pipes): _pipes.queue_free()
	super._exit_tree()
