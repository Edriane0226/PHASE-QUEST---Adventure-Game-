extends "res://core_authority.gd"

const CONNECTED := "res://World/Navigation/ConnectedWorld.tscn"
const KEYS := ["fresh","migrated","review","render","legacy","manual","smoke"]
const PROVIDER_FLAGS := [
	"r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1",
	"r3_031_sunlit","r3_032_orchard","r3_033_dewglass","r3_034_stream","r3_035_steamworks","r3_036_skybridge",
	"r3_038_vanishing_lab","r3_039_sorting_room","r3_040_frostprint","r3_041_reversible_frost",
	"r3_042_observatory","r3_043_phaseworks_core",
]

var fixture_menu := true
var legacy_source: Dictionary

func _ready() -> void:
	for flag in PROVIDER_FLAGS:
		set_meta(flag,true)
	var key := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			key = arg.trim_prefix("--profile=")
	if key not in KEYS or not _disposable_project():
		push_error("Zone 3 acceptance requires a named disposable profile.")
		return
	save_path = "res://../fixtures/"+key+".save"
	if key == "legacy" and not _write_legacy_location():
		push_error("Could not prepare the earned Core legacy location fixture.")
		return
	load_profile()

func _write_legacy_location() -> bool:
	var source := FileAccess.open("res://../fixtures/fresh-z3l6.save",FileAccess.READ)
	if source == null:
		return false
	var raw: Variant = source.get_var(false)
	source.close()
	if not raw is Dictionary or WORLD_SAVE.region_for_run(raw.get("active_run",{})) != "Z3L6":
		return false
	legacy_source = raw.duplicate(true)
	# Preserve the genuine attempts and progression. Exercise the use of the
	# old grounded local position when the world location envelope is absent.
	raw.extras[WORLD_SAVE.KEY].erase("location")
	raw.extras[WORLD_SAVE.KEY].erase("legacy_run")
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(raw)
	file.flush()
	return file.get_error() == OK

func _disposable_project() -> bool:
	return ProjectSettings.globalize_path("res://").contains("/r3-prompt044/review/")

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/") and _disposable_project()
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func menu_world_ready(id: String) -> bool:
	return (fixture_menu and _disposable_project() and (id in ["Z1L6","Z2L6"] or id in
		["Z3L1","Z3L2","Z3L3","Z3L4","Z3L5","Z3L6"])) or super.menu_world_ready(id)

func request_world_continue() -> String:
	var path := super.request_world_continue()
	return CONNECTED if fixture_menu and not path.is_empty() else path
