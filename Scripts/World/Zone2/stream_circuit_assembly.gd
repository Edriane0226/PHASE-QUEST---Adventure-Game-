extends RefCounted
## Independent modules share one finite sample through the covered circuit.
const KIT = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const REGION := "Z2L4"
const INLET := "stream_iced_inlet"
const COLLECTOR := "stream_regulated_plate"
const FITTING := "stream_channel_fitting"
const BENCH := "world:fitting/control"
const INSTALLED := "installed:channel/control"
const MEASURES := 2
const WARM_C := 22
const COOL_C := 7
const DEW_C := 13

static func measurement() -> Dictionary:
	return {"version":1,"source":INLET,"material":"water","phases":["solid","liquid","gas","liquid"],
		"warm_c":WARM_C,"warm_measures":0,"cool_c":COOL_C,"dew_point_c":DEW_C,"liquid_measures":MEASURES,
		"heat_input":"sunlight","heat_removed_by":"cryo","return":"stream_measuring_tank"}

static func piece(id: String, points: Dictionary, initial: String, images: Dictionary, cubes: float, half := Vector2.ZERO) -> Dictionary:
	var result := KIT.fixture(id,points[id],initial,images,cubes)
	var at: Vector2 = points[id]
	result.origin_ground = [at.x,at.y-cubes*10]
	result.footprint_cubes = [cubes,cubes]
	var part: Dictionary = result.components[0]
	part.offset_cubes = [cubes/2,cubes/2,0]
	part.height_layers = 3 if id == "lift" else (2 if id == "plate" else 1)
	part.collision_bounds = [] if half == Vector2.ZERO else [[-half.x,-half.y],[half.x,-half.y],[half.x,half.y],[-half.x,half.y]]
	return result

static func target(part: String, process: String, prerequisites: Dictionary, seconds: float) -> Dictionary:
	var binding := KIT.transition(part,process,prerequisites,seconds)
	binding.spec.level = 4
	binding.spec.allowed_modes = ["cryo"] if process == "condensation" else ["thermal"]
	return binding

static func definition(points: Dictionary) -> Dictionary:
	var fitting := piece("fitting",points,"ready",{"ready":"channel_fitting"},1)
	fitting.components[0].item_id = FITTING
	var plate := target("plate","condensation",{"sealed":["channel","sealed"],"solar":["shutter","open"],"warm_test":["plate","gas"]},2.5)
	plate.flags.warm_test = {"component":"plate/control","field":"comparison","value":"warm_dry"}
	return {"subregion":REGION,"assemblies":[
		piece("inlet",points,"solid",{"solid":"stream_inlet_frozen","liquid":"stream_inlet_thawed","routed":"stream_inlet_flowing"},2.5,Vector2(26,12)),
		piece("basin",points,"empty",{"empty":"solar_tray_empty","liquid":"solar_tray_supplied","spent":"solar_tray_empty"},2.5),
		piece("shutter",points,"closed",{"closed":"solar_shutter_closed","open":"solar_shutter_open"},1.5),
		piece("channel",points,"gap",{"gap":"vapor_channel_gap","sealed":"vapor_channel_sealed"},2),
		fitting,
		piece("plate",points,"empty",{"empty":"return_collector_warm","gas":"return_collector_warm","liquid":"return_collector_droplets","drained":"return_collector_returning"},2.5,Vector2(25,11)),
		piece("tank",points,"empty",{"empty":"collector_tank_empty","full":"collector_tank_full","measured":"collector_tank_float_latched"},2.5),
		piece("lift",points,"lowered",{"lowered":"water_lift_lowered","raised":"water_lift_raised","locked":"water_lift_locked"},2.5),
		piece("exit",points,"closed",{"closed":"float_latch_covered","open":"float_latch_latched"},1),
	],"items":{FITTING:{"source":"fitting/control","initial_owner":BENCH}},"actions":{
		"supply":KIT.control("inlet","Route meltwater to basin","routed",[KIT.phase("inlet","liquid")]),
		"sun":KIT.control("shutter","Open solar shutter","open",[KIT.phase("basin","liquid")]),
		"lift_fitting":{"component":"fitting/control","kind":"pickup","caption":"Lift channel fitting","item":FITTING,"requires":[KIT.phase("basin","liquid")]},
		"fit":{"component":"channel/control","kind":"place","caption":"Seat channel fitting","item":FITTING},
		"seal":KIT.control("channel","Clamp covered channel","sealed"),
		"capture":KIT.control("basin","Send captured vapor to plate","spent",[KIT.phase("basin","liquid"),KIT.phase("channel","sealed"),KIT.phase("shutter","open")]),
		"compare":{"component":"plate/control","caption":"Test uncooled plate","kind":"set","field":"comparison","value":"warm_dry","requires":[KIT.phase("plate","gas")]},
		"drain":KIT.control("tank","Drain droplets into measuring tank","full",[KIT.phase("plate","liquid")]),
		"measure":KIT.control("tank","Measure returned liquid","measured",[KIT.phase("tank","full")]),
		"ride":KIT.control("lift","Raise lift with returned water","raised",[KIT.phase("lift","lowered"),KIT.phase("tank","measured")]),
		"lock":KIT.control("lift","Lock lift at upper landing","locked",[KIT.phase("lift","raised")]),
		"exit":KIT.control("exit","Open stream exit","open",[KIT.phase("lift","locked")]),
	},"targets":{
		INLET:target("inlet","melting",{},2.5),
		COLLECTOR:plate,
	}}
