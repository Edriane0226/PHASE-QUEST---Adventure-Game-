extends "res://Scripts/World/Zone3/vanishing_ice_assembly.gd"

const FROSTPRINT := "Z3L3"
const INTRO := "z3l3_deposition"
const FIRST := "frostprint_first_frost"
const DEW := "frostprint_dew"
const COMPARE := "frostprint_comparison_frost"
const OPTICAL := "frostprint_optical_frost"
const PROCESSES := {FIRST:"deposition", DEW:"condensation", COMPARE:"deposition", OPTICAL:"deposition"}
const PANE_C := 8
const DEW_POINT_C := 12
const TARGET_MARK := 3
const FROST_ART := {"empty":"deposition_empty","gas":"deposition_supplied_vapor","solid":"deposition_target"}

static func frostprint_target(id: String, part_id: String, seconds: float, gates: Dictionary) -> Dictionary:
	var process: String = PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	var flags := {}
	for key in gates:
		flags[key] = CONTROL.phase(gates[key][0],gates[key][1])
	var key := part_id+"/control"
	return {"component":key,"occlusion_component":key,"flags":flags,
		"spec":{"zone":ZONE,"level":3,"material":"water","process":process,
			"allowed_modes":["cryo"] if id == DEW else rule.modes,"required_exposure":seconds,
			"max_range":105.0,"required_flags":flags.keys()},
		"sample":{"material":"water","phase_region":rule.region,"heat_flow":rule.heat}}

static func frostprint_definition(points: Dictionary) -> Dictionary:
	var conditions := {"sealed":["cover","sealed"],"regulated":["gauge","regulated"],"heat_sink":["sink","on"]}
	var first := frostprint_target(FIRST,"first",3.0,conditions)
	first.milestone = INTRO
	first.spec.introductory_milestone = INTRO
	var optical_art := FROST_ART.duplicate()
	optical_art.isolated = "deposition_isolated"
	return {"subregion":FROSTPRINT,"assemblies":[
		piece("cover",points,"open",{"open":"lab_valve_open","sealed":"lab_valve_isolated"},1.25),
		piece("gauge",points,"normal",{"normal":"condition_gauge_normal","regulated":"condition_gauge_regulated"},1.25),
		piece("sink",points,"off",{"off":"heat_exchanger_off","on":"heat_exchanger_heat_out"},1.25),
		piece("first",points,"empty",FROST_ART,2.5,2,Vector2(39,22)),
		piece("first_sensor",points,"empty",{"empty":"phase_sensor_solid_empty","solid":"phase_sensor_solid_detected"},1.25),
		piece("dry_sensor",points,"empty",{"empty":"phase_sensor_liquid_empty"},1.25),
		piece("dew",points,"empty",{"empty":"dew_comparison_warm","gas":"dew_comparison_cooled","liquid":"dew_comparison_droplets"},2.5,2,Vector2(27,14)),
		piece("frost",points,"empty",FROST_ART,2.5,2,Vector2(27,14)),
		piece("compare",points,"idle",{"idle":"worktop_clear","fed":"path_card_deposition_unobserved",
			"retry":"path_card_deposition_unobserved","accepted":"path_card_deposition_observed"},1.5),
		piece("optical",points,"empty",optical_art,2.5,2,Vector2(27,14)),
		piece("optical_sensor",points,"below",{"below":"optical_sensor_below","target":"optical_sensor_at_target"},1.25,1,Vector2(12,7)),
		piece("inlet",points,"closed",{"closed":"lab_valve_closed","open":"lab_valve_open","isolated":"lab_valve_isolated"},1.5,1,Vector2(33,16)),
		piece("exit",points,"locked",{"locked":"worktop_clear","recorded":"worktop_sample"},2,1,Vector2(17,9)),
	],"items":{},"actions":{
		"seal":CONTROL.control("cover","Seal the frost collectors","sealed",[]),
		"supply":CONTROL.control("first","Feed water vapor","gas",[CONTROL.phase("first","empty"),CONTROL.phase("cover","sealed")]),
		"regulate":CONTROL.control("gauge","Set regulated pressure","regulated",[CONTROL.phase("first","gas")]),
		"cool":CONTROL.control("sink","Start heat removal","on",[CONTROL.phase("gauge","regulated")]),
		"split":CONTROL.control("compare","Feed separate dew and frost lines","fed",[CONTROL.phase("first","solid"),CONTROL.phase("dew","empty")]),
		"compare":CONTROL.control("compare","Compare liquid dew and solid frost","accepted",[CONTROL.phase("dew","liquid"),CONTROL.phase("frost","solid")]),
		"feed":CONTROL.control("inlet","Open optical vapor inlet","open",[CONTROL.phase("compare","accepted"),CONTROL.phase("inlet","closed")]),
		"stop":CONTROL.control("inlet","Close optical vapor inlet","isolated",[CONTROL.phase("optical_sensor","target"),CONTROL.phase("inlet","open")]),
		"exit":CONTROL.control("exit","Record Frostprint result","recorded",[CONTROL.phase("inlet","isolated")]),
	},"targets":{
		FIRST:first,
		DEW:frostprint_target(DEW,"dew",2.5,{}),
		COMPARE:frostprint_target(COMPARE,"frost",3.0,conditions),
		OPTICAL:frostprint_target(OPTICAL,"optical",4.0,conditions.merged({"inlet":["inlet","open"]})),
	},"introductions":[INTRO]}
