extends "res://Scripts/World/Zone1/stillwater_assembly.gd"

const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
const CONTROL = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const CATALOG := "res://assets/zones/zone_3/world_v1/kit_catalog.json"
const REGION := "Z3L1"
const ZONE := "sublimation_and_deposition"
const MILESTONE := "z3l1_sublimation"
const OBSERVATION := "lab_observation_ice"
const PLUG := "lab_slot_ice_plug"
const SEAL := "lab_cloth_seal"
const BOILER := "lab_utility_boiler"
const CONDENSER := "lab_utility_condenser"
const MEASURES := 2
const TARGET_PROCESSES := {OBSERVATION:"sublimation", PLUG:"sublimation", SEAL:"evaporation",
	BOILER:"boiling", CONDENSER:"condensation"}
static var _art: Dictionary = {}

static func art(id: String) -> Dictionary:
	if _art.is_empty():
		for entry in JSON.parse_string(FileAccess.get_file_as_string(CATALOG)).entries:
			_art[entry.id] = {"path":entry.path,"pivot_px":entry.pivot_px,"scale":entry.world_scale}
	return _art[id]

static func piece(id: String, points: Dictionary, initial: String, images: Dictionary, cubes: float,
		height := 1, half := Vector2.ZERO) -> Dictionary:
	var visuals := {}
	for state in images:
		visuals[state] = art(images[state])
	var module := part("control",[cubes/2,cubes/2,0],cubes,{"phase":initial},visuals)
	module.height_layers = height
	if half != Vector2.ZERO:
		module.collision_bounds = [[-half.x,-half.y],[half.x,-half.y],[half.x,half.y],[-half.x,half.y]]
	var at: Vector2 = points[id]
	return {"id":id,"origin_ground":[at.x,at.y-cubes*10],"footprint_cubes":[cubes,cubes],"components":[module]}

static func target(id: String, station: String, seconds: float, amount: int, gates: Dictionary) -> Dictionary:
	var process: String = TARGET_PROCESSES[id]
	var rule: Dictionary = RULES.PROCESSES[process]
	var flags := {}
	for key in gates:
		flags[key] = CONTROL.phase(gates[key][0],gates[key][1])
	var spec := {"zone":ZONE,"level":1,"material":"water","process":process,
		"allowed_modes":["cryo"] if process == "condensation" else rule.modes,
		"required_exposure":seconds,"max_range":105.0,"required_flags":flags.keys()}
	return {"component":station+"/control","occlusion_component":station+"/control","spec":spec,
		"flags":flags,"sample":{"material":"water","amount":amount,"phase_region":rule.region,"heat_flow":rule.heat},
		"events":[{"id":"six_changes","members":[process]}]}

static func definition(points: Dictionary) -> Dictionary:
	var conditions := {"sealed":["cover","sealed"],"low_pressure":["gauge","low"],"heater":["heater","regulated"]}
	var observation := target(OBSERVATION,"observation",4.0,1,conditions)
	observation.milestone = MILESTONE
	observation.spec.introductory_milestone = MILESTONE
	observation.events.append({"id":"no_liquid_needed","members":[]})
	observation.events.append({"id":"field_notes","members":["sublimation"]})
	var plug_conditions := conditions.duplicate()
	plug_conditions["observed"] = ["observation","gas"]
	return {"subregion":REGION,"assemblies":[
		piece("cover",points,"open",{"open":"lab_valve_open","sealed":"lab_valve_isolated"},1.25),
		piece("gauge",points,"normal",{"normal":"condition_gauge_normal","low":"condition_gauge_low"},1.5,1,Vector2(11,7)),
		piece("heater",points,"off",{"off":"heat_exchanger_off","regulated":"heat_exchanger_heat_in"},1.5,1,Vector2(12,7)),
		piece("observation",points,"solid",{"solid":"sublimation_solid","gas":"sublimation_captured_gas"},2.5,2,Vector2(30,14)),
		piece("plug",points,"solid",{"solid":"sample_slot_frozen","gas":"sample_slot_clear"},2.5,2,Vector2(27,13)),
		piece("seal",points,"covered",{"covered":"utility_seal_wet","liquid":"utility_seal_wet","gas":"utility_seal_dry"},2,1,Vector2(16,9)),
		piece("boiler",points,"open",{"open":"utility_boiler_filled","liquid":"utility_boiler_warm",
			"gas":"utility_boiler_boil_a","spent":"utility_boiler_cooled"},2.5,2,Vector2(27,14)),
		piece("condenser",points,"empty",{"empty":"recovery_condenser_warm","gas":"recovery_condenser_cooled",
			"liquid":"recovery_condenser_droplets","drained":"recovery_condenser_collecting"},2.5,2,Vector2(25,13)),
		piece("tank",points,"empty",{"empty":"utility_tank_empty","full":"utility_tank_full"},2,2,Vector2(19,10)),
		piece("exit",points,"locked",{"locked":"lab_valve_closed","released":"lab_valve_open"},1.25),
	],"items":{},"actions":{
		"seal_chamber":CONTROL.control("cover","Seal observation chamber","sealed",[CONTROL.phase("cover","open")]),
		"pressure":CONTROL.control("gauge","Set low pressure","low",[CONTROL.phase("cover","sealed")]),
		"heat":CONTROL.control("heater","Enable regulated heat input","regulated",[CONTROL.phase("gauge","low")]),
		"question":CONTROL.control("observation","Check the path of the ice","question",[CONTROL.phase("observation","gas")]),
		"spread":CONTROL.control("seal","Spread damp seal for airflow","liquid",[CONTROL.phase("plug","gas"),CONTROL.phase("seal","covered")]),
		"guard":CONTROL.control("boiler","Fit dry seal and close guard","liquid",[CONTROL.phase("seal","gas"),CONTROL.phase("boiler","open")]),
		"route":CONTROL.control("boiler","Drive utility and route exhaust","spent",[CONTROL.phase("boiler","gas")]),
		"collect":CONTROL.control("tank","Drain droplets into supply tank","full",
			[CONTROL.phase("condenser","liquid"),CONTROL.phase("tank","empty")]),
		"exit":CONTROL.control("exit","Record lab access seal","released",[CONTROL.phase("tank","full")]),
	},"targets":{
		OBSERVATION:observation,
		PLUG:target(PLUG,"plug",3.0,1,plug_conditions),
		SEAL:target(SEAL,"seal",2.5,1,{"spread":["seal","liquid"]}),
		BOILER:target(BOILER,"boiler",4.0,MEASURES,{"dry_seal":["seal","gas"],"guard":["boiler","liquid"]}),
		CONDENSER:target(CONDENSER,"condenser",2.5,MEASURES,{"routed":["boiler","spent"],"exhaust":["condenser","gas"]}),
	},"introductions":[MILESTONE],"guide_topics":["sublimation"]}
