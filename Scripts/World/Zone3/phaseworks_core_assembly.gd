extends "res://Scripts/World/Zone3/vanishing_ice_assembly.gd"

const STEAMWORKS = preload("res://Scripts/World/Zone2/steamworks_assembly.gd")
const CORE := "Z3L6"
const RECIPE := {"housing":"Cartridge housing","collector_plate":"Cooled collector plate","vapor_tube":"Vapor tube",
	"calibrated_sensor":"Calibrated sensor","water_ice_sample":"Water-ice sample"}
const FITTED := "installed:recipe/control"
const BENCHES := {
	"inlet":"melting","jig":"freezing","seal":"evaporation","boiler":"boiling","condenser":"condensation",
	"port":"sublimation","source":"sublimation","collector":"deposition","scanner":"sublimation",
}
const QUESTIONS := [
	{"id":"melting","prompt":"What happened to the supply ice when the jig received liquid?",
		"choices":["Liquid became solid as it cooled.","Solid became liquid as heat entered.","Solid became gas as heat entered."],"correct":1,
		"feedback":["Cooling liquid into solid is freezing. Here we started with ice and collected liquid.","Heat entered the solid water and it melted to liquid. The substance stayed water.","Sublimation would give vapor directly. The supply gave liquid."]},
	{"id":"freezing","prompt":"How did the water hold the housing jig?",
		"choices":["Liquid lost heat and became solid.","Gas lost heat and became solid.","Solid gained heat until it hardened."],"correct":0,
		"feedback":["The jig removed heat from liquid water. Solid ice held the parts in the jig.","Gas going directly to solid is deposition. The jig started with liquid.","The jig cooled liquid water. Adding heat to that ice would melt it."]},
	{"id":"vaporization","prompt":"How did the label seal dry differently from the boiler?",
		"choices":["Both made bubbles throughout the liquid.","Only the boiler made water vapor.","The seal lost water at its surface. Boiling made vapor throughout the liquid."],"correct":2,
		"feedback":["Bulk bubbles mark boiling. The seal dried by surface evaporation.","Both routes made water vapor. The wet seal evaporated at its surface.","Evaporation takes place at the liquid surface. Boiling makes vapor throughout the liquid. Both require energy."]},
	{"id":"condensation","prompt":"What happened when boiler exhaust met the above-freezing cooled collector?",
		"choices":["Gas lost heat and formed liquid.","Liquid gained heat and formed gas.","Gas lost heat and formed solid ice."],"correct":0,
		"feedback":["The cooled collector removed heat. Water vapor condensed into liquid above freezing.","Adding heat to liquid can produce vapor. This collector cooled vapor into liquid.","Solid directly from gas is deposition. This collector was above freezing and produced liquid."]},
	{"id":"sublimation","prompt":"What did the sealed source do before vapor entered the cartridge?",
		"choices":["It melted ice and transferred liquid.","It supplied heat at low pressure so ice became gas directly.","It compressed gas and collected frost."],"correct":1,
		"feedback":["The source liquid reading stayed at zero. The transfer line carried vapor.","Heat entered the ice at suitable low pressure. Gas formed directly from solid, with no liquid stage.","That describes the opposite direction. This source captured gas from ice."]},
	{"id":"deposition","prompt":"How did solid frost grow on the cartridge collector?",
		"choices":["Vapor made droplets that froze.","Pressure alone turned any gas solid.","Heat left supplied vapor at the regulated cold collector. Solid ice formed directly."],"correct":2,
		"feedback":["Droplets freezing would be two changes. This collector’s liquid reading stayed at zero.","The cartridge needed suitable water vapor and a sealed collector that removed heat.","The regulated cold collector removed heat from water vapor. Frost formed directly with no intermediate liquid."]},
]

static func origin(id: String) -> String:
	return "world:"+id+"/control"

static func staged(id: String) -> String:
	return "installed:rack_"+id+"/control"

static func target_id(bench: String) -> String:
	return "phaseworks_"+bench

static func apparatus_target(bench: String) -> Dictionary:
	var key := bench+"/control"
	var process: String = BENCHES[bench]
	var rule: Dictionary = RULES.PROCESSES[process]
	return {"component":key,"occlusion_component":key,"spec":{
		"zone":ZONE,"level":6,"material":"water","process":process,"required_exposure":3.0,
		"allowed_modes":["cryo"] if process == "condensation" else rule.modes,
		"max_range":105.0,"required_flags":[],
	},"sample":{"material":"water","phase_region":rule.region,"heat_flow":rule.heat}}

