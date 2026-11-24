extends RefCounted
## Conservative legacy -> world state. Locations/Guide views never prove a stage.
const PARTS := ["gear","crank","brake_shoe"]
const DEFAULTS := {"route_version":2,"bell_count":0,"furnace_on":false,"part":"ground","clear":false,"checkpoint":"C0","workshop_version":1,"workshop_parts":[0,0,0],"workshop_held":-1,"gear_thawed":false,"latch_thawed":false,"heavy_engaged":false,"light_count":0,"cache_thawed":false,"crank":"cache","walkback_open":false,"jump_records":{},"deaths":0,"death_pending":false}
static func migrate(raw: Variant, completed: bool) -> Dictionary:
	if not raw is Dictionary:return {"version":99,"legacy_original":raw}
	if raw.get("route_version",2) not in [0,1,2] or raw.get("workshop_version",1)!=1:return {"version":99,"legacy_original":raw}
	var s:=DEFAULTS.duplicate(true);s.merge(raw.duplicate(true),true)
	if raw.is_empty() and completed:
		s.merge({"bell_count":3,"furnace_on":true,"part":"docked","clear":true,"checkpoint":"C2","workshop_parts":[2,2,2],"gear_thawed":true,"latch_thawed":true,"heavy_engaged":true,"light_count":2,"cache_thawed":true,"crank":"installed","walkback_open":true,"completion_only_recovery":true},true)
	elif raw.get("route_version",0)!=2:
		if s.part not in ["ground","held","docked"]:return {"version":99,"legacy_original":raw}
		s.bell_count=3 if s.clear else ["ground","held","docked"].find(s.part)
		s.heavy_engaged=raw.get("mirror_a",0)==1 or s.cache_thawed
		var turns: Variant=raw.get("mirror_b",0)
		if not turns is int:return {"version":99,"legacy_original":raw}
		s.light_count=2 if s.cache_thawed else mini(clampi(turns,0,3),1)
	if not raw.has("workshop_version"):
		var cp: Variant=raw.get("checkpoint_progress",{})
		var c2: bool=s.checkpoint=="C2" or (cp is Dictionary and cp.get("unlock_sequence") is Array and "C2" in cp.unlock_sequence)
		if s.latch_thawed or c2:
			s.clear=true;s.bell_count=3;s.workshop_parts=[2,2,2];s.gear_thawed=true;s.latch_thawed=true
		elif s.gear_thawed:s.workshop_parts=[1,0,0] # Keep earned thaw; never invent placement.
	s.part="docked" if s.clear else "ground" # Retired opening module is not new cargo.
	if not s.jump_records is Dictionary:return {"version":99,"legacy_original":raw}
	if s.walkback_open:s.jump_records.z1_l2_j2=true # Same restoration rule as legacy apply_cache_state.
	s.route_version=2;s.workshop_version=1
	return {"version":1,"subregion":"Z1L2","components":{},"items":{},"legacy":s,"legacy_original":raw.duplicate(true)}

static func supported(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version")!=1 or raw.get("subregion")!="Z1L2" or not raw.get("legacy") is Dictionary:return false
	var s: Dictionary=raw.legacy
	if s.get("route_version")!=2 or s.get("workshop_version")!=1:return false
	for field in ["furnace_on","clear","gear_thawed","latch_thawed","heavy_engaged","cache_thawed","walkback_open","death_pending"]:
		if not s.get(field) is bool:return false
	for field in ["bell_count","light_count"]:
		if not s.get(field) is int or s[field]<0 or s[field]>3:return false
	if not s.get("workshop_parts") is Array or s.workshop_parts.size()!=3:return false
	for phase in s.workshop_parts:
		if not phase is int or phase not in [0,1,2]:return false
	if not s.get("workshop_held") is int or s.workshop_held < -1 or s.workshop_held>2:return false
	if s.get("crank") not in ["cache","held","installed"]:return false
	if not s.get("jump_records") is Dictionary or not s.get("deaths") is int or s.deaths<0:return false
	if s.workshop_held>=0 and (s.workshop_parts[s.workshop_held]!=1 or s.crank=="held"):return false
	if (s.latch_thawed or s.gear_thawed) and not s.clear:return false
	if s.latch_thawed and s.workshop_parts!=[2,2,2]:return false
	if s.cache_thawed and not s.latch_thawed:return false
	if s.crank!="cache" and (not s.cache_thawed or not s.walkback_open):return false
	return true

static func complete(s: Dictionary) -> bool:
	return s.get("clear",false) and s.get("workshop_parts")==[2,2,2] and s.get("cache_thawed",false) and s.get("walkback_open",false) and s.get("jump_records",{}).get("z1_l2_j2",false) and s.get("crank")=="installed"
