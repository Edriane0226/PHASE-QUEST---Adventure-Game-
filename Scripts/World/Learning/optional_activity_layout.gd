extends RefCounted
## Optional practice uses the same accepted kit pivots and stacked-floor assembly as required tasks.
const PARTS = preload("res://Scripts/World/Zone1/stillwater_assembly.gd")
const DISPLAYS := {
	"Z1L4":"ice", "Z1L5":"ice", "Z2L2":"dry", "Z2L4":"dew", "Z2L5":"dew",
	"Z3L2":"paths", "Z3L4":"frost", "Z3L5":"frost",
}
const OUTCOMES := {
	"Z1L4":["freeze_side"], "Z1L5":["freeze_jig"], "Z2L4":["stream_regulated_plate"],
	"Z2L5":["steamworks_condenser"], "Z3L2":["sorting_warmer_sample","sorting_chamber_sample"],
	"Z3L4":["reversible_collector_a_deposit"], "Z3L5":["observatory_deposition"],
}
## Floor corrections in ground pixels, measured within the reserved pads.
const OFFSETS := {
	"Z1L5.optional":{"slot_triangle":Vector2(0,-2)},
	"Z2L5.optional":{"slot_triangle":Vector2(-6,10),"source_circle":Vector2(8,4),
		"slot_circle":Vector2(2,-4),"control":Vector2(8,-4)},
	"Z3L2.optional":{"source_melting":Vector2(-12,-8),"slot_melting":Vector2(-2,8),
		"source_sublimation":Vector2(8,0)},
}
const FROST_SIGN := Vector2(98,14)
const ACTIVITIES := {
	"ice":{
		"title":"Ice Mold Match", "shapes":["triangle","circle","square"], "process":"freezing", "mode":"cryo",
		"objective":"Freeze the filled molds and match the ice shapes to their silhouettes.",
		"cue":"Select Cryo and hold Fire at each filled mold. Liquid water loses heat and becomes solid ice.",
		"item":"ice sample",
	},
	"dry":{
		"title":"Drying Day", "shapes":["triangle","square","notch"],
		"objective":"Dry three damp pennants and hang them on their matching hooks.",
		"cue":"Start the fan at the sunny rack. Sunlight supplies energy. Airflow carries moist air away while water evaporates from the cloth surface below boiling.",
		"item":"pennant",
	},
	"dew":{
		"title":"Dew Garden", "shapes":["triangle","circle","square"], "process":"condensation", "mode":"cryo",
		"objective":"Collect liquid dew in three cups and water the matching planters.",
		"cue":"Select Cryo and hold Fire at the collector. Its regulated plate cools below the dew point while staying above freezing at +8°C. Water vapor becomes liquid droplets.",
		"item":"cup",
	},
	"paths":{
		"title":"Sample Match", "shapes":["melting","sublimation"],
		"objective":"Match each observed experiment card to its state path.",
		"cue":"Melting at normal pressure produced liquid water. Controlled sublimation captured gas with zero intermediate liquid. A shrinking solid alone does not identify the path.",
		"item":"observation card",
	},
	"frost":{
		"title":"Frost Gallery", "shapes":["branch","star","grid"], "process":"deposition", "mode":"pressure",
		"objective":"Collect three sealed frost samples and match their patterns to the display.",
		"cue":"Select Pressure and hold Fire at each supplied sealed collector. The chamber regulates pressure and removes heat. Water vapor becomes solid frost directly, with zero liquid.",
		"item":"sealed sample",
	},
}

static func row_offset(column: int, depth: float, count: int) -> Array:
	var side := (column - (count - 1) / 2.0) * 1.65
	return [depth + side, depth - side, 0]

