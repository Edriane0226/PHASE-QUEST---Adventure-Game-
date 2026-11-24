extends RefCounted
## Independent Orchard modules use the Zone 2 kit's ground pivots and scale.
const KIT = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const BELT := "orchard_drive_belt"
const INSTALLED := "installed:socket/control"
const SOURCE := "world:belt/control"
const TARGET_ID := "orchard_guarded_boiler"

static func piece(id: String, points: Dictionary, initial: String, art: Dictionary, size := 2.0) -> Dictionary:
	var site := KIT.fixture(id, points[id], initial, art, size)
	# Retain baked collision. Only the live boiler replaces its original body
	# so the native beam can identify its guarded endpoint.
	site.components[0].collision_bounds = []
	if id == "boiler":
		site.components[0].collision_bounds = [[-51,-36],[51,-36],[51,36],[-51,36]]
	return site

static func definition(points: Dictionary) -> Dictionary:
	var fixtures := [
		piece("rack", points, "folded", {"folded":"drying_rack_folded","wet":"drying_rack_spread_wet","drying":"drying_rack_drying","dry":"drying_rack_dry"}, 3),
		piece("fan", points, "off", {"off":"orchard_fan_off","airflow":"orchard_fan_air_a"}),
		piece("shutter", points, "closed", {"closed":"solar_shutter_closed","open":"solar_shutter_open"}),
		piece("socket", points, "empty", {"empty":"engine_socket_drive_belt_empty"}),
		piece("belt", points, "dry", {"dry":"drive_belt_dry"}, 1),
		piece("fill", points, "empty", {"empty":"return_reservoir_empty","filled":"return_reservoir_supplied"}),
		piece("cover", points, "open", {"open":"boiler_cover_open","guarded":"boiler_covered"}, 1.5),
		piece("boiler", points, "empty", {"empty":"boiler_empty","liquid":"boiler_filled","gas":"boiler_boil_a"}, 3),
		piece("valve", points, "closed", {"closed":"vapor_channel_sealed","routed":"vapor_channel_gas_a"}, 1.5),
		piece("turbine", points, "idle", {"idle":"model_turbine_idle"}, 3),
		piece("gate", points, "closed", {"closed":"harvest_gate_closed"}, 3),
		piece("cloth", points, "wet", {"wet":"pennant_square_wet","wrong":"pennant_square_wet","dry":"pennant_square_dry"}),
		piece("wheel", points, "idle", {"idle":"model_turbine_idle","wrong":"model_turbine_idle","turning":"model_turbine_turn_a"}),
		piece("exit", points, "locked", {"locked":"float_latch_covered","open":"float_latch_latched"}),
	]
	fixtures[4].components[0].item_id = BELT
	var actions := {
		"spread":KIT.control("rack","Spread wet belt","wet",[KIT.phase("rack","folded")]),
		"sun":KIT.control("shutter","Open sunny shutter","open"),
		"air":KIT.control("fan","Start airflow","airflow"),
		"dry":KIT.control("rack","Dry spread belt","drying",[KIT.phase("rack","wet"), KIT.phase("shutter","open"), KIT.phase("fan","airflow")]),
		"inspect":KIT.control("rack","Check dry belt","dry",[KIT.phase("rack","drying")]),
		"take":{"component":"belt/control","caption":"Lift dry belt","kind":"pickup","item":BELT,"requires":[KIT.phase("rack","dry")]},
		"fit":{"component":"socket/control","caption":"Fit belt to machine","kind":"place","item":BELT},
		"fill":KIT.control("fill","Supply boiler water","filled"),
		"guard":KIT.control("cover","Close inspection cover · vent open","guarded",[KIT.phase("fill","filled")]),
		"route":KIT.control("valve","Route vapor to turbine","routed",[KIT.phase("boiler","gas")]),
		"cloth":KIT.control("cloth","Choose tool for wet cloth","dry",[KIT.phase("valve","routed")]),
		"wheel":KIT.control("wheel","Choose tool for powered wheel","turning",[KIT.phase("cloth","dry")]),
		"exit":KIT.control("exit","Release orchard exit latch","open",[KIT.phase("wheel","turning")]),
	}
	var boiler := {"component":"boiler/control","occlusion_component":"boiler/control",
		"spec":{"zone":KIT.ZONE,"level":2,"material":"water","process":"boiling","allowed_modes":["thermal"],"required_exposure":4.0,"max_range":115.0,"required_flags":["supplied","guarded"]},
		"sample":{"material":"water","amount":1,"phase_region":"boiling_bulk","heat_flow":"in"},
		"flags":{"supplied":KIT.phase("fill","filled"),"guarded":KIT.phase("cover","guarded")},
		"events":[{"id":"bubble_business","members":[]},{"id":"six_changes","members":["boiling"]}]}
	return {"subregion":"Z2L2","assemblies":fixtures,"actions":actions,"targets":{TARGET_ID:boiler},
		"items":{BELT:{"initial_owner":SOURCE,"source":"belt/control"}},"guide_topics":["vaporization"]}
