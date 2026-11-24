extends "res://Scripts/World/Zone1/stillwater_assembly.gd"
## Workshop kit pieces. The jig and wooden frame have independent state.

static func definition(points: Dictionary) -> Dictionary:
	var mirrors := {}
	for index in range(8):
		mirrors[str(index)] = visual("mirror_%d" % index, .72)
	var lamp := site("storage", points.court1, [
		part("source", [1, 3, 0], 1.5, {"phase":"sun"}, {"sun":visual("receiver_on", .75)}),
		part("mirror_a", [2, 3, 0], 1.6, {"phase":"0"}, mirrors),
		part("mirror_b", [4, 3, 0], 1.6, {"phase":"0"}, mirrors),
		part("receiver", [4, 1, 0], 1.5, {"phase":"off"}, {
			"off":visual("receiver_off", .8), "on":visual("receiver_on", .8)}),
		part("heater", [5, 4, 0], 1.5, {"phase":"off"}, {
			"off":visual("heater_empty", .7), "on":visual("heater_active", .7)}),
		part("latch", [3.25, 5, 0], 1.5, {"phase":"solid"}, {
			"solid":visual("storage_latch_frozen"), "liquid":visual("storage_latch_thawed"), "open":visual("storage_latch_open")}),
	])
	var plank := part("plank", [1.25, 4.75, 0], 1.7, {"phase":"rough"}, {
		"rough":visual("practice_plank", .8), "finished":visual("practice_plank", .8)})
	plank.item_id = "practice_plank"
	var jig_variants := {}
	for phase in ["empty", "liquid", "solid", "fitted", "released", "drained"]:
		jig_variants[phase] = visual("workshop_jig_" + phase, .88)
	var gate := part("gate", [3, 3, 0], 1.3, {"phase":"closed"}, {
		"closed":visual("maintenance_gate_closed", .55), "open":visual("maintenance_gate_open", .55)})
	gate.collision_bounds = [[-5,-26],[5,-26],[5,26],[-5,26]]
	gate.collision_layer = 2
	var rig := site("rig", points.court2, [
		plank, gate,
		part("rack", [1.25, 4.75, 0], 1.65, {"phase":"rack"}, {"rack":visual("sample_frame", .68)}),
		part("valve", [3.4, 1.1, 0], 1.5, {"phase":"closed"}, {
			"closed":visual("canal_diverter_main", .68), "open":visual("canal_diverter_side", .68)}),
		part("supply", [1.4, 1.4, 0], 1.8, {"phase":"liquid"}, {
			"liquid":visual("supply_liquid", .68), "empty":visual("cooling_tray_drained", .68)}),
		part("jig", [4.6, 2.45, 0], 2.15, {"phase":"empty"}, jig_variants),
		part("frame", [4.65, 2.05, 0], 1.7, {"phase":"frame"}, {"frame":visual("sample_frame", .72)}),
		part("drain", [4.8, 4.8, 0], 1.5, {"phase":"closed"}, {
			"closed":visual("drain_closed", .76), "open":visual("drain_open", .76)}),
		part("basin", [3.1, 4.9, 0], 1.65, {"phase":"empty"}, {
			"empty":visual("cooling_tray_empty", .62), "liquid":visual("cooling_tray_liquid", .62)}),
	])
	var plan := part("blueprint", [4.5, 2.6, 0], 1.6, {"phase":"recorded"}, {"recorded":visual("boat_blueprint", .8)})
	var desk := site("desk", points.court3, [
		part("bench", [3, 3, 0], 2.2, {"phase":"bench"}, {"bench":visual("workshop_bench", .85)}),
		plan,
	])
	return {
		"subregion":"Z1L5", "assemblies":[lamp, rig, desk],
		"items":{"practice_plank":{"source":"rig/plank", "initial_owner":"world:rig/rack"}},
		"targets":{"freeze_jig":transition("freezing"), "melt_jig":transition("melting")},
		"actions":{
			"mirror_a":control("storage/mirror_a", "Rotate first mirror", "next"),
			"mirror_b":control("storage/mirror_b", "Rotate second mirror", "next"),
			"open":control("storage/latch", "Open thawed storage latch", "open"),
			"walkback":control("rig/gate", "Open walkback gate", "open"),
			"fill":control("rig/valve", "Fill jig from reservoir", "open"),
			"take":cargo("rig/rack", "Pick up practice plank", "pickup"),
			"put_back":cargo("rig/rack", "Return plank to rack", "place"),
			"fit":cargo("rig/frame", "Fit plank into frozen jig", "place"),
			"drain":control("rig/drain", "Drain meltwater into basin", "open"),
			"retrieve":cargo("rig/frame", "Pick up released workpiece", "pickup"),
			"stow":cargo("rig/rack", "Set finished sample on rack", "place"),
			"draft":control("desk/bench", "Record boat blueprint", "recorded"),
		},
	}

static func control(component: String, caption: String, value: String) -> Dictionary:
	return {"component":component, "caption":caption, "kind":"set", "field":"phase", "value":value}

static func cargo(component: String, caption: String, kind: String) -> Dictionary:
	return {"component":component, "caption":caption, "kind":kind, "item":"practice_plank"}

static func transition(process: String) -> Dictionary:
	var melts := process == "melting"
	return {
		"component":"rig/jig",
		"spec":{"zone":"melting_and_freezing", "level":5, "material":"water", "process":process,
			"allowed_modes":["thermal" if melts else "cryo"], "required_exposure":3.0, "max_range":105.0,
			"required_flags":["ready"]},
		"sample":{"material":"water", "amount":1, "phase_region":process, "heat_flow":"in" if melts else "out"},
		"flags":{"ready":{"component":"rig/jig", "field":"phase", "value":"fitted" if melts else "liquid"}},
	}
