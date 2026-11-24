extends RefCounted
## Only native target commits write this bridge. Lessons/visibility never supply receipts.
const KEY := "world_intro_receipts"
const PROCESSES := {"melting":["melting"],"freezing":["freezing"],"vaporization":["evaporation","boiling"],"condensation":["condensation"],"sublimation":["sublimation"],"deposition":["deposition"]}
static func stage(extras: Dictionary, milestone_id: String, process: String, evidence_key: String) -> bool:
	var raw: Variant=extras.get(KEY,{"version":1,"milestones":{}})
	if not raw is Dictionary or raw.get("version")!=1 or not raw.get("milestones") is Dictionary:return false
	var record: Dictionary=raw.duplicate(true)
	var targets: Variant=record.milestones.get(milestone_id,{})
	if not targets is Dictionary:return false
	targets=targets.duplicate(true)
	if targets.has(process) and targets[process]!=evidence_key:return false
	targets[process]=evidence_key;record.milestones[milestone_id]=targets;extras[KEY]=record;return true
static func verified(profile: Dictionary, milestone_id: String, milestone: Dictionary) -> bool:
	var extras: Dictionary=profile.get("extras",{})
	var raw: Variant=extras.get(KEY)
	if not raw is Dictionary or raw.get("version")!=1 or not raw.get("milestones") is Dictionary:return false
	var targets: Variant=raw.milestones.get(milestone_id)
	var evidence: Variant=extras.get("independent_phase_evidence")
	if not targets is Dictionary or not evidence is Dictionary:return false
	for process in PROCESSES.get(milestone.capability,[]):
		var key: Variant=targets.get(process)
		if not key is String or not key.begins_with("%s:%d:"%[milestone.zone,milestone.level]):return false
		var receipt: Variant=evidence.get(key)
		if not receipt is Dictionary or receipt.get("version")!=1 or receipt.get("process")!=process or receipt.get("material")!="water" or receipt.get("capability")!=milestone.capability:return false
		var rule: Dictionary=load("res://Scripts/Content/phase_transition_rules.gd").PROCESSES.get(process,{})
		if rule.is_empty() or receipt.get("from_state")!=rule.from or receipt.get("to_state")!=rule.to or receipt.get("puzzle_type")!=rule.type:return false
		if key!="%s:%d:%s"%[milestone.zone,milestone.level,receipt.get("id","")]:return false
	return not PROCESSES.get(milestone.capability,[]).is_empty()
