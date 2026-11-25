extends SceneTree
## Plans new elevations for authored scenery after the land under it moved up or down.
## Each piece keeps its own height above the ground. ground_scenery.mjs applies the plan.
##   Godot --headless --path <project> -s res://tools/world/terrain_bake/ground_scenery.gd -- <before> <after> <plan.json>
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var a: Dictionary = FileAccess.open(args[0],FileAccess.READ).get_var()
	var b: Dictionary = FileAccess.open(args[1],FileAccess.READ).get_var()
	var old := {}
	for s in a.scenery:old[s[0]] = s
	var plan := {}
	for s in b.scenery:
		if not old.has(s[0]) or old[s[0]][3] < -9000.0 or s[3] < -9000.0:continue
		var next: float = old[s[0]][2]+s[3]-old[s[0]][3]
		if absf(next-s[2]) > .01:plan[s[0]] = next
	var file := FileAccess.open(args[2],FileAccess.WRITE)
	file.store_string(JSON.stringify(plan,"\t"))
	file.close()
	print("SCENERY PLAN ",plan.size())
	quit()
