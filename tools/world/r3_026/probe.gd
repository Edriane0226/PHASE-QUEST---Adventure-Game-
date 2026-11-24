extends SceneTree
## Independent full-foot oracle for installed water gaps and surrounding banks.
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run() -> void:
	change_scene_to_file("res://World/Navigation/ConnectedWorld.tscn");await scene_changed;await physics_frame
	var world=current_scene;var store=root.get_node("PlayerSave");var row: Dictionary=world.REGISTRY.definition("Z1L3")
	world.activate("Z1L3",Vector2(row.entry[0],row.entry[1]));store.enter_world_subregion(world,"Z1L3")
	var provider=preload("res://Scripts/World/Zone1/stillwater_world.gd").new();world.chunks["Z1L3.shell"].add_child(provider);check(provider.bind_crossing(world),"measured modular footprints bind")
	var originals: Array=[]
	for record in provider._original_floors:originals.append(record.polygon)
	var support=preload("res://Scripts/World/terrain_support_profiles.gd")
	for pit in provider.pits:
		var center: Vector2=world.models[0].box_of(pit).get_center()
		for x in range(-120,121,15):
			for y in range(-90,91,15):
				var at: Vector2=center+Vector2(x+1.3,y+.7);var box: Rect2=support.foot_rect(at);var foot: PackedVector2Array=world.models[0].rect_poly(box)
				var water: bool=not Geometry2D.intersect_polygons(foot,pit).is_empty()
				var expected: bool=not water and support.rectangle_supported(box,originals)
				check(world.geometry.supported_box(box)==expected,"independent bank/water support oracle "+str(at))
	var result:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures}
	FileAccess.open("res://../evidence/probe-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("GEOMETRY026 ",result.status," / ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
