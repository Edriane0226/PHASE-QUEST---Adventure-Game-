extends "res://Scripts/World/Zone1/stillwater_assembly.gd"
## Accepted Zone 2 kit artwork and separate, cube-based apparatus bindings.
const ZONE := "vaporization_and_condensation"
const MILESTONE := "z2l1_vaporization"
const KIT := "res://assets/zones/zone_2/world_v1/kit_catalog.json"
const PLANK := "landing_plank"
const BOUNDS := {
	"canopy":Vector2(34,17), "shutter":Vector2(24,14), "reflector":Vector2(20,12),
	"tray":Vector2(30,16), "float":Vector2(24,14), "boiler":Vector2(33,22),
	"turbine":Vector2(30,21), "crate":Vector2(25,14), "support":Vector2(26,15),
}
static var _art: Dictionary = {}

static func art(id: String) -> Dictionary:
	if _art.is_empty():
		for entry in JSON.parse_string(FileAccess.get_file_as_string(KIT)).entries:
			_art[entry.id] = {"path":entry.path, "pivot_px":entry.pivot_px, "scale":entry.world_scale}
	return _art[id]

static func fixture(id: String, at: Vector2, initial: String, images: Dictionary, size := 2.0) -> Dictionary:
	var variants := {}
	for phase in images:
		variants[phase] = art(images[phase])
	var spec := part("control", [3,3,0], size, {"phase":initial}, variants)
	if BOUNDS.has(id):
		var half: Vector2 = BOUNDS[id]
		spec.collision_bounds = [[-half.x,-half.y],[half.x,-half.y],[half.x,half.y],[-half.x,half.y]]
	return site(id, at, [spec])

static func phase(component: String, value: String) -> Dictionary:
	return {"component":component + "/control", "field":"phase", "value":value}

static func control(id: String, label: String, value: String, requires: Array = []) -> Dictionary:
	var action := phase(id, value)
	action.merge({"caption":label, "kind":"set", "requires":requires})
	return action

static func transition(component: String, process: String, gates: Dictionary, seconds: float) -> Dictionary:
	var rule: Dictionary = preload("res://Scripts/Content/phase_transition_rules.gd").PROCESSES[process]
	var flags := {}
	for id in gates:
		flags[id] = phase(gates[id][0], gates[id][1])
	var spec := {"zone":ZONE, "level":1, "material":"water", "process":process,
		"allowed_modes":rule.modes, "required_exposure":seconds, "max_range":105.0, "required_flags":flags.keys()}
	var target := {"component":component + "/control", "occlusion_component":component + "/control", "spec":spec, "flags":flags,
		"sample":{"material":"water", "amount":1, "phase_region":rule.region, "heat_flow":rule.heat},
		"events":[{"id":"six_changes", "members":[process]}]}
	if rule.capability == "vaporization":
		target.milestone = MILESTONE
		spec.introductory_milestone = MILESTONE
		target.events.append({"id":"surface_escape" if process == "evaporation" else "bubble_business", "members":[]})
		if process == "evaporation":
			target.events.append({"id":"field_notes", "members":["vaporization"]})
	return target

static func definition(points: Dictionary) -> Dictionary:
	var fixtures := [
		fixture("canopy", points.canopy, "closed", {"closed":"solar_canopy_closed", "open":"solar_canopy_open"}),
		fixture("shutter", points.shutter, "closed", {"closed":"solar_shutter_closed", "open":"solar_shutter_open"}),
		fixture("reflector", points.reflector, "0", {"0":"solar_reflector_0", "1":"solar_reflector_1", "2":"solar_reflector_2", "3":"solar_reflector_3"}),
		fixture("tray", points.tray, "empty", {"empty":"solar_tray_empty", "liquid":"solar_tray_supplied", "gas":"solar_tray_observed"}, 2.5),
		fixture("float", points.float, "covered", {"covered":"float_latch_covered", "revealed":"float_latch_revealed", "latched":"float_latch_latched"}),
		fixture("boiler", points.boiler, "empty", {"empty":"boiler_empty", "open":"boiler_cover_open", "liquid":"boiler_covered", "gas":"boiler_cooled"}, 2.5),
		fixture("turbine", points.turbine, "idle", {"idle":"model_turbine_idle", "latched":"model_turbine_latched"}),
		fixture("crate", points.crate, "solid", {"solid":"equipment_crate_frozen", "liquid":"equipment_crate_open"}),
		fixture("support", points.support, "empty", {"empty":"support_tray_empty", "liquid":"support_tray_liquid", "solid":"support_tray_solid", "latched":"support_tray_latched"}),
		fixture("plank", points.plank, "ready", {"ready":"landing_plank"}),
		fixture("landing", points.landing, "damaged", {"damaged":"landing_damaged", "repaired":"landing_repaired"}, 2.5),
	]
	fixtures[9].components[0].item_id = PLANK
	var actions := {
		"open_canopy":control("canopy", "Open canopy", "open"),
		"open_shutter":control("shutter", "Open solar shutter", "open", [phase("canopy", "open")]),
		"fill_tray":control("tray", "Fill shallow Sunny Tray", "liquid", [phase("tray", "empty")]),
		"set_float":control("float", "Secure uncovered float latch", "latched", [phase("tray", "gas")]),
		"fill_boiler":control("boiler", "Fill comparison chamber", "open", [phase("boiler", "empty"), phase("float", "latched")]),
		"close_cover":control("boiler", "Close guard · keep vent open", "liquid", [phase("boiler", "open")]),
		"set_turbine":control("turbine", "Set model wheel latch", "latched", [phase("boiler", "gas")]),
		"fill_support":control("support", "Fill support tray", "liquid", [phase("support", "empty"), phase("crate", "liquid")]),
		"lock_support":control("support", "Secure frozen support", "latched", [phase("support", "solid")]),
		"take_plank":{"component":"plank/control", "kind":"pickup", "item":PLANK, "caption":"Pick up landing plank",
			"requires":[phase("support", "latched")]},
		"repair":{"component":"landing/control", "kind":"place", "item":PLANK, "caption":"Fit plank to landing",
			"events":[{"id":"hands_on", "members":[]}]},
	}
	for angle in range(3):
		actions["aim_reflector_%d" % angle] = control("reflector", "Turn reflector", str(angle + 1),
			[phase("reflector", str(angle)), phase("shutter", "open")])
	var targets := {
		"sunny_tray_evaporation":transition("tray", "evaporation",
			{"filled":["tray","liquid"], "exposed":["canopy","open"], "shutter":["shutter","open"], "reflected":["reflector","3"]}, 4.0),
		"sunlit_chamber_boiling":transition("boiler", "boiling",
			{"guarded":["boiler","liquid"], "comparison":["float","latched"]}, 5.0),
		"sunlit_crate_melting":transition("crate", "melting",
			{"frozen":["crate","solid"], "recall":["turbine","latched"]}, 3.0),
		"sunlit_support_freezing":transition("support", "freezing", {"filled":["support","liquid"]}, 3.0),
	}
	return {
		"subregion":"Z2L1", "assemblies":fixtures, "actions":actions, "targets":targets,
		"items":{PLANK:{"initial_owner":"world:plank/control", "source":"plank/control"}},
		"introductions":[MILESTONE], "guide_topics":["vaporization", "melting", "freezing"],
	}
