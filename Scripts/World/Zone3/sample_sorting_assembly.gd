extends "res://Scripts/World/Zone3/vanishing_ice_assembly.gd"

const SORTING := "Z3L2"
const MELT := "sorting_warmer_sample"
const SUBLIME := "sorting_chamber_sample"
const RECOVER := "sorting_recovery_condenser"
const BATCH := 2
const PANE_C := 8
const PROCESSES := {MELT:"melting", SUBLIME:"sublimation", RECOVER:"condensation"}
const RECOVERY := {"source":SUBLIME,"destination":"sorting_supply_tank","material":"water","measures":BATCH,
	"states":["solid","gas","liquid"],"pressure_regime":"normal","pane_c":PANE_C}
const OUTPUT := {"id":"calibrated_sample_tray","version":1}

static func sorting_target(id: String, part_id: String, seconds: float, gates: Dictionary) -> Dictionary:
	var rule: Dictionary = RULES.PROCESSES[PROCESSES[id]]
	var flags := {}
	for key in gates:
		flags[key] = CONTROL.phase(gates[key][0],gates[key][1])
	var key := part_id+"/control"
	return {"component":key,"occlusion_component":key,"flags":flags,
		"spec":{"zone":ZONE,"level":2,"material":"water","process":PROCESSES[id],
			"allowed_modes":["cryo"] if id == RECOVER else rule.modes,"required_exposure":seconds,
			"max_range":105.0,"required_flags":flags.keys()},
		"sample":{"material":"water","amount":BATCH,"phase_region":rule.region,"heat_flow":rule.heat}}

static func sorting_definition(points: Dictionary) -> Dictionary:
	return {"subregion":SORTING,"assemblies":[
		piece("warmer",points,"solid",{"solid":"normal_warmer_solid","liquid":"normal_warmer_liquid"},2.5,2,Vector2(27,14)),
		piece("liquid_sensor",points,"empty",{"empty":"phase_sensor_liquid_empty","detected":"phase_sensor_liquid_detected"},1.25),
		piece("melt_card",points,"empty",{"empty":"path_card_melting_unobserved","detected":"path_card_melting_observed"},1.25),
		piece("chamber",points,"solid",{"solid":"sublimation_solid","gas":"sublimation_captured_gas",
			"routed":"sample_slot_clear"},2.5,2,Vector2(27,14)),
		piece("valve",points,"open",{"open":"lab_valve_open","sealed":"lab_valve_isolated"},1.25),
		piece("condition",points,"normal",{"normal":"condition_gauge_normal","ready":"condition_gauge_low"},1.25),
		piece("gas_sensor",points,"empty",{"empty":"phase_sensor_gas_empty","detected":"phase_sensor_gas_detected"},1.25),
		piece("dry_tray",points,"empty",{"empty":"phase_sensor_liquid_empty"},1.25),
		piece("gas_card",points,"empty",{"empty":"path_card_sublimation_unobserved","detected":"path_card_sublimation_observed"},1.25),
		piece("liquid_lock",points,"closed",{"closed":"route_lock_liquid_closed","wrong":"route_lock_liquid_wrong","open":"route_lock_liquid_open"},1.5),
		piece("gas_lock",points,"closed",{"closed":"route_lock_direct_gas_closed","wrong":"route_lock_direct_gas_wrong","open":"route_lock_direct_gas_open"},1.5),
		piece("condenser",points,"empty",{"empty":"recovery_condenser_warm","gas":"recovery_condenser_cooled",
			"liquid":"recovery_condenser_droplets","drained":"recovery_condenser_collecting"},2.5,2,Vector2(25,13)),
		piece("tank",points,"empty",{"empty":"utility_tank_empty","full":"utility_tank_full"},2,2,Vector2(19,10)),
		piece("exit",points,"locked",{"locked":"worktop_clear","released":"worktop_sample"},2,1,Vector2(17,9)),
	],"items":{},"actions":{
		"seal":CONTROL.control("valve","Seal the sample chamber","sealed",[]),
		"prepare":CONTROL.control("condition","Set low pressure and regulated heat","ready",[CONTROL.phase("valve","sealed")]),
		"liquid_lock":CONTROL.control("liquid_lock","Check liquid route lock","open",[]),
		"gas_lock":CONTROL.control("gas_lock","Check direct-gas route lock","open",[]),
		"route":CONTROL.control("condenser","Send captured gas to condenser","gas",[
			CONTROL.phase("chamber","gas"),CONTROL.phase("liquid_lock","open"),CONTROL.phase("gas_lock","open")]),
		"collect":CONTROL.control("tank","Drain droplets into recovery tank","full",[CONTROL.phase("condenser","liquid")]),
		"exit":CONTROL.control("exit","Record calibrated sample tray","released",[CONTROL.phase("tank","full")]),
	},"targets":{
		MELT:sorting_target(MELT,"warmer",3.0,{}),
		SUBLIME:sorting_target(SUBLIME,"chamber",4.0,{"sealed":["valve","sealed"],"regulated":["condition","ready"]}),
		RECOVER:sorting_target(RECOVER,"condenser",2.5,{"routed":["chamber","routed"]}),
	}}
