extends RefCounted
## The observation cup and irrigation tank share one pane, with an independent cooling loop.
const KIT = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const REGION := "Z2L3"
const MILESTONE := "z2l3_condensation"
const PANE := "dewglass_pane"
const PACK := "dewglass_cartridge_freezer"
const CARTRIDGE := "dewglass_cooling_cartridge"
const SOURCE := "world:pack/control"
const INSTALLED := "installed:jacket/control"
const HUMID_SOURCE := "dewglass_evaporation_tray"
const PANE_C := 6
const DEW_POINT_C := 12
const IRRIGATION_MEASURES := 3

static func proof(measures: int) -> Dictionary:
	return {"version":1,"source":HUMID_SOURCE,"material":"water","from_state":"gas","to_state":"liquid",
		"pane_c":PANE_C,"dew_point_c":DEW_POINT_C,"measures":measures}

static func piece(id: String, points: Dictionary, initial: String, images: Dictionary, size: float, height: float, body := Vector2.ZERO) -> Dictionary:
	var result := KIT.fixture(id,points[id],initial,images,size)
	var part: Dictionary = result.components[0]
	var at: Vector2 = points[id]
	result.origin_ground = [at.x,at.y-size*10]
	result.footprint_cubes = [size,size]
	part.offset_cubes = [size/2,size/2,0]
	part.height_layers = height
	if body != Vector2.ZERO:
		part.collision_bounds = [[-body.x,-body.y],[body.x,-body.y],[body.x,body.y],[-body.x,body.y]]
	return result

static func target(part: String, process: String, gates: Dictionary, seconds: float) -> Dictionary:
	var binding := KIT.transition(part,process,gates,seconds)
	binding.spec.level = 3
	binding.spec.max_range = 103.0 if part == "pane" else 78.0
	return binding

static func definition(points: Dictionary) -> Dictionary:
	var pack := piece("pack",points,"empty",{"empty":"cooling_pack_empty","liquid":"cooling_pack_liquid","solid":"cooling_pack_solid"},1.5,1,Vector2(13,8))
	pack.components[0].item_id = CARTRIDGE
	var pane := target("pane","condensation",{"humid_air":["source","humid"]},2.0)
	pane.milestone = MILESTONE
	pane.spec.introductory_milestone = MILESTONE
	pane.events.append({"id":"field_notes","members":["condensation"]})
	return {"subregion":REGION,"assemblies":[
		piece("pane",points,"gas",{"gas":"cooled_pane_warm","liquid":"cooled_pane_droplets"},2.5,2,Vector2(27,9)),
		piece("cup",points,"empty",{"empty":"dew_cup_circle_empty"},1,1),
		piece("source",points,"off",{"off":"humidity_source_off","humid":"humidity_source_humid"},2,1),
		piece("gutter",points,"missing",{"missing":"gutter_missing","joined":"gutter_connected"},1.5,1),
		piece("elbow",points,"loose",{"loose":"gutter_elbow","fitted":"gutter_straight"},1,1),
		piece("tank",points,"unseated",{"unseated":"collector_tank_empty","seated":"collector_tank_empty","full":"collector_tank_float_latched"},2,1),
		piece("jacket",points,"empty",{"empty":"cooling_jacket_empty","regulated":"cooling_jacket_regulated"},2,1),
		pack,
		piece("exit",points,"locked",{"locked":"float_latch_covered","released":"float_latch_latched"},1,1),
	],"items":{CARTRIDGE:{"source":"pack/control","initial_owner":SOURCE}},"actions":{
		"source":KIT.control("source","Open humid-air feed","humid"),
		"observe":KIT.control("pane","Check where droplets came from","question",[KIT.phase("pane","liquid")]),
		"gutter":KIT.control("gutter","Join gutter sections","joined",[KIT.phase("pane","liquid")]),
		"elbow":KIT.control("elbow","Fit gutter elbow","fitted",[KIT.phase("gutter","joined")]),
		"seat":KIT.control("tank","Seat irrigation tank","seated",[KIT.phase("elbow","fitted")]),
		"fill":KIT.control("pack","Fill cooling cartridge","liquid",[KIT.phase("tank","seated")]),
		"lift":{"component":"pack/control","kind":"pickup","caption":"Lift frozen cartridge","item":CARTRIDGE,"requires":[KIT.phase("pack","solid")]},
		"fit":{"component":"jacket/control","kind":"place","caption":"Fit cartridge into jacket","item":CARTRIDGE,
			"requires":[KIT.phase("tank","seated")],"events":[{"id":"hands_on","members":[]}]},
		"collect":KIT.control("tank","Measure irrigation water","full",[KIT.phase("tank","seated"),KIT.phase("jacket","regulated")]),
		"exit":KIT.control("exit","Release greenhouse latch","released",[KIT.phase("tank","full")]),
	},"targets":{PANE:pane,PACK:target("pack","freezing",{"filled":["pack","liquid"]},3.0)},
	"introductions":[MILESTONE],"guide_topics":["condensation"]}
