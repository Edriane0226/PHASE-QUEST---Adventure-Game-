extends RefCounted
## Separate outdoor modules for one guarded, externally heated test batch.
const KIT = preload("res://Scripts/World/Zone2/sunlit_assembly.gd")
const PIECES = preload("res://Scripts/World/Zone2/stream_circuit_assembly.gd")
const REGION := "Z2L5"
const BELT := "steamworks_drive_belt"
const PACK := "steamworks_cooling_pack"
const BELT_SOURCE := "world:belt/control"
const BELT_SOCKET := "installed:drive/control"
const PACK_SOURCE := "world:pack/control"
const PACK_SOCKET := "installed:jacket/control"
const INLET := "steamworks_inlet"
const FREEZER := "steamworks_pack"
const BOILER := "steamworks_boiler"
const CONDENSER := "steamworks_condenser"
const MEASURES := 2

static func part(id: String, points: Dictionary, phase: String, images: Dictionary, size: float,
		half := Vector2.ZERO, height := 1) -> Dictionary:
	var piece := PIECES.piece(id,points,phase,images,size,half)
	piece.components[0].height_layers = height
	return piece

static func target(id: String, process: String, gates: Dictionary, seconds: float, amount: int) -> Dictionary:
	var binding := KIT.transition(id,process,gates,seconds)
	binding.spec.level = 5
	# All transitions reuse learned capabilities from the preceding lessons.
	binding.erase("milestone")
	binding.spec.erase("introductory_milestone")
	binding.spec.allowed_modes = ["cryo"] if process in ["freezing","condensation"] else ["thermal"]
	binding.sample.amount = amount
	return binding

static func definition(points: Dictionary) -> Dictionary:
	var belt := part("belt",points,"dry",{"dry":"drive_belt_dry"},1)
	belt.components[0].item_id = BELT
	var pack := part("pack",points,"liquid",{"liquid":"cooling_pack_liquid",
		"solid":"cooling_pack_solid","spent":"cooling_pack_liquid"},1.5,Vector2(10,6))
	pack.components[0].item_id = PACK
	var cold := target("condenser","condensation",{"exhaust":["condenser","gas"],
		"frozen_pack":["pack","solid"],"installed_pack":["jacket","fitted"]},2.5,MEASURES)
	return {
		"subregion":REGION,
		"assemblies":[
			part("inlet",points,"solid",{"solid":"stream_inlet_frozen","liquid":"stream_inlet_thawed",
				"fed":"stream_inlet_flowing"},2,Vector2(23,12)),
			part("rack",points,"wet",{"wet":"drying_rack_folded","spread":"drying_rack_spread_wet",
				"drying":"drying_rack_drying","dry":"drying_rack_dry"},2.5,Vector2(27,11)),
			part("fan",points,"off",{"off":"orchard_fan_off","air":"orchard_fan_air_a"},1.5,Vector2(16,9)),
			part("shutter",points,"closed",{"closed":"solar_shutter_closed","open":"solar_shutter_open"},
				1.5,Vector2(17,9)),
			belt,pack,
			part("drive",points,"empty",{"empty":"engine_socket_drive_belt_empty"},1.5),
			part("jacket",points,"empty",{"empty":"pack_socket_empty","fitted":"pack_socket_fitted",
				"spent":"cooling_pack_liquid"},1.5),
			part("boiler",points,"empty",{"empty":"boiler_empty","filled":"boiler_cover_open",
				"liquid":"boiler_covered","gas":"boiler_boil_a","spent":"boiler_cooled"},2.5,Vector2(30,16),3),
			part("turbine",points,"idle",{"idle":"model_turbine_idle","exhaust":"model_turbine_idle",
				"stopped":"model_turbine_idle"},2.5,Vector2(27,15),2),
			part("condenser",points,"empty",{"empty":"return_collector_warm","gas":"return_collector_cooled",
				"liquid":"return_collector_droplets","drained":"return_collector_returning"},2.5,Vector2(24,12),2),
			part("reservoir",points,"empty",{"empty":"return_reservoir_empty","returned":"return_reservoir_full"},
				2.5,Vector2(22,12),2),
			part("desk",points,"locked",{"locked":"float_latch_covered","recorded":"engine_blueprint"},1.5,Vector2(12,7)),
			part("exit",points,"closed",{"closed":"float_latch_revealed","open":"float_latch_latched"},1),
		],
		"items":{BELT:{"source":"belt/control","initial_owner":BELT_SOURCE},
			PACK:{"source":"pack/control","initial_owner":PACK_SOURCE}},
		"actions":{
			"spread":KIT.control("rack","Spread wet belt","spread",[KIT.phase("rack","wet"),KIT.phase("inlet","liquid")]),
			"fan":KIT.control("fan","Start drying fan","air"),
			"sun":KIT.control("shutter","Open drying shutter","open"),
			"dry_start":KIT.control("rack","Set belt in sunlight and airflow","drying",
				[KIT.phase("rack","spread"),KIT.phase("fan","air"),KIT.phase("shutter","open")]),
			"dry":KIT.control("rack","Check dried belt","dry",[KIT.phase("rack","drying")]),
			"lift_belt":{"component":"belt/control","kind":"pickup","caption":"Lift dry belt","item":BELT,
				"requires":[KIT.phase("rack","dry")]},
			"fit_belt":{"component":"drive/control","kind":"place","caption":"Fit belt to turbine","item":BELT},
			"lift_pack":{"component":"pack/control","kind":"pickup","caption":"Lift frozen pack","item":PACK,
				"requires":[KIT.phase("pack","solid")]},
			"fit_pack":{"component":"jacket/control","kind":"place","caption":"Fit pack to condenser jacket","item":PACK},
			"fill":KIT.control("boiler","Feed inlet water to boiler","filled",[KIT.phase("boiler","empty"),
				KIT.phase("inlet","liquid"),KIT.phase("jacket","fitted")]),
			"guard":KIT.control("boiler","Close guard · keep vent open","liquid",[KIT.phase("boiler","filled")]),
			"route":KIT.control("turbine","Send boiler vapor through turbine","exhaust",
				[KIT.phase("boiler","gas"),KIT.phase("turbine","idle")]),
			"exhaust":KIT.control("turbine","Route exhaust to condenser","stopped",[KIT.phase("turbine","exhaust")]),
			"drain":KIT.control("reservoir","Return liquid to reservoir","returned",
				[KIT.phase("condenser","liquid"),KIT.phase("reservoir","empty")]),
			"blueprint":KIT.control("desk","Record engine blueprint","recorded",[KIT.phase("reservoir","returned")]),
			"exit":KIT.control("exit","Open Steamworks exit","open",[KIT.phase("desk","recorded")]),
		},
		"targets":{
			INLET:target("inlet","melting",{},2.5,MEASURES),
			FREEZER:target("pack","freezing",{"dry_belt":["rack","dry"]},2.5,1),
			BOILER:target("boiler","boiling",{"guard":["boiler","liquid"],"jacket":["jacket","fitted"]},4.0,MEASURES),
			CONDENSER:cold,
		},
	}
