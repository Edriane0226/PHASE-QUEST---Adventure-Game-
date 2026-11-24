extends RefCounted
## Authored water-transition contracts, not a general thermodynamic solver.
const DEVICE = preload("res://Scripts/Content/phase_device_progress.gd")
const PROCESSES := {
	"melting":{"modes":["thermal"], "capability":"melting", "from":"solid", "to":"liquid", "region":"melting", "heat":"in", "type":"melt_direct"},
	"freezing":{"modes":["cryo"], "capability":"freezing", "from":"liquid", "to":"solid", "region":"freezing", "heat":"out", "type":"freeze_controlled"},
	"evaporation":{"modes":["thermal"], "capability":"vaporization", "from":"liquid", "to":"gas", "region":"evaporating_surface", "heat":"in", "type":"evaporate_surface"},
	"boiling":{"modes":["thermal"], "capability":"vaporization", "from":"liquid", "to":"gas", "region":"boiling_bulk", "heat":"in", "type":"boil_volume"},
	"condensation":{"modes":["cryo","pressure"], "capability":"condensation", "from":"gas", "to":"liquid", "region":"condensing", "heat":"out", "type":"condense_collect"},
	"sublimation":{"modes":["vacuum"], "capability":"sublimation", "from":"solid", "to":"gas", "region":"solid_gas", "heat":"in", "type":"sublime_controlled"},
	"deposition":{"modes":["pressure"], "capability":"deposition", "from":"gas", "to":"solid", "region":"gas_solid", "heat":"out", "type":"deposit_frost"}
}

static func definition_error(spec: Dictionary) -> String:
	for field: String in ["id", "zone", "material", "process"]:
		if not spec.get(field) is String or spec[field].is_empty(): return "invalid_definition"
	if spec.zone not in ["melting_and_freezing","vaporization_and_condensation","sublimation_and_deposition"]: return "invalid_definition"
	if not spec.get("level") is int or spec.level < 1 or spec.level > 6: return "invalid_definition"
	if spec.material != "water" or not PROCESSES.has(spec.process): return "unsupported_transition"
	for field: String in ["required_exposure", "max_range"]:
		var value: Variant = spec.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) or value <= 0: return "invalid_definition"
	if not spec.get("allowed_modes") is Array or spec.allowed_modes.is_empty(): return "invalid_definition"
	for mode: Variant in spec.allowed_modes:
		if not mode is String or mode not in PROCESSES[spec.process].modes: return "unsupported_mode"
	if not spec.get("required_flags") is Array: return "invalid_definition"
	for flag: Variant in spec.required_flags:
		if not flag is String or flag.is_empty(): return "invalid_definition"
	var introduction: Variant = spec.get("introductory_milestone", "")
	if not introduction is String: return "invalid_definition"
	if not introduction.is_empty():
		if not DEVICE.MILESTONES.has(introduction): return "invalid_introduction"
		var milestone: Dictionary = DEVICE.MILESTONES[introduction]
		if milestone.zone != spec.zone or milestone.level != spec.level or milestone.capability != PROCESSES[spec.process].capability: return "invalid_introduction"
	return ""

static func eligibility(spec: Dictionary, mode: String, device: Dictionary, sample: Dictionary, flags: Dictionary, introduction_authorized := false) -> String:
	var error := definition_error(spec)
	if not error.is_empty(): return error
	var rule: Dictionary = PROCESSES[spec.process]
	var access := DEVICE.normalize(device)
	if mode not in spec.allowed_modes: return "unsupported_mode"
	if not access.unlocked_modes.has(mode): return "locked_mode"
	if not access.learned_capabilities.has(rule.capability) and not introduction_authorized: return "locked_capability"
	if mode == "pressure" and spec.process == "condensation" and not access.learned_capabilities.has("deposition"): return "locked_capability"
	for flag: String in spec.required_flags:
		if flags.get(flag) != true: return "prerequisite_missing"
	if sample.get("material") != spec.material: return "wrong_material"
	if sample.get("state") != rule.from: return "wrong_state"
	var amount: Variant = sample.get("amount")
	if not (amount is float or amount is int) or not is_finite(float(amount)) or amount <= 0: return "empty_sample"
	if sample.get("phase_region") != rule.region or sample.get("heat_flow") != rule.heat: return "unsuitable_conditions"
	# Pressure control works only through an instrumented, sealed chamber whose
	# controller has verified the material's phase region and heat exchange.
	if mode in ["vacuum", "pressure"]:
		if sample.get("sealed") != true or sample.get("instrumented") != true or sample.get("temperature_controlled") != true: return "controlled_chamber_required"
		if sample.get("pressure_regime") != ("low" if mode == "vacuum" else "high"): return "unsuitable_pressure"
	if spec.process in ["sublimation", "deposition"] and sample.get("liquid_present") != false: return "intermediate_liquid"
	return ""
