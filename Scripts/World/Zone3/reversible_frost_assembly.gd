extends "res://Scripts/World/Zone3/vanishing_ice_assembly.gd"

const CIRCUIT := "Z3L4"
const SOURCE := "reversible_source_ice"
const FIRST := "reversible_collector_a_deposit"
const RETURN := "reversible_collector_a_resublime"
const FINAL := "reversible_collector_b_deposit"
const PROCESSES := {SOURCE:"sublimation", FIRST:"deposition", RETURN:"sublimation", FINAL:"deposition"}
const TARGET_BENCH := {SOURCE:"source", FIRST:"a", RETURN:"a", FINAL:"b"}
const RECEIPT_ORDER := [SOURCE,FIRST,RETURN,FINAL]
const CONDITIONS := {"standby":["normal","none"],"sublime":["low","in"],"deposit":["high","out"]}
const GAUGE_ART := {"standby":"condition_gauge_normal","sublime":"condition_gauge_low","deposit":"condition_gauge_regulated"}
const HEAT_ART := {"standby":"heat_exchanger_off","sublime":"heat_exchanger_heat_in","deposit":"heat_exchanger_heat_out"}
const CLOSED_LINE := {"open":"lab_valve_open","sealed":"lab_valve_isolated","sent":"lab_valve_closed"}
enum Step {SOURCE_ICE, SOURCE_GAS, A_GAS, A_FROST, A_ISOLATED, A_RETURN_GAS, B_GAS, B_FROST, ONLINE}
const TARGET_STEPS := {SOURCE:Step.SOURCE_ICE, FIRST:Step.A_GAS, RETURN:Step.A_ISOLATED, FINAL:Step.B_GAS}

static func circuit_target(id: String) -> Dictionary:
	var key: String = TARGET_BENCH[id]+"/control"
	var process: String = PROCESSES[id]
	return {"component":key,"occlusion_component":key,"spec":{
		"zone":ZONE,"level":4,"material":"water","process":process,
		"allowed_modes":RULES.PROCESSES[process].modes,"required_exposure":3.0,
		"max_range":105.0,"required_flags":[],
	},"sample":{"material":"water"}}

static func circuit_definition(points: Dictionary) -> Dictionary:
	var assemblies := [
		piece("source",points,"solid",{"solid":"sublimation_solid","gas":"sublimation_captured_gas","empty":"sample_slot_clear"},2.25,2,Vector2(27,14)),
		piece("a",points,"empty",{"empty":"deposition_empty","gas":"deposition_supplied_vapor","solid":"deposition_target",
			"isolated":"frost_removal_0","return_gas":"sublimation_captured_gas","cleared":"frost_removal_3"},2.25,2,Vector2(27,14)),
		piece("b",points,"empty",{"empty":"receiver_b_empty","gas":"deposition_supplied_vapor","solid":"receiver_b_target"},2.25,2,Vector2(27,14)),
		piece("source_valve",points,"open",CLOSED_LINE,1.25),
		piece("a_valve",points,"closed",{"closed":"lab_valve_closed","inlet":"lab_valve_open",
			"isolated":"lab_valve_isolated","sent":"lab_valve_closed"},1.25),
		piece("b_valve",points,"closed",{"closed":"lab_valve_closed","sealed":"lab_valve_isolated"},1.25),
		piece("source_sensor",points,"empty",{"empty":"phase_sensor_gas_empty","gas":"phase_sensor_gas_detected"},1.25),
		piece("a_sensor",points,"below",{"below":"optical_sensor_below","target":"optical_sensor_at_target","clear":"optical_sensor_cleared"},1.25),
		piece("b_sensor",points,"below",{"below":"optical_sensor_below","target":"optical_sensor_at_target"},1.25),
		piece("exit",points,"offline",{"offline":"reversible_circuit_disconnected","ready":"reversible_circuit_target_b",
			"online":"reversible_circuit_complete"},2.25,2,Vector2(23,11)),
	]
	var actions := {
		"source_valve":CONTROL.control("source_valve","Set source valve","panel",[]),
		"a_valve":CONTROL.control("a_valve","Set collector A valve","panel",[]),
		"question":CONTROL.control("a_sensor","Review the vapor transfer","panel",[]),
		"exit":CONTROL.control("exit","Bring the circuit online","online",[]),
	}
	for bench in ["source","a","b"]:
		var gauge: String = bench+"_gauge"
		assemblies.append(piece(gauge,points,"standby",GAUGE_ART,1.25))
		assemblies.append(piece(bench+"_heat",points,"standby",HEAT_ART,1.25))
		actions[gauge] = CONTROL.control(gauge,"Set pressure and heat","panel",[])
	var targets := {}
	for id in RECEIPT_ORDER:
		targets[id] = circuit_target(id)
	return {"subregion":CIRCUIT,"assemblies":assemblies,"items":{},"actions":actions,"targets":targets}
