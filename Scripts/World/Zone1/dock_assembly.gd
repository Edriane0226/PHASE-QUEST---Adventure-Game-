extends "res://Scripts/World/Zone1/stillwater_assembly.gd"
## Separate storage casings, cargo, water tray, mechanical latch, jig, and launch ramp.
const RECIPE := {
	"plank1":"Plank bundle 1", "plank2":"Plank bundle 2", "plank3":"Plank bundle 3",
	"rope":"Rope coil", "sailcloth":"Sailcloth", "rudder":"Rudder kit",
}
const PLANKS := ["plank1","plank2","plank3"]
const RIGGING := ["rope","sailcloth","rudder"]

static func definition(points: Dictionary) -> Dictionary:
	var sites: Array = []
	var actions := {}
	var items := {}
	var targets := {}
	for id in RECIPE:
		var at: Vector2 = points[id]
		var cargo := part("cargo", [3,3,0], 1.2, {"phase":"part"}, {"part":visual("boat_part_" + id, .68)})
		cargo.item_id = id
		var components := [cargo]
		if id in PLANKS or id == "rudder":
			var ice := {"solid":id + "_shell_0", "liquid":id + "_shell_3"} if id in PLANKS else {"solid":"rudder_chest_frozen", "liquid":"rudder_chest_open"}
			var casing := fixture("ice", ice, "solid", 1.8)
			components.append(casing)
			targets["thaw_" + id] = transition(id + "/ice", "melting", "solid", 4.0)
		sites.append(site(id, at, components))
		var rack := "plank_rack" if id in PLANKS else "rigging_rack"
		items[id] = {"source":id + "/cargo", "initial_owner":"world:" + id + "/cargo", "rack":rack}
		actions["take_" + id] = action(id + "/cargo", "Pick up " + RECIPE[id].to_lower(), "pickup", id)
		actions["return_" + id] = action(id + "/cargo", "Return " + RECIPE[id].to_lower(), "place", id)
		actions["rack_" + id] = action(rack + "/control", "Stow " + RECIPE[id].to_lower(), "place", id)
	for id in ["plank_rack", "rigging_rack"]:
		sites.append(site(id, points[id], [fixture("control", {"rack":"sample_frame"}, "rack")]))
	var controls := {
		"ramp":{"closed":"maintenance_gate_closed", "open":"maintenance_gate_open"},
		"water":{"dry":"canal_diverter_main", "filled":"canal_diverter_side"},
		"latch":{"open":"bridge_lock_repositioned", "latched":"bridge_lock_latched"},
		"shutter":{"connected":"heat_shutter_connected", "isolated":"heat_shutter_isolated"},
		"jig":{"empty":"boat_assembly_empty", "liquid":"boat_assembly_liquid", "solid":"boat_assembly_solid",
			"assembled":"boat_assembly_rigged", "released":"boat_assembly_released", "tested":"boat_assembly_empty"},
		"fill_jig":{"full":"supply_liquid", "empty":"cooling_tray_drained"},
		"launch":{"ready":"dock_idle"},
	}
	for id in controls:
		var part_spec := fixture("control", controls[id], controls[id].keys()[0], 2.5 if id == "jig" else 1.5)
		if id == "ramp":
			part_spec.collision_bounds = [[-5,-26],[5,-26],[5,26],[-5,26]]
			part_spec.collision_layer = 2
		sites.append(site(id, points[id], [part_spec]))
	var tray := fixture("tray", {
		"dry":"cooling_tray_empty", "liquid":"cooling_tray_liquid", "solid":"cooling_tray_solid", "latched":"cooling_tray_latched"
	}, "dry", 1.7)
	sites.append(site("walkway", points.tray, [tray]))
	targets["freeze_walkway"] = transition("walkway/tray", "freezing", "liquid")
	targets["freeze_jig"] = transition("jig/control", "freezing", "liquid")
	targets["release_jig"] = transition("jig/control", "melting", "assembled")
	actions.merge({
		"ramp":action("ramp/control", "Lower cargo ramp"),
		"fill_walkway":action("water/control", "Fill service walkway"),
		"latch_walkway":action("latch/control", "Latch frozen walkway"),
		"isolate_heat":action("shutter/control", "Divert heat away from walkway"),
		"fill_jig":action("fill_jig/control", "Fill assembly jig"),
		"recipe":action("jig/control", "Inspect boat recipe"),
		"test":action("launch/control", "Test launch"),
	})
	return {
		"subregion":"Z1L6", "assemblies":sites, "items":items, "targets":targets, "actions":actions,
		"guide_topics":["melting", "freezing"],
	}

static func fixture(id: String, artwork: Dictionary, initial: String, size := 1.5) -> Dictionary:
	var variants := {}
	for phase in artwork:
		variants[phase] = visual(artwork[phase], .75)
	return part(id, [3,3,0], size, {"phase":initial}, variants)

static func action(component: String, caption: String, kind := "set", item := "") -> Dictionary:
	return {"component":component, "caption":caption, "kind":kind, "item":item, "field":"phase", "value":"used"}

static func transition(component: String, process: String, ready: String, seconds := 3.0) -> Dictionary:
	var melts := process == "melting"
	return {"component":component,
		"spec":{"zone":"melting_and_freezing", "level":6, "material":"water", "process":process,
			"allowed_modes":["thermal" if melts else "cryo"], "required_exposure":seconds, "max_range":105.0,
			"required_flags":["ready"]},
		"sample":{"material":"water", "amount":1, "phase_region":process, "heat_flow":"in" if melts else "out"},
		"flags":{"ready":{"component":component, "field":"phase", "value":ready}},
	}
