extends RefCounted
## Conditions are evaluated by verified gameplay callers. This catalogue awards
## nothing by itself. IDs and set members are durable profile identifiers.
const DEFINITIONS := [
	{"id":"first_thaw", "name":"First Thaw", "icon":"ice",
		"condition":"Manually melt an ice barrier using Thermal device heat for the first time. Legacy direct-heater awards remain earned."},
	{"id":"helping_breeze", "name":"A Helping Breeze", "icon":"fan",
		"condition":"Manually complete the Melting Garden fan-assisted heater outcome after installing blades and providing fuel. Pickup alone does not count."},
	{"id":"follow_light", "name":"Follow the Light", "icon":"light",
		"condition":"Manually complete a mirror-directed heating puzzle."},
	{"id":"ice_builder", "name":"Ice Builder", "icon":"steps",
		"condition":"Manually freeze a filled tray to verified solid state."},
	{"id":"back_and_forth", "name":"Back and Forth", "icon":"arrows",
		"condition":"Manually melt and refreeze the same tracked water sample in one puzzle instance. Tutorial previews do not count."},
	{"id":"surface_escape", "name":"Surface Escape", "icon":"tray",
		"condition":"Manually complete a surface-evaporation outcome."},
	{"id":"bubble_business", "name":"Bubble Business", "icon":"boiler",
		"condition":"Manually complete a boiling-through-volume outcome."},
	{"id":"two_ways_up", "name":"Two Ways Up", "icon":"dual",
		"condition":"Earn both Surface Escape and Bubble Business across saves or sessions.",
		"mode":"derived", "members":["surface_escape","bubble_business"]},
	{"id":"dew_detective", "name":"Dew Detective", "icon":"drop",
		"condition":"Manually collect the required amount of condensed water in a condensation puzzle."},
	{"id":"round_trip", "name":"Round Trip", "icon":"loop",
		"condition":"Manually complete boiling → condensation → reservoir return in one working circuit."},
	{"id":"no_liquid_needed", "name":"No Liquid Needed", "icon":"gas",
		"condition":"Manually complete controlled sublimation with no intermediate liquid state."},
	{"id":"frost_from_air", "name":"Frost from Air", "icon":"frost",
		"condition":"Manually complete deposition using water vapor with no intermediate liquid."},
	{"id":"direct_return", "name":"Direct Return", "icon":"transfer",
		"condition":"Manually complete sublimation → deposition transfer in the same tracked apparatus."},
	{"id":"six_changes", "name":"Six Changes Understood", "icon":"six",
		"condition":"Record an independent verified solve for all six phase changes. Vaporization requires both evaporation and boiling. This game achievement is not a validated assessment result.",
		"mode":"set", "members":["melting","freezing","evaporation","boiling","condensation","sublimation","deposition"]},
	{"id":"chilled_to_death", "name":"Chilled to death", "icon":"mitten", "hidden":true,
		"condition":"First actual game-over caused by cold when warmth reaches zero. Falling, pause, reload and visual frost effects do not qualify."},
	{"id":"back_to_fire", "name":"Back to the Fire", "icon":"fire",
		"condition":"In one life, fall to 25% warmth or below, then recover to at least 90% through shelter heat without cold death or checkpoint teleport resetting the meter."},
	{"id":"safe_return", "name":"Safe Return", "icon":"flag",
		"condition":"Unlock a non-entry checkpoint, then respawn at the newest unlocked checkpoint after a death and regain control. Initial spawn and fast travel do not count."},
	{"id":"hands_on", "name":"Hands On", "icon":"module",
		"condition":"Successfully pick up and place a required module or part in its matching destination. Dropping it elsewhere does not count."},
	{"id":"pocket_scientist", "name":"Pocket Scientist", "icon":"crystals",
		"condition":"Collect all six unique crystals in the Melting Garden. Repeated pickup events do not count.",
		"mode":"set", "target":6, "validation":"crystal"},
	{"id":"trail_mapper", "name":"Trail Mapper", "icon":"pins",
		"condition":"Activate three distinct non-entry waypoints across the campaign. Revisits and fast travel do not count.",
		"mode":"set", "target":3, "validation":"waypoint"},
	{"id":"field_notes", "name":"Field Notes", "icon":"book",
		"condition":"Unlock all six phase-change lesson Guides through required lessons or observations. Discovery does not establish independent mastery.",
		"mode":"set", "members":["melting","freezing","vaporization","condensation","sublimation","deposition"]},
	{"id":"good_question", "name":"Good Question", "icon":"question",
		"condition":"Open free contextual help for an active unresolved puzzle and acknowledge its guidance. Automatic introductions and empty help panels do not count."},
	{"id":"try_another_way", "name":"Try Another Way", "icon":"retry",
		"condition":"After an explicit test reports an incorrect configuration, change it and manually solve the same puzzle ID. Setup, waiting and previews do not count. Free help is allowed."},
	{"id":"steady_explorer", "name":"Steady Explorer", "icon":"boots",
		"condition":"Complete a district in one attempt without player death. Free help is allowed."},
	{"id":"boatwright", "name":"Boatwright", "icon":"boat",
		"condition":"Complete the Frozen Dock recovery puzzles, assemble the boat and pass its launch test."},
	{"id":"steam_engineer", "name":"Steam Engineer", "icon":"engine",
		"condition":"Assemble the Skybridge engine and pass the full vapor/condensate return test."},
	{"id":"frost_engineer", "name":"Frost Engineer", "icon":"cartridge",
		"condition":"Assemble the Phaseworks Core cartridge and verify its deposited sample."},
	{"id":"snow_scholar", "name":"Snow Scholar", "icon":"snow_seal",
		"condition":"Pass the Frozen Dock craft test, answer all 3 Finn questions correctly, and board the boat."},
	{"id":"sun_scholar", "name":"Sun Scholar", "icon":"sun_seal",
		"condition":"Pass the Skybridge Engine craft test, answer all 4 Finn questions correctly, and depart on the lift."},
	{"id":"lab_scholar", "name":"Lab Scholar", "icon":"lab_seal",
		"condition":"Pass the Phaseworks Core craft test, answer all 6 Finn questions correctly, use the scanner and complete the desk result."},
	{"id":"phase_explorer", "name":"Phase Explorer", "icon":"crest",
		"condition":"Complete all 18 unique districts across the three zones.",
		"mode":"set", "target":18, "validation":"level"},
	{"id":"clear_explanation", "name":"Clear Explanation", "icon":"speech",
		"condition":"Answer every Finn question correctly on its first attempt in one challenge run without contextual answer help during that run. Prior learning and earlier puzzle help are allowed. No timer."}
]

