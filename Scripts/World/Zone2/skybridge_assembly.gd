extends RefCounted
## Five unique recipe parts, fixed working-water feed and a separate coolant loop.
const STEAMWORKS = preload("res://Scripts/World/Zone2/steamworks_assembly.gd")
const KIT = STEAMWORKS.KIT
const REGION := "Z2L6"
const CONNECTION := "Z2L6--Z3L1"
const INLET := "skybridge_feedwater"
const PACK := "skybridge_cooling_pack"
const BOILER := "skybridge_boiler"
const CONDENSER := "skybridge_condenser"
const MEASURES := 2
const RECIPE := {
	"boiler_shell":"Boiler shell",
	"turbine_cartridge":"Turbine cartridge",
	"condenser_coil":"Condenser coil",
	"return_tank":"Return tank",
	"drive_belt":"Drive belt",
}
const FITTINGS := {
	"boiler_shell":"boiler", "turbine_cartridge":"turbine", "condenser_coil":"condenser",
	"return_tank":"tank", "drive_belt":"drive",
}
const QUESTIONS := [
	{"id":"feedwater", "prompt":"What did Thermal do to the solid feedwater?",
		"choices":["Removed heat and froze it.", "Added heat and melted it.", "Changed it into fuel."], "correct":1,
		"feedback":["Freezing removes heat from liquid. This ice gained heat.",
			"Yes. Solid water gained heat and became liquid water.",
			"The ice stayed water. It changed from solid to liquid."]},
	{"id":"pack", "prompt":"What happened to the water inside the separate cooling pack?",
		"choices":["Cryo removed heat and the liquid froze.", "Cryo added heat and the water boiled.", "The pack filled with droplets from the exhaust."], "correct":0,
		"feedback":["Yes. Removing heat changed the pack's liquid water to solid ice.",
			"Cryo removed heat. Adding heat would warm the water.",
			"The pack already contained its own water. Exhaust droplets form in the condenser."]},
	{"id":"wheel", "prompt":"What turned the wheel in the test?",
		"choices":["The return tank's liquid.", "Cold from the cooling pack.", "Vapor from the externally heated boiler."], "correct":2,
		"feedback":["The tank received liquid after the wheel turned. The boiler supplied vapor to the wheel.",
			"The cooling loop removes heat downstream. Boiler vapor drove the wheel.",
			"Yes. Heat boiled the water, and the flowing vapor did work on the turbine."]},
	{"id":"return", "prompt":"Why does the returned water need fresh heat before another test?",
		"choices":["The condenser removed heat and returned liquid. The boiler needs heat to make vapor again.",
			"The condenser added heat and made more vapor.", "The return tank makes fuel every time it fills."], "correct":0,
		"feedback":["Yes. Exhaust lost heat and condensed. Reusing the water still requires external heat and cooling.",
			"The condenser removed heat. The droplets show that vapor became liquid.",
			"The tank collects water. A new batch still needs external heat at the boiler."]},
]

static func source(id: String) -> String:
	return "world:" + id + "/control"

static func staged(id: String) -> String:
	return "installed:rack_" + id + "/control"

static func fitted(id: String) -> String:
	return "installed:" + FITTINGS[id] + "/control"

static func transition(part: String, process: String, gates: Dictionary, seconds: float, amount: int) -> Dictionary:
	var binding := STEAMWORKS.target(part, process, gates, seconds, amount)
	binding.spec.level = 6
	return binding

