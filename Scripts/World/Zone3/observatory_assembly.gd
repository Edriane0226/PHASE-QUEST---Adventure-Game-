extends "res://Scripts/World/Zone3/vanishing_ice_assembly.gd"

const STEAMWORKS = preload("res://Scripts/World/Zone2/steamworks_assembly.gd")
const CIRCUIT = preload("res://Scripts/World/Zone3/reversible_frost_assembly.gd")
const OBSERVATORY := "Z3L5"
const PLATE := "observatory_calibration_plate"
const CRADLE := "world:plate/control"
const DOCKED := "installed:dock/control"
const PANE_C := 8
const GROUPS := {
	"solid_liquid":["melting","freezing"],
	"liquid_gas":["evaporation","boiling","condensation"],
	"solid_gas":["sublimation","deposition"],
}
const VESSELS := {
	"melting":"melt","freezing":"freeze","evaporation":"evap","boiling":"boil",
	"condensation":"condense","sublimation":"sublime","deposition":"deposit",
}
const FINISHED_PHASES := {
	"melting":["liquid","drained"],"freezing":["solid","released"],"evaporation":["gas"],
	"boiling":["gas","spent"],"condensation":["liquid"],"sublimation":["gas","routed"],"deposition":["solid"],
}
const PROGRESS_ART := {
	"melting":["normal_warmer_melting_early","normal_warmer_melting_late"],
	"evaporation":["utility_seal_drying","utility_seal_drying"],
	"boiling":["utility_boiler_boil_a","utility_boiler_boil_b"],
	"sublimation":["sublimation_shrinking_early","sublimation_shrinking_late"],
	"deposition":["deposition_early_frost","deposition_growing"],
}

static func target_id(process: String) -> String:
	return "observatory_"+process

static func exhibit_target(process: String) -> Dictionary:
	var key: String = VESSELS[process]+"/control"
	var rule: Dictionary = RULES.PROCESSES[process]
	return {"component":key,"occlusion_component":key,"spec":{
		"zone":ZONE,"level":5,"material":"water","process":process,
		"allowed_modes":["cryo"] if process == "condensation" else rule.modes,
		"required_exposure":3.0,"max_range":105.0,"required_flags":[],
	},"sample":{"material":"water","phase_region":rule.region,"heat_flow":rule.heat}}

static func observatory_definition(points: Dictionary) -> Dictionary:
	var plate := piece("plate",points,"ready",{"ready":"cartridge_part_collector_plate"},1.25)
	plate.components[0].item_id = PLATE
	var assemblies := [
		piece("melt",points,"solid",{"solid":"normal_warmer_solid","liquid":"normal_warmer_liquid","drained":"exhibit_melting_observed"},2.25,2,Vector2(25,13)),
		piece("freeze",points,"empty",{"empty":"exhibit_freezing_ready","liquid":"assembly_jig_liquid",
			"solid":"exhibit_freezing_observed","released":"assembly_jig_liquid"},2.25,2,Vector2(25,13)),
		piece("heater",points,"off",{"off":"heat_exchanger_off","used":"heat_exchanger_heat_in"},1.25),
		plate,
		piece("dock",points,"empty",{"empty":"cartridge_slot_collector_plate_empty"},1.5),
		piece("evap",points,"folded",{"folded":"exhibit_evaporation_ready","liquid":"utility_seal_wet","gas":"utility_seal_dry"},2.25,2,Vector2(22,12)),
		piece("boil",points,"unguarded",{"unguarded":"exhibit_boiling_ready","liquid":"utility_boiler_filled",
			"gas":"utility_boiler_boil_a","spent":"utility_boiler_cooled"},2.25,2,Vector2(25,13)),
		piece("condense",points,"empty",{"empty":"recovery_condenser_warm","gas":"recovery_condenser_cooled",
			"liquid":"recovery_condenser_droplets"},2.25,2,Vector2(25,13)),
		STEAMWORKS.part("wheel",points,"idle",{"idle":"model_turbine_idle","driven":"model_turbine_latched",
			"spin_a":"model_turbine_turn_a","spin_b":"model_turbine_turn_b"},1.25),
		piece("sublime",points,"solid",{"solid":"sublimation_solid","gas":"sublimation_captured_gas",
			"routed":"sample_slot_clear"},2.25,2,Vector2(25,13)),
		piece("deposit",points,"empty",{"empty":"deposition_empty","gas":"deposition_supplied_vapor",
			"solid":"deposition_target"},2.25,2,Vector2(25,13)),
		piece("sublime_setup",points,"standby",CIRCUIT.GAUGE_ART,1.25),
		piece("deposit_setup",points,"standby",CIRCUIT.GAUGE_ART,1.25),
		piece("blueprint",points,"locked",{"locked":"worktop_clear","recorded":"cartridge_blueprint"},1.5),
		piece("exit",points,"waiting",{"waiting":"worktop_clear","recorded":"worktop_sample"},2.25,2,Vector2(21,12)),
	]
	var actions := {
		"fill":CONTROL.control("freeze","Fill tray from meltwater","liquid",[CONTROL.phase("freeze","empty"),CONTROL.phase("melt","liquid")]),
		"release":CONTROL.control("heater","Run the jig heater","used",[CONTROL.phase("freeze","solid")]),
		"take":{"component":"plate/control","kind":"pickup","item":PLATE,"caption":"Pick up calibration plate","requires":[CONTROL.phase("freeze","released")]},
		"dock":{"component":"dock/control","kind":"place","item":PLATE,"caption":"Seat calibration plate"},
		"spread":CONTROL.control("evap","Spread the damp label cloth","liquid",[CONTROL.phase("evap","folded")]),
		"guard":CONTROL.control("boil","Close boiler guard","liquid",[CONTROL.phase("boil","unguarded")]),
		"wheel":CONTROL.control("wheel","Drive wheel and route exhaust","driven",[CONTROL.phase("boil","gas")]),
		"sublime_setup":CONTROL.control("sublime_setup","Set source conditions","panel",[]),
		"deposit_setup":CONTROL.control("deposit_setup","Set collector conditions","panel",[]),
		"route":CONTROL.control("deposit","Route captured vapor to collector","gas",[CONTROL.phase("deposit","empty"),CONTROL.phase("sublime","gas")]),
		"blueprint":CONTROL.control("blueprint","Record frost-cartridge blueprint","recorded",[]),
		"exit":CONTROL.control("exit","Record Observatory completion","recorded",[CONTROL.phase("blueprint","recorded")]),
	}
	for group in GROUPS:
		var prefix: String = "exhibit_sign_"+group
		assemblies.append(piece(group,points,"locked",{"locked":prefix+"_locked","ready":prefix+"_ready","complete":prefix+"_complete"},1.25))
		actions[group] = CONTROL.control(group,"Review state and heat","panel",[])
	var targets := {}
	for process in VESSELS:
		targets[target_id(process)] = exhibit_target(process)
	return {"subregion":OBSERVATORY,"assemblies":assemblies,"targets":targets,"actions":actions,
		"items":{PLATE:{"source":"plate/control","initial_owner":CRADLE}}}