static func definition(id: String) -> Dictionary:
	for item: Dictionary in DEFINITIONS:
		if item.id == id: return item
	return {}

static func target(item: Dictionary) -> int:
	return item.members.size() if item.has("members") else int(item.get("target", 1))

static func progress_count(item: Dictionary, state: Dictionary) -> int:
	if item.get("mode", "count") == "derived":
		return item.members.filter(func(member): return state.unlocks.has(member)).size()
	var field := "values" if item.get("mode", "count") == "set" else "events"
	return mini(target(item), state.progress[item.id][field].size())

static func valid_member(item: Dictionary, value: String, context: String) -> bool:
	if item.has("members"): return value in item.members
	var rule: String = item.get("validation", "")
	if rule == "crystal":
		return context == "melting_and_freezing:1" and value in range(6).map(func(i): return "melting_and_freezing:1:crystal%d" % i)
	if rule == "level":
		var parts := value.split(":")
		return parts.size() == 2 and parts[0] in ["melting_and_freezing","vaporization_and_condensation","sublimation_and_deposition"] and parts[1] in ["1","2","3","4","5","6"]
	if rule == "waypoint":
		if not value.begins_with(context + ":waypoint"): return false
		var index := value.trim_prefix(context + ":waypoint")
		return index.is_valid_int() and int(index) > 0 and index == str(int(index))
	return false