static func definition(points: Dictionary) -> Dictionary:
	var result := {
		"subregion":REGION,
		"assemblies":[
			STEAMWORKS.part("inlet", points, "solid", {"solid":"stream_inlet_frozen", "liquid":"stream_inlet_thawed", "fed":"stream_inlet_flowing"}, 2, Vector2(23,12)),
			STEAMWORKS.part("pack", points, "liquid", {"liquid":"cooling_pack_liquid", "solid":"cooling_pack_solid", "spent":"cooling_pack_liquid"}, 2, Vector2(16,9)),
			STEAMWORKS.part("recipe", points, "empty", {"empty":"engine_blueprint"}, 1.5),
			STEAMWORKS.part("boiler", points, "unfitted", {"unfitted":"engine_socket_boiler_shell_empty", "empty":"boiler_empty",
				"filled":"boiler_cover_open", "liquid":"boiler_covered", "gas":"boiler_boil_a", "spent":"boiler_cooled"}, 2.5, Vector2(28,15), 3),
			STEAMWORKS.part("turbine", points, "unfitted", {"unfitted":"engine_socket_turbine_cartridge_empty",
				"idle":"model_turbine_idle", "turned":"model_turbine_latched"}, 2.5, Vector2(26,13), 2),
			STEAMWORKS.part("drive", points, "unfitted", {"unfitted":"engine_socket_drive_belt_empty", "fitted":"drive_belt_fitted"}, 1.5),
			STEAMWORKS.part("condenser", points, "unfitted", {"unfitted":"engine_socket_condenser_coil_empty", "empty":"return_collector_warm",
				"gas":"return_collector_cooled", "liquid":"return_collector_droplets", "drained":"return_collector_returning"}, 2.5, Vector2(24,12), 2),
			STEAMWORKS.part("tank", points, "unfitted", {"unfitted":"engine_socket_return_tank_empty",
				"empty":"return_reservoir_empty", "returned":"return_reservoir_full"}, 2.5, Vector2(22,11), 2),
		],
		"items":{},
		"actions":{
			"feed":KIT.control("boiler", "Connect feedwater and cooling loop", "filled",
				[KIT.phase("boiler","empty"), KIT.phase("inlet","liquid"), KIT.phase("pack","solid")]),
			"guard":KIT.control("boiler", "Close guard · keep vent open", "liquid", [KIT.phase("boiler","filled")]),
			"wheel":KIT.control("turbine", "Send vapor through the wheel", "turned",
				[KIT.phase("boiler","gas"), KIT.phase("turbine","idle")]),
			"exhaust":KIT.control("condenser", "Route exhaust to the condenser", "gas",
				[KIT.phase("turbine","turned"), KIT.phase("condenser","empty")]),
			"drain":KIT.control("tank", "Return droplets to the tank", "returned",
				[KIT.phase("condenser","liquid"), KIT.phase("tank","empty")]),
		},
		"targets":{
			INLET:transition("inlet", "melting", {"ice":["inlet","solid"]}, 2.5, MEASURES),
			PACK:transition("pack", "freezing", {"filled":["pack","liquid"]}, 2.5, 1),
			BOILER:transition("boiler", "boiling", {"guard":["boiler","liquid"], "coolant":["pack","solid"]}, 4.0, MEASURES),
			CONDENSER:transition("condenser", "condensation", {"exhaust":["condenser","gas"], "coolant":["pack","solid"]}, 2.5, MEASURES),
		},
		"completion_events":[{"id":"sun_scholar", "event":"lift_departure", "members":[]}],
	}
	for id in RECIPE:
		var art: String = "engine_part_" + id
		var cargo := STEAMWORKS.part(id, points, "ready", {"ready":art}, 1)
		cargo.components[0].item_id = id
		var rack: String = "rack_" + id
		result.assemblies.append(cargo)
		result.assemblies.append(STEAMWORKS.part(rack, points, "empty", {"empty":"engine_socket_" + id + "_empty"}, 1.5))
		result.items[id] = {"source":id+"/control", "initial_owner":source(id)}
		result.actions["take_"+id] = {"component":id+"/control", "kind":"pickup", "item":id, "caption":"Lift " + RECIPE[id].to_lower()}
		result.actions["stow_"+id] = {"component":rack+"/control", "kind":"place", "item":id, "caption":"Stow " + RECIPE[id].to_lower()}
		result.actions["return_"+id] = {"component":id+"/control", "kind":"place", "item":id, "caption":"Set " + RECIPE[id].to_lower() + " back"}
	return result
