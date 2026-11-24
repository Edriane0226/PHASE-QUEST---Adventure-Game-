extends RefCounted
## Spatial identity is independent of campaign readiness. Layout metadata grants nothing.
const LEVELS=preload("res://Scripts/Content/level_registry.gd")
const INDEX="res://World/Data/subregions.json"
const WORLD_SCENE="res://World/PhaseWorld.tscn"
const CAMPAIGN_SCENE="res://World/CampaignWorld.tscn"
const CAMPAIGN_DISTRICTS := {
	"Z1L1":NodePath("GroundSort/Zone1/Garden"),
	"Z1L2":NodePath("GroundSort/Zone1/FrozenMill"),
	"Z1L3":NodePath("GroundSort/Zone1/Stillwater"),
	"Z1L4":NodePath("GroundSort/Zone1/Canal"),
	"Z1L5":NodePath("GroundSort/Zone1/SnowboundWorkshop"),
	"Z1L6":NodePath("GroundSort/Zone1/FrozenDock"),
	"Z2L1":NodePath("GroundSort/Zone2/SunlitLanding"),
	"Z2L2":NodePath("GroundSort/Zone2/DryingOrchard"),
	"Z2L3":NodePath("GroundSort/Zone2/Dewglass"),
	"Z2L4":NodePath("GroundSort/Zone2/ReturningStream"),
	"Z2L5":NodePath("GroundSort/Zone2/SteamworksGarden"),
	"Z2L6":NodePath("GroundSort/Zone2/SkybridgeEngine"),
	"Z3L1":NodePath("GroundSort/Zone3/VanishingIceLab"),
	"Z3L2":NodePath("GroundSort/Zone3/SampleSorting"),
	"Z3L3":NodePath("GroundSort/Zone3/Frostprint"),
	"Z3L4":NodePath("GroundSort/Zone3/ReversibleFrost"),
	"Z3L5":NodePath("GroundSort/Zone3/Observatory"),
	"Z3L6":NodePath("GroundSort/Zone3/PhaseworksCore")
}
# Only reviewed, integrated runtime chunks may be added by later prompts.
const READY_CHUNKS: Dictionary={}
static var _catalog: Dictionary={}
static func _load_index() -> void:
	if not _catalog.is_empty():return
	var value=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if value is Dictionary and value.get("subregions") is Array:_catalog=value
static func definitions() -> Array:
	_load_index();return _catalog.get("subregions",[]).duplicate(true)
static func definition(id: String) -> Dictionary:
	_load_index()
	for source in _catalog.get("subregions",[]):
		var row: Dictionary=source.duplicate(true)
		if row.id==id:
			row.world_ready=READY_CHUNKS.has(id);row.world_scene=READY_CHUNKS.get(id,"");return row
	return {}
static func world_bounds() -> Rect2:
	_load_index();var b: Array=_catalog.get("world_bounds",[0,0,0,0]);return Rect2(b[0],b[1],b[2],b[3])
static func legacy_scene(id: String) -> String:
	var row:=definition(id)
	return LEVELS.scene_for_level(str(row.zone_id),int(row.level)) if not row.is_empty() else ""
static func can_enter(profile: Node,id: String) -> bool:
	var row:=definition(id)
	return not row.is_empty() and row.world_ready and profile.is_level_unlocked(row.zone_id,row.level)
static func can_enter_campaign(profile: Node,id: String) -> bool:
	if not CAMPAIGN_DISTRICTS.has(id):return false
	var row:=definition(id)
	return not row.is_empty() and profile.is_level_unlocked(row.zone_id,row.level)
static func local_to_ground(id: String,local: Vector2) -> Vector2:
	var row:=definition(id)
	return local+Vector2(row.origin[0],row.origin[1]) if not row.is_empty() else Vector2(INF,INF)
static func ground_to_local(id: String,ground: Vector2) -> Vector2:
	return ground-local_to_ground(id,Vector2.ZERO)
static func projected(ground: Vector2,elevation: float) -> Vector2:
	return ground-Vector2(0,elevation)