static func core_definition(points: Dictionary) -> Dictionary:
	var gauge := {"off":"heat_exchanger_off","low":"heat_exchanger_heat_in","cold":"heat_exchanger_heat_out"}
	var assemblies := [
		piece("inlet",points,"solid",{"solid":"normal_warmer_solid","liquid":"normal_warmer_liquid","fed":"exhibit_melting_observed"},2.25,2,Vector2(25,13)),
		piece("jig",points,"empty",{"empty":"exhibit_freezing_ready","liquid":"assembly_jig_liquid","solid":"assembly_jig_solid"},2.25,2,Vector2(25,13)),
		piece("seal",points,"folded",{"folded":"utility_seal_wet","liquid":"utility_seal_wet","gas":"utility_seal_dry"},1.5,1,Vector2(16,9)),
		piece("boiler",points,"unguarded",{"unguarded":"utility_boiler_filled","liquid":"utility_boiler_warm",
			"gas":"utility_boiler_boil_a","spent":"utility_boiler_cooled"},2.25,2,Vector2(25,13)),
		piece("condenser",points,"empty",{"empty":"recovery_condenser_warm","gas":"recovery_condenser_cooled",
			"liquid":"recovery_condenser_droplets"},2.25,2,Vector2(25,13)),
		STEAMWORKS.part("wheel",points,"idle",{"idle":"model_turbine_idle","driven":"model_turbine_latched"},1.25),
		piece("port",points,"solid",{"solid":"delivery_port_frozen","gas":"delivery_port_open"},2.25,2,Vector2(25,13)),
		piece("port_control",points,"off",gauge,1.25),
		piece("recipe",points,"open",{"open":"cartridge_blueprint","fitted":"cartridge_sealed"},1.5),
		piece("source",points,"empty",{"empty":"cartridge_empty","solid":"cartridge_source_solid",
			"gas":"cartridge_vapor_captured","sent":"sample_slot_clear"},2.25,2,Vector2(25,13)),
		piece("collector",points,"empty",{"empty":"deposition_empty","gas":"deposition_supplied_vapor",
			"solid":"cartridge_verified","sent":"cartridge_empty"},2.25,2,Vector2(25,13)),
		piece("source_control",points,"off",gauge,1.25),
		piece("collector_control",points,"off",gauge,1.25),
		piece("scanner",points,"empty",{"empty":"exit_scanner_empty","arrived":"cartridge_verified",
			"solid":"exit_scanner_inserted","gas":"exit_scanner_absence_signal"},2.25,2,Vector2(25,13)),
		piece("scanner_control",points,"off",gauge,1.25),
		piece("exit",points,"closed",{"closed":"final_exit_locked","open":"final_exit_allowed"},2.25,2,Vector2(22,12)),
	]
	var actions := {
		"fill":CONTROL.control("jig","Fill jig with meltwater","liquid",[CONTROL.phase("inlet","liquid")]),
		"spread":CONTROL.control("seal","Spread the damp label seal","liquid",[CONTROL.phase("seal","folded")]),
		"guard":CONTROL.control("boiler","Fit dry seal and close boiler guard","liquid",[CONTROL.phase("seal","gas"),CONTROL.phase("boiler","unguarded")]),
		"drive":CONTROL.control("wheel","Drive wheel and route exhaust","driven",[CONTROL.phase("boiler","gas")]),
		"port_setup":CONTROL.control("port_control","Seal port · low pressure and heat in","low",[CONTROL.phase("port","solid")]),
		"recipe":CONTROL.control("recipe","Inspect frost-cartridge recipe","panel",[]),
		"source_setup":CONTROL.control("source_control","Seal source · low pressure and heat in","low",[CONTROL.phase("source","solid")]),
		"route":CONTROL.control("collector","Send captured vapor to collector","gas",[CONTROL.phase("source","gas")]),
		"collector_setup":CONTROL.control("collector_control","Regulate collector · heat out","cold",[CONTROL.phase("collector","gas")]),
		"send":CONTROL.control("collector","Send tested cartridge to scanner","sent",[CONTROL.phase("collector","solid")]),
		"insert":CONTROL.control("scanner","Insert tested cartridge","solid",[CONTROL.phase("scanner","arrived")]),
		"power":CONTROL.control("scanner_control","Power sealed scanner · heat in","low",[CONTROL.phase("scanner","solid")]),
		"exit":CONTROL.control("exit","Record campaign completion","open",[CONTROL.phase("scanner","gas")]),
	}
	var items := {}
	for id in RECIPE:
		var cargo := piece(id,points,"ready",{"ready":"cartridge_part_"+id},1)
		cargo.components[0].item_id = id
		var rack: String = "rack_"+id
		assemblies.append(cargo)
		assemblies.append(piece(rack,points,"empty",{"empty":"cartridge_slot_"+id+"_empty",
			"seated":"cartridge_slot_"+id+"_committed"},1.25))
		items[id] = {"source":id+"/control","initial_owner":origin(id)}
		actions["take_"+id] = {"component":id+"/control","kind":"pickup","item":id,"caption":"Lift "+RECIPE[id].to_lower()}
		actions["return_"+id] = {"component":id+"/control","kind":"place","item":id,"caption":"Return "+RECIPE[id].to_lower()}
		actions["seat_"+id] = {"component":rack+"/control","kind":"place","item":id,"caption":"Use "+RECIPE[id].to_lower()+" slot"}
	var targets := {}
	for bench in BENCHES:
		targets[target_id(bench)] = apparatus_target(bench)
	return {"subregion":CORE,"assemblies":assemblies,"actions":actions,"targets":targets,"items":items,
"completion_events":[{"id":"lab_scholar","event":"scanner_completion","members":[]}]}
