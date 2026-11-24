extends "res://sorting_authority.gd"

const FROSTPRINT = preload("res://Scripts/World/Zone3/frostprint_world.gd")

func _ready() -> void:
	set_meta("r3_040_frostprint",true)
	super._ready()

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/")
		and ProjectSettings.globalize_path("res://").contains("/r3-prompt040/review/")
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func campaign_source(source, zone: String, level: int) -> bool:
	if zone != ZONES[2] or level != 3:
		return super.campaign_source(source,zone,level)
	if not _fixture(source) or not session_active or WORLD_SAVE.region_for_run(data.active_run) != FROSTPRINT.REGION:
		return false
	var chunk: Node = source.active_chunk()
	return (source.access.allowed(FROSTPRINT.REGION) and is_instance_valid(chunk) and chunk.subregion_id == FROSTPRINT.REGION
		and chunk.frame_valid() and chunk.runtime_provider is FROSTPRINT)
