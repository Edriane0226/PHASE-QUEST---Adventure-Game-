extends "res://Scripts/World/Zone1/stillwater_assembly.gd"
## Zone 1 kit pieces at measured offsets inside the three existing courts.

static func definition(points: Dictionary) -> Dictionary:
	var intake := site("intake", points.court1, [
		part("water", [2.6, 3.4, 0], 2, {"phase":"solid"}, {
			"solid":visual("canal_blocked"), "liquid":visual("canal_liquid")}),
		part("diverter", [4.4, 2, 0], 1.5, {"phase":"main"}, {
			"main":visual("canal_diverter_main"), "side":visual("canal_diverter_side")}),
	])
	var branches := site("branches", points.court2, [
		part("isolator", [2.7, 4.4, 0], 1.5, {"phase":"open"}, {
			"open":visual("canal_diverter_side"), "closed":visual("canal_diverter_main")}),
		part("side", [2.7, 3.6, 0], 2, {"phase":"empty"}, {
			"empty":visual("cooling_tray_empty"), "liquid":visual("canal_isolated"), "solid":visual("canal_frozen")}),
		part("drive", [5.1, 1, 0], 1.5, {"phase":"open"}, {
			"open":visual("storage_latch_thawed"), "engaged":visual("storage_latch_open")}),
	])
	var main := site("wheel_channel", points.court2 + Vector2(30, -62), [
		part("main", [2.2, 3.7, 0], 2, {"phase":"blocked"}, {
			"blocked":visual("canal_blocked", .85), "liquid":visual("canal_liquid", .85)}),
		part("wheel", [4, 2.6, 0], 1.5, {"phase":"stopped"}, {
			"stopped":visual("canal_wheel_stopped", .85), "turning":visual("canal_wheel_turn_a", .85)}),
	])
	var lock := part("lock", [2, 5.1, 0], 1.6, {"phase":"wrong"}, {
		"wrong":visual("bridge_lock_frozen_wrong"), "thawed":visual("bridge_lock_thawed"),
		"seated":visual("bridge_lock_repositioned"), "frozen":visual("bridge_lock_repositioned"),
		"latched":visual("bridge_lock_latched")})
	lock.item_id = "bridge_lock"
	var correction := site("correction", points.court3, [
		lock,
		part("socket", [1.6, 4.1, 0], 1.5, {"phase":"empty"}, {
			"empty":visual("storage_latch_open"), "occupied":visual("storage_latch_frozen")}),
		part("latch", [1.2, 3.6, 0], 1.5, {"phase":"open"}, {
			"open":visual("heat_shutter_isolated"), "latched":visual("bridge_lock_latched")}),
		part("release", [5.1, 1, 0], 1.5, {"phase":"closed"}, {
			"closed":visual("storage_latch_frozen"), "open":visual("storage_latch_open")}),
	])
	return {
		"subregion":"Z1L4", "assemblies":[intake, branches, main, correction],
		"items":{"bridge_lock":{"source":"correction/lock", "initial_owner":"world:correction/lock"}},
		"targets":{
			"thaw_intake":transition("intake/water", "melting"),
			"freeze_side":transition("branches/side", "freezing"),
			"thaw_lock":transition("correction/lock", "melting"),
			"refreeze_lock":transition("correction/socket", "freezing"),
		},
		"actions":{
			"divert":control("intake/diverter", "Divert meltwater to side channel", "side"),
			"isolate":control("branches/isolator", "Isolate side channel · reopen main flow", "closed"),
			"drive":control("branches/drive", "Engage wheel drive", "engaged"),
			"pickup":{"component":"correction/lock", "caption":"Pick up thawed bridge lock", "kind":"pickup", "item":"bridge_lock"},
			"seat":{"component":"correction/socket", "caption":"Fit lock into support socket", "kind":"place", "item":"bridge_lock"},
			"latch":control("correction/latch", "Latch corrected crossing", "latched"),
			"release":control("correction/release", "Release canal exit", "open"),
		},
	}

static func control(component: String, caption: String, value: String) -> Dictionary:
	return {"component":component, "caption":caption, "kind":"set", "field":"phase", "value":value}

static func transition(component: String, process: String) -> Dictionary:
	var melts := process == "melting"
	return {
		"component":component,
		"spec":{"zone":"melting_and_freezing", "level":4, "material":"water", "process":process,
			"allowed_modes":["thermal" if melts else "cryo"], "required_exposure":3.0, "max_range":105.0,
			"required_flags":["ready"]},
		"sample":{"material":"water", "amount":1, "phase_region":process, "heat_flow":"in" if melts else "out"},
		# The live provider also checks the ordered stage and unique lock owner.
		"flags":{"ready":{"component":component, "field":"phase", "value":"solid" if melts else "liquid"}},
	}