static func art(kind: String, shape: String) -> Dictionary:
	match kind:
		"ice":
			var mold := "mold_" + shape
			return {"pending":mold+"_liquid", "working":mold+"_freezing", "ready":mold+"_solid",
				"vacant":mold+"_empty", "held":mold+"_sample", "slot":mold+"_empty",
				"wrong":mold+"_wrong", "placed":mold+"_committed", "card":"observation_card_"+shape}
		"dry":
			var cloth := "pennant_" + shape
			var hook := "pennant_hook_" + shape
			return {"pending":cloth+"_wet", "working":cloth+"_drying", "ready":cloth+"_dry",
				"held":cloth+"_carried", "slot":hook+"_empty", "wrong":hook+"_wrong", "placed":hook+"_committed"}
		"dew":
			var cup := "dew_cup_" + shape
			var planter := "dew_planter_" + shape
			return {"pending":cup+"_empty", "working":cup+"_empty", "ready":cup+"_full",
				"held":cup+"_carried", "slot":planter+"_dry", "wrong":planter+"_wrong",
				"placed":planter+"_committed", "returned":cup+"_poured", "card":"dew_card_"+shape}
		"paths":
			var card := "path_card_" + shape
			var slot := "sample_match_" + shape
			return {"pending":card+"_unobserved", "working":card+"_unobserved", "ready":card+"_observed",
				"held":card+"_observed", "slot":slot+"_empty", "wrong":slot+"_wrong", "placed":slot+"_committed"}
		"frost":
			var collector := "gallery_collector_" + shape
			var slot := "gallery_slot_" + shape
			return {"pending":collector+"_early", "working":collector+"_growing", "ready":collector+"_target",
				"vacant":collector+"_empty", "held":"gallery_sample_"+shape+"_carried", "slot":slot+"_empty",
				"wrong":slot+"_wrong", "placed":slot+"_committed", "card":"gallery_card_"+shape}
	return {}

static func piece(catalog: Dictionary, id: String, offset: Array, size: float, images: Dictionary, solid: bool, art_scale := 1.0) -> Dictionary:
	var variants := {}
	for phase in images:
		var entry: Dictionary = catalog[images[phase]]
		variants[phase] = {"path":entry.path, "pivot_px":entry.pivot_px, "scale":entry.world_scale*art_scale}
	var part := PARTS.part(id,offset,size,{"phase":images.keys()[0]},variants)
	if solid:
		var half := size * 10.0
		part.collision_bounds = [[-half,0],[0,-half/2],[half,0],[0,half/2]]
	return part

static func place(offset: Array, shift: Vector2, rise := 0) -> Array:
	return [offset[0] + shift.y / 20.0 + shift.x / 40.0,
		offset[1] + shift.y / 20.0 - shift.x / 40.0, rise]

static func definition(id: String, at: Vector2, catalog: Dictionary, kind: String) -> Dictionary:
	var shapes: Array = ACTIVITIES[kind].shapes
	var offsets: Dictionary = OFFSETS.get(id,{})
	var pieces := []
	for i in shapes.size():
		var shape: String = shapes[i]
		var images := art(kind,shape)
		var source := {"pending":images.pending,"working":images.working,"ready":images.ready}
		for phase in ["vacant","returned"]:
			if images.has(phase): source[phase] = images[phase]
		var source_solid := kind in ["ice","frost"]
		var source_id := "source_"+shape
		var source_offset := place(row_offset(i,2.75,shapes.size()),offsets.get(source_id,Vector2.ZERO))
		if kind == "frost": source_offset = place([0,0,0],Vector2(0,27+52*i))
		pieces.append(piece(catalog,source_id,source_offset,1.5,source,source_solid))
		var slot_column := (i+1) % shapes.size()
		var slot_id := "slot_"+shape
		var slot_offset := place(row_offset(slot_column,5.75,shapes.size()),offsets.get(slot_id,Vector2.ZERO))
		if kind == "frost": slot_offset = place([0,0,0],Vector2(44,39+52*slot_column))
		pieces.append(piece(catalog,slot_id,slot_offset,1.5,
			{"empty":images.slot,"wrong":images.wrong,"placed":images.placed},kind in ["dew","frost"]))
		if images.has("card"):
			pieces.append(piece(catalog,"card_"+shape,place(slot_offset,Vector2.ZERO,1),0.75,
				{"default":images.card},false,0.45))
	if kind == "dry":
		pieces.append(piece(catalog,"control",[1,3,0],1.5,{"idle":"orchard_fan_off","running":"orchard_fan_air_a"},true))
		pieces.append(piece(catalog,"rack",[2,1,0],1.5,{"default":"drying_rack_empty"},true))
	elif kind == "dew":
		pieces.append(piece(catalog,"control",place([1.25,1.25,0],offsets.get("control",Vector2.ZERO)),1.5,
			{"idle":"return_collector_warm","running":"return_collector_cooled","ready":"return_collector_droplets"},true))
	var origin := at+Vector2(80,-90) if kind == "frost" else at-Vector2(0,85)
	var size := Vector2(9.0,9.0) if kind == "frost" else Vector2(8.5,8.5)
	return {"id":id,"origin_ground":origin,"footprint_cubes":size,"stepped_floor":true,"components":pieces}
