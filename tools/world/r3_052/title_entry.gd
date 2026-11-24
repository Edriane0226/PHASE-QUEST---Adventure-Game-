extends RefCounted
## Drives the real title and transition in disposable staged processes.
const TITLE := "res://UI/Menus/MainMenuPanel.tscn"
const CAMPAIGN := "res://World/CampaignWorld.tscn"

static func open(tree: SceneTree, fresh := false) -> Node:
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	var menu := tree.current_scene
	if fresh:
		menu.view.buttons["new_game"].pressed.emit()
		menu.name_input.text="Campaign 052"
		menu.view.dialog.action_buttons["confirm_new_game"].pressed.emit()
	else:
		if menu.view.buttons["continue"].disabled:
			push_error("052 disposable save has no valid Continue.")
			tree.quit(1)
			return null
		menu.view.buttons["continue"].pressed.emit()
	var transition := tree.root.get_node("SceneTransition")
	var until := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<until:
		await tree.process_frame
		var world := tree.current_scene
		if world != null and world.scene_file_path==CAMPAIGN and not transition.busy:
			if world.entry_authorized and not world.restoration_pending:return world
			push_error("052 campaign entry failed: "+world.last_error)
			tree.quit(1)
			return null
	push_error("052 campaign entry timed out.")
	tree.quit(1)
	return null

static func block_save(profile: Node, block: bool) -> void:
	# Exercise the real writer's tempfile error in a disposable profile.
	var path: String = profile.save_path+".tmp"
	if not profile.campaign_staging_enabled():return
	if block:
		DirAccess.make_dir_absolute(path)
	else:
		DirAccess.remove_absolute(path)

static func cycle_district(world: Node, id: String) -> Node2D:
	var key := id+".shell"
	var resident: Node2D = world.chunks[key]
	var provider: Node = resident.runtime_provider
	var saved_at: Vector2 = world.player.safe_save_position()
	var previous: String = world.active_subregion_id
	var profile := world.get_node("/root/PlayerSave")
	var remote := "Z3L1" if id.begins_with("Z1") else "Z1L1"
	if not world.activate(remote,world.checkpoint_anchor(remote,"C0")) or not profile.enter_world_subregion(world,remote):return null
	await world.get_tree().physics_frame
	var inactive: bool = not world.nearby_districts[id] and resident.process_mode==Node.PROCESS_MODE_DISABLED
	if not world.activate(previous,saved_at) or not profile.enter_world_subregion(world,previous):return null
	await world.get_tree().physics_frame
	return resident if inactive and world.chunks[key]==resident and resident.runtime_provider==provider else null
