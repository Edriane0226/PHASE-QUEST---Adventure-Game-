extends "res://frostprint_authority.gd"

const CIRCUIT = preload("res://Scripts/World/Zone3/reversible_frost_world.gd")

func _ready() -> void:
	set_meta("r3_041_reversible_frost",true)
	super._ready()

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/")
		and ProjectSettings.globalize_path("res://").contains("/r3-prompt041/review/")
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func campaign_source(source, zone: String, level: int) -> bool:
	if zone != ZONES[2] or level != 4:
		return super.campaign_source(source,zone,level)
	if not _fixture(source) or not session_active or WORLD_SAVE.region_for_run(data.active_run) != CIRCUIT.REGION:
		return false
	var chunk: Node = source.active_chunk()
	return (source.access.allowed(CIRCUIT.REGION) and is_instance_valid(chunk) and chunk.subregion_id == CIRCUIT.REGION
		and chunk.frame_valid() and chunk.runtime_provider is CIRCUIT)
