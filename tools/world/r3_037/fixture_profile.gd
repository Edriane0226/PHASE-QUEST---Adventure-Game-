extends "res://zone2_authority.gd"

const CONNECTED := "res://World/Navigation/ConnectedWorld.tscn"
var fixture_menu := true
var classic_verified := false
var fresh_ledger_path := ""

func _ready() -> void:
	for flag in ["r3_015_fixture","r3_019_permissions","r3_020_restore","r3_030_zone1",
			"r3_031_sunlit","r3_032_orchard","r3_033_dewglass","r3_034_stream",
			"r3_035_steamworks","r3_036_skybridge"]:
		set_meta(flag,true)
	var args := OS.get_cmdline_user_args()
	var key := ""
	for arg in args:
		if arg.begins_with("--profile="):
			key = arg.trim_prefix("--profile=")
	if key not in ["fresh","migrated","review","render","map","manual","smoke"]:
		push_error("037 requires a named disposable profile.")
		return
	save_path = "res://../fixtures/" + key + ".save"
	if key == "migrated" and "--first" in args:
		if not _write_classic_wrapper():
			push_error("Could not write the disposable classic Dock profile.")
			return
	load_profile()
	if key == "migrated" and "--first" in args:
		classic_verified = _classic_survived()
	if key == "map" and not _copy_fresh_ledger():
		push_error("Could not copy discovery for this earned fresh-route profile.")
	world_entry_request = {}

func _copy_fresh_ledger() -> bool:
	var identity := world_discovery_namespace()
	if identity.is_empty():
		return false
	var project_name: String = ProjectSettings.get_setting("application/config/name")
	fresh_ledger_path = "res://../local-user/fresh/Godot/app_userdata/%s/world-discovery/%s.json" % [project_name,identity]
	var directory := "user://world-discovery"
	return (DirAccess.make_dir_recursive_absolute(directory) == OK
		and DirAccess.copy_absolute(fresh_ledger_path,directory.path_join(identity+".json")) == OK)

func _write_classic_wrapper() -> bool:
	var source := FileAccess.open("res://../fixtures/arrival.save",FileAccess.READ)
	if source == null:
		return false
	var raw: Variant = source.get_var(false)
	source.close()
	if not raw is Dictionary or not raw.extras.get(WORLD_SAVE.KEY) is Dictionary:
		return false
	var dock: Variant = raw.extras[WORLD_SAVE.KEY].attempts.get("Z1L6",{}).get("attempt")
	if not dock is Dictionary or WORLD_SAVE.region_for_run(dock) != "Z1L6":
		return false
	# Classic format had one active snapshot. The Dock attempt and all earned
	# completion, learning and inventory records come from the actual 030 save.
	raw.active_run = dock.duplicate(true)
	raw.extras.erase(WORLD_SAVE.KEY)
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(raw)
	file.flush()
	var written := file.get_error() == OK
	file.close()
	return written and DirAccess.copy_absolute(save_path,"res://../fixtures/classic-source.save") == OK

func _classic_survived() -> bool:
	var file := FileAccess.open("res://../fixtures/classic-source.save",FileAccess.READ)
	if file == null:
		return false
	var raw: Dictionary = file.get_var(false)
	file.close()
	var retained := ["lessons_seen","independent_phase_evidence","achievement_unlocks","achievement_progress","guides_unlocked"]
	return (not raw.extras.has(WORLD_SAVE.KEY) and data.player_name == raw.player_name
		and data.completed == raw.completed and data.active_run == raw.active_run
		and WORLD_SAVE.migrate(data) == data and world_record().active_subregion == "Z1L6"
		and retained.all(func(key): return data.extras.get(key) == raw.extras.get(key)))

func _fixture(source) -> bool:
	return (save_path.begins_with("res://../fixtures/")
		and ProjectSettings.globalize_path("res://").contains("/r3-prompt037/review/")
		and is_instance_valid(source) and source == get_tree().current_scene
		and source.fixture_session() and not source.demonstration_mode)

func menu_world_ready(id: String) -> bool:
	return (fixture_menu and (id.begins_with("Z2") or id in ["Z1L6","Z3L1"])) or super.menu_world_ready(id)

func request_world_continue() -> String:
	var path := super.request_world_continue()
	if not fixture_menu or path.is_empty():
		return path
	return CONNECTED
