extends RefCounted
## Read-only menu eligibility. Geography/readiness and earned permissions remain separate.
const WORLD=preload("res://Scripts/Content/world_subregions.gd")
const SAVE=preload("res://Scripts/Content/world_save.gd")
const REGIONS={"melting_and_freezing":"gardens","vaporization_and_condensation":"vale","sublimation_and_deposition":"laboratory"}
static func resume(profile: Node) -> Dictionary:
	if profile.read_only or not profile.has_player_name():return {}
	var raw: Variant=profile.data.extras.get(SAVE.KEY)
	if not SAVE.supported(raw):return {}
	var world: Dictionary=profile.world_record()
	var run: Dictionary=profile.data.active_run
	var completed_only := false
	var id:=""
	if not world.is_empty() and not world.get("location",{}).is_empty():
		var location: Dictionary=world.location
		if not location.get("subregion") is String or not world.get("active_subregion") is String or not world.get("active_zone") is String:return {}
		id=location.subregion
		var row:=WORLD.definition(id)
		if row.is_empty() or world.active_subregion!=id or world.active_zone!=row.zone_id:return {}
		if not run.is_empty() and SAVE.region_for_run(run)!=id:return {}
	else:id=SAVE.region_for_run(run)
	if id.is_empty() and run.is_empty():
		for level in [2,1]:
			if profile.is_level_complete("melting_and_freezing",level):
				id = "Z1L%d" % level
				completed_only = true
				break
	var row:=WORLD.definition(id)
	if row.is_empty() or not profile.is_level_unlocked(row.zone_id,int(row.level)):return {}
	if not profile.menu_world_ready(id):return {}
	var attempt: Variant=run
	if run.is_empty():
		var archive: Variant=world.get("attempts",{}).get(id,{})
		attempt=archive.get("attempt",{}) if archive is Dictionary else {}
		if completed_only and attempt is Dictionary and attempt.is_empty():
			attempt={"zone":row.zone_id,"level":int(row.level),"state":{},"achievement_history_known":false}
	if not attempt is Dictionary or SAVE.region_for_run(attempt)!=id or not attempt.get("state",{}) is Dictionary:return {}
	if not SAVE.supported_campaign_run(attempt):return {}
	return {"subregion":id,"zone":row.zone_id,"region":REGIONS[row.zone_id],"attempt":attempt.duplicate(true)}
