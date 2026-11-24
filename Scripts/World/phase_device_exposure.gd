extends RefCounted
## Pure cumulative simulation. Invalid/idle frames hold exposure; restore resets
## unfinished exposure. Only threshold crossing creates an outcome.
const RULES = preload("res://Scripts/Content/phase_transition_rules.gd")
var _spec: Dictionary = {}
var _elapsed := 0.0
var _outcome: Dictionary = {}

func configure(spec: Dictionary) -> bool:
	_spec = {}
	_elapsed = 0.0
	_outcome = {}
	if not RULES.definition_error(spec).is_empty(): return false
	_spec = spec.duplicate(true)
	return true

func definition() -> Dictionary:
	return _spec.duplicate(true)

func exposure() -> float:
	return _elapsed

func outcome() -> Dictionary:
	return _outcome.duplicate(true)

func advance(delta: float, mode: String, device: Dictionary, sample: Dictionary, flags: Dictionary, introduction_authorized := false) -> Dictionary:
	if _spec.is_empty(): return {"reason":"invalid_definition", "new_outcome":false}
	if not _outcome.is_empty(): return {"reason":"complete", "new_outcome":false}
	if not is_finite(delta) or delta <= 0: return {"reason":"invalid_delta", "new_outcome":false}
	var reason := RULES.eligibility(_spec, mode, device, sample, flags, introduction_authorized)
	if not reason.is_empty(): return {"reason":reason, "new_outcome":false}
	_elapsed = minf(_elapsed + delta, _spec.required_exposure)
	if _elapsed < _spec.required_exposure: return {"reason":"exposing", "new_outcome":false}
	var rule: Dictionary = RULES.PROCESSES[_spec.process]
	_outcome = {"version":1, "id":_spec.id, "process":_spec.process, "material":_spec.material,
		"from_state":rule.from, "to_state":rule.to, "capability":rule.capability, "puzzle_type":rule.type}
	return {"reason":"verified", "new_outcome":true}

func restore_completed(record: Variant) -> bool:
	# No fractional exposure is accepted from disk. Restore only exact outcomes.
	_elapsed = 0.0
	_outcome = {}
	if _spec.is_empty() or not record is Dictionary: return false
	var rule: Dictionary = RULES.PROCESSES[_spec.process]
	var expected := {"version":1, "id":_spec.id, "process":_spec.process, "material":_spec.material,
		"from_state":rule.from, "to_state":rule.to, "capability":rule.capability, "puzzle_type":rule.type}
	if record != expected: return false
	_outcome = expected
	_elapsed = _spec.required_exposure
	return true
