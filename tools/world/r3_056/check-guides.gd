extends SceneTree

const LIBRARY = preload("res://UI/Guides/GuidesLibrary.tscn")
const JOURNAL = preload("res://UI/Menus/JournalPanel.tscn")
const TOPICS := {
	"melting": "res://Scripts/UI/Support/garden_guide_preview.gd",
	"map": "res://Scripts/UI/map_lesson_scenario.gd",
	"sluice": "",
}

class GardenGuideSupport extends CanvasLayer:
	var return_to_help := true
	var return_to_altar := false
	var demo_topic := "melting"
	var visual: Control

	func allowed_topics() -> Array:
		return TOPICS.keys()

	func guide_entry(topic: String) -> Dictionary:
		return {"zone": "melting_and_freezing", "level": 1, "object": topic}

	func return_from_guide() -> void:
		pass

	func open_help() -> void:
		pass

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	failures += int(not ok)
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	root.size = Vector2i(960, 540)
	var profile := root.get_node("PlayerSave")
	var path: String = profile.save_path
	var before: Dictionary = profile.data.duplicate(true)
	var hash := FileAccess.get_sha256(path)
	var support := GardenGuideSupport.new()
	root.add_child(support)
	var library := LIBRARY.instantiate()
	library.support = support
	support.add_child(library)
	var journal := JOURNAL.instantiate()
	root.add_child(journal)
	for topic: String in TOPICS:
		library.select_topic(topic)
		journal.guide_records[topic] = support.guide_entry(topic)
		journal._show_guide(topic)
		var replay: Button = library.get_node("Footer/Replay")
		if TOPICS[topic].is_empty():
			check(library.preview == null and replay.disabled and not library.description.text.is_empty(), "library keeps text for " + topic)
			check(journal.guide_preview == null and journal.guide_replay.disabled and not journal.guide_description.text.is_empty(), "Journal keeps text for " + topic)
		else:
			check(is_instance_valid(library.preview) and library.preview.get_script().resource_path == TOPICS[topic] and not replay.disabled, "library uses the isolated " + topic + " demo")
			check(is_instance_valid(journal.guide_preview) and journal.guide_preview.get_script().resource_path == TOPICS[topic] and not journal.guide_replay.disabled, "Journal uses the isolated " + topic + " demo")
			replay.pressed.emit()
			journal.guide_replay.pressed.emit()
			await process_frame
	check(profile.data == before and FileAccess.get_sha256(path) == hash, "Guides preserve profile memory and bytes")
	check(not ResourceLoader.has_cached("res://Zone_1/Levels/wrld_lvl_1.tscn") and not ResourceLoader.has_cached("res://Zone_1/Levels/wrld_lvl_2.tscn"), "Guides load neither standalone level")
	journal.free()
	support.free()
	print("GUIDES056 ", "PASS" if failures == 0 else "FAIL", " ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
