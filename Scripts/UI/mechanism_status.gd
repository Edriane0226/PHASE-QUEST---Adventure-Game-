extends CanvasLayer
const FONT = preload("res://assets/fonts/InterfaceSans.tres")
var level: Node2D
var warning: ColorRect
var card: VBoxContainer
var bar: ProgressBar
var caption: Label
var world_bars: Node2D
var tasks: Array = []
var clock := 0.0


func bindLevel(owner_level: Node2D) -> void:
	level = owner_level
	warning = $ColdWarning
	card = level.hud_root.get_node("MechanismStatusCard")
	bar = card.get_node("ProgressBar")
	caption = card.get_node("Caption")
	world_bars = level.get_node("WorldMechanismBars")
	world_bars.draw.connect(_draw_bars)


func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	clock += delta
	var live: bool = (
		not level.overview and not level.complete and not level.dead and not get_tree().paused
	)
	warning.visible = live and level.warmth < 25
	warning.material.set_shader_parameter("strength", clampf((25 - level.warmth) / 15, .4, 1))
	warning.material.set_shader_parameter("beat", pow(maxf(0, sin(clock * 5)), 3))
	tasks = collect_tasks() if live else []
	world_bars.queue_redraw()
	var nearest := -1
	var distance := 440.0
	for i in range(tasks.size()):
		var value: float = level.player.position.distance_to(tasks[i].at)
		if value < distance:
			nearest = i
			distance = value
	card.visible = nearest >= 0 and level.warming_crystal < 0
	if nearest >= 0:
		var task: Dictionary = tasks[nearest]
		bar.value = task.value * 100
		caption.text = task.text + " · %d%%" % [task.value * 100]
	if level.mobile_controls.touch_mode:
		card.offset_top = -245
		card.offset_bottom = -205
		level.thawing_group.offset_top = -245
		level.thawing_group.offset_bottom = -199



func _add(result: Array, id: String, text: String, value: float, active: bool) -> void:
	if value >= 1 or (not active and value <= 0):
		return
	result.append(
		{
			"id": id,
			"at": level.props[id].position,
			"text": text if active else text + " (paused)",
			"value": value
		}
	)


func collect_tasks() -> Array:
	var result: Array = []
	if level.SAVE_LEVEL <= 2:
		for i in range(3):
			_add(result, "ice%d" % i, "Melting ice", level.melted[i], level._heat_available(i))
			if level.SAVE_LEVEL == 2:
				var heating: bool = (
					level.lit[i]
					and (i != 1 or level._fan_running())
					and (i != 2 or level.receiver_lit)
					and level.valve_modes[i] == 1
				)
				_add(result, "valve%d" % i, "Warming copper link", level.pipe_warmth[i], heating)
		if not level.receiver_lit:
			_add(
				result,
				"receiver",
				"Igniting relay heater",
				level.ignition_charge,
				level._mirror_aligned()
			)
	elif level.SAVE_LEVEL == 3:
		for i in range(4):
			var route: bool = i != 3 or level.routing == 2
			_add(
				result,
				"pool%d" % i,
				"Filling water basin",
				level.water[i],
				level.flowing[i] and route
			)
			var cooling: bool = (
				level.cooling[i]
				and not level.flowing[i]
				and level.water[i] >= 1
				and route
				and (i < 2 or level.cores_installed[i - 2])
			)
			_add(result, "pool%d" % i, "Freezing water crossing", level.frozen[i], cooling)
	else:
		if level.SAVE_LEVEL == 6 and level.launching:
			_add(
				result,
				"exit",
				"Launching skiff",
				clampf((level.props.exit.position.y - level.iso(level.EXIT).y) / 180, 0, 1),
				true
			)
		for i in range(level.controls.size()):
			var ready: bool = level._aux_ready(i)
			_add(
				result,
				"source%d" % i,
				"Melting ice source",
				level.source_melt[i],
				level.pump_modes[i] == 1 and (level.specialties[i] != "pressure" or ready)
			)
			_add(
				result,
				"basin%d" % i,
				"Filling water basin",
				level.basin_water[i],
				(
					level.source_melt[i] >= 1
					and level.sluices[i]
					and (level.specialties[i] != "routing" or ready)
				)
			)
			_add(
				result,
				"basin%d" % i,
				"Freezing water crossing",
				level.basin_ice[i],
				(
					level.pump_modes[i] == 2
					and not level.sluices[i]
					and level.basin_water[i] >= 1
					and ready
				)
			)
			if level.specialties[i] == "recovery":
				_add(
					result,
					"aux%d" % i,
					"Storing recovered heat",
					level.recovered[i],
					level.pump_modes[i] == 2 and ready and level.basin_ice[i] < 1
				)
			if (
				level.specialties[i] == "recovery"
				and level.recovered[i] >= .99
				and level.auxiliary[i] == 1
			):
				_add(
					result,
					"aux%d" % i,
					"Raising platform",
					level.props["aux%d" % i].visual_lift / 20,
					true
				)
	return result


func _draw_bars() -> void:
	var seen := {}
	for task: Dictionary in tasks:
		var screen: Vector2 = world_bars.get_global_transform_with_canvas() * task.at
		if not level.get_viewport_rect().grow(50).has_point(screen):
			continue
		var offset: int = seen.get(task.at, 0)
		seen[task.at] = offset + 1
		var prop = level.props[task.id]
		var height := 90.0
		if prop.get("display_height") != null:
			height = prop.display_height
		elif prop.get("kind") == "pool":
			height = 60
		elif prop.get("kind") == "brazier":
			height = 75
		var at: Vector2 = task.at + Vector2(-48, -height - 18 - offset * 31)
		world_bars.draw_style_box(_style(Color("234756")), Rect2(at, Vector2(96, 9)))
		world_bars.draw_style_box(
			_style(
				(
					Color("edb860")
					if "Melting" in task.text or "Warming" in task.text
					else Color("80d9e9")
				)
			),
			Rect2(at + Vector2.ONE, Vector2(94 * task.value, 7))
		)
		world_bars.draw_string_outline(
			FONT,
			at + Vector2(-15, -6),
			task.text + " %d%%" % [task.value * 100],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			4,
			Color("234756")
		)
		world_bars.draw_string(
			FONT,
			at + Vector2(-15, -6),
			task.text + " %d%%" % [task.value * 100],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("fff0cb")
		)


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
