extends RefCounted
## Resolve teaching content from durable district and outcome identities.
const REGISTRY=preload("res://Scripts/Content/world_subregions.gd")
const VISUAL=preload("res://Scripts/UI/mechanic_visual.gd")
const DISTRICTS=preload("res://Scripts/World/Learning/district_teaching.gd")
const RULES=preload("res://Scripts/Content/phase_transition_rules.gd")
const GARDEN_DEMO=preload("res://Scripts/UI/Support/garden_guide_preview.gd")
const PHASE_EXPLANATIONS := {
	"freeze_controlled": "A prepared sample of liquid water lost heat and became solid ice. The substance stayed water.",
	"evaporate_surface": "Water escaped as invisible vapor from the liquid surface. Heat supplied energy without bringing the whole liquid to a boil.",
	"boil_volume": "Heat brought the water to boiling conditions. Vapor bubbles formed throughout the liquid.",
	"condense_collect": "Water vapor lost heat and became liquid droplets. The collector measured liquid water.",
	"sublime_controlled": "In the sealed low-pressure chamber, ice gained heat and became water vapor directly. The liquid sensor stayed at zero.",
	"deposit_frost": "The regulated cold collector removed heat from supplied water vapor. Ice grew directly from the gas without liquid.",
}
const WORLD_REFERENCES := {
	"map": ["Checkpoint map", ["Open Pause, then Checkpoint map. Choose a previously attuned checkpoint in this district."]],
	"task_sidebar": ["Current objectives", ["Read the objectives below your nameplate. Open Pause, then Objectives for the full list."]],
	"professor": ["Professor", ["Ask your district Professor for free lessons and puzzle help."]],
	"exit": ["District exits", ["Finish the required tasks, then use the exit. Follow the trail or transit to the next district."]],
	"movement": ["Moving and running", ["Use the movement stick. Hold Run to move faster. Approach equipment to use its contextual action."]],
	"crystals": ["Collecting crystals", ["In the Melting Garden, approach a crystal and interact. If frost covers it, stay nearby while it warms, then interact again to collect it."]],
	"vaporization": ["Evaporation and boiling", ["Liquid water gains energy and becomes invisible water vapor. Evaporation takes place at the surface. Boiling forms vapor bubbles throughout the liquid."]],
}
static var _cast: Dictionary={}
static func speaker(subregion: String) -> Dictionary:
	var row:=REGISTRY.definition(subregion)
	if row.is_empty():return {}
	if _cast.is_empty():_cast=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/professors/r3_v1/cast_registry.json"))
	# Zone role comes from preserved zone order, never location/highest completion.
	var zones: Array=["melting_and_freezing","vaporization_and_condensation","sublimation_and_deposition"]
	var role: String="professor_z%d"%(zones.find(row.zone_id)+1)
	var actor: Dictionary=_cast.actors.get(role,{})
	return {"role":role,"character_id":actor.get("character_id",""),"name":actor.get("display_name",""),"portrait":actor.get("portraits",{}).get(role+"_portrait_explaining",""),"subregion":subregion}
static func lesson(subregion: String,topic: String,authored: Dictionary={}) -> Dictionary:
	var result:=speaker(subregion)
	if result.is_empty():return {}
	var text: Array=WORLD_REFERENCES.get(topic,VISUAL.LESSONS.get(topic,[]))
	var local: Variant=authored.get(topic,DISTRICTS.LESSONS.get(subregion,{}).get(topic))
	if local is Dictionary and local.get("title") is String and local.get("paragraphs") is Array:text=[local.title,local.paragraphs]
	elif topic=="professor" and not text.is_empty():
		# This retained generic help topic names the local teacher; never mutate legacy copy.
		text=text.duplicate(true);text[0]=result.name
	result.merge({"topic":topic,"available":not text.is_empty(),"title":text[0] if not text.is_empty() else topic,"paragraphs":text[1] if text.size()>1 else []});return result

static func region_for(zone: String, level: int) -> String:
	for row in REGISTRY.definitions():
		if row.zone_id == zone and row.level == level: return row.id
	return ""

static func explanation(entry: Dictionary,authored: Dictionary={}) -> Dictionary:
	var instance: String=str(entry.get("instance_id",""))
	var region:=region_for(instance.get_slice(":",0),instance.get_slice(":",1).to_int())
	var result:=speaker(region)
	if result.is_empty():return {}
	var type_id: String=str(entry.get("type",""))
	var local: Variant=DISTRICTS.EXPLANATIONS.get(region,{}).get(type_id)
	var text: Variant=authored.get(type_id,local if local != null else PHASE_EXPLANATIONS.get(type_id,VISUAL.PUZZLE_EXPLANATIONS.get(type_id,"")))
	result.merge({"type":type_id,"instance_id":instance,"text":text if text is String else "","available":text is String and not text.is_empty()});return result

static func guide(record: Dictionary) -> Dictionary:
	var region := region_for(record.zone, record.level)
	var topic: String = record.topic
	var content := lesson(region,topic)
	var type_id: String = record.get("puzzle_type","")
	var result := {"title":content.get("title",topic),"speaker":content.get("role",""),
		"expression":"explaining","body":"\n\n".join(content.get("paragraphs",[])),"rows":[],"search":false}
	if not type_id.is_empty():
		var outcome := explanation({"type":type_id,"instance_id":"%s:%d:%s" % [record.zone,record.level,record.object]})
		if outcome.get("available",false):
			if not result.body.is_empty(): result.body += "\n\n"
			result.body += outcome.text
	var processes: Array[String] = []
	for process: String in RULES.PROCESSES:
		var rule: Dictionary = RULES.PROCESSES[process]
		if rule.type == type_id:
			processes.assign([process])
			break
		if rule.capability == topic: processes.append(process)
	if not processes.is_empty():
		result.diagram = processes[0]
		result.guide_processes = processes
	return result

static func preview(record: Dictionary) -> Control:
	var region := region_for(record.zone,record.level)
	if record.topic in ["map","checkpoint"] and not region.is_empty():
		var map_demo = preload("res://Scripts/UI/map_lesson_scenario.gd").new()
		map_demo.mode = "map"
		map_demo.district = region
		return map_demo
	match region:
		"Z1L2":
			if record.topic in ["resonance","melting","balance"]:
				var model=load("res://Scripts/World/Zone1/mill_guide_preview.gd").new()
				model.topic=record.topic
				return model
		"Z1L3":
			if record.topic in ["melting","freezing"]:
				var model=load("res://Scripts/World/Zone1/stillwater_guide_preview.gd").new()
				model.topic=record.topic
				return model
	if {"Z2L3":"condensation","Z3L1":"sublimation","Z3L3":"deposition"}.get(region) == record.topic:
		return load("res://Scripts/UI/Support/%s_preview.gd" % record.topic).new()
	if region == "Z1L1" and GARDEN_DEMO.supports(record.topic):
		var model := GARDEN_DEMO.new()
		model.topic=record.topic
		return model
	return null

static func answer(subregion: String,question: Dictionary,choice: int) -> Dictionary:
	if speaker(subregion).is_empty() or not question.get("choices") is Array or choice<0 or choice>=question.choices.size() or not question.get("correct") is int:return {}
	var feedback: Variant = question.get("feedback","")
	if feedback is Array: feedback = feedback[choice] if choice < feedback.size() else ""
	return {"correct":choice==question.correct,"feedback":("Correct. " if choice==question.correct else "Try again. ")+str(feedback),"speaker":speaker(subregion)}
