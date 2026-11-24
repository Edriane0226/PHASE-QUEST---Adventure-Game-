extends SubViewportContainer
## A scripted illustration. Its own viewport contains artwork and inert controls.
signal finished
signal narrated(text: String)

const REGISTRY = preload("res://Scripts/Content/world_subregions.gd")
const FRAMES = preload("res://assets/characters/cast/explorer/frames.tres")
const HEATER_OFF = preload("res://assets/zones/zone_1/flat_v1/props/heater_off.tres")
const HEATER_ON = preload("res://assets/zones/zone_1/flat_v1/props/heater_on.tres")
const LESSON := [
	"Each water molecule has one oxygen atom and two hydrogen atoms. In ice, the molecules vibrate in fixed positions.",
	"The warmer heater transfers heat to the ice. Watch the molecules as melting begins.",
	"The molecules can move past one another. The atoms stay joined as H₂O.",
	"The ice is now liquid water. Its molecules stay close together and can move around."
]
const CONTROLS := [
	"Drag the round joystick in the direction you want to go. Lift your finger to stop.",
	"Hold Run with your other thumb to move faster. Release Run to return to walking.",
	"Approach equipment and tap its nearby action. Here, Activate heater transfers heat to ice. Fire is a separate control.",
	"Use your Checkpoint map to revisit an attuned checkpoint. In the connected campaign, open it from Pause."
]
const MAP := [
	"Open Pause and choose Checkpoint map. The illustration shows a sample route.",
	"Choose an attuned checkpoint in the current district. A gray pin remains locked.",
	"Confirm to travel. This demonstration moves its own marker.",
	"Close the map to return to the trail."
]
var viewport: SubViewport
var illustration: Node2D
var explorer: AnimatedSprite2D
var heater: Sprite2D
var molecules: Node2D
var touch_controls: Control
var touch_pointer: Control
var demo_interaction: Button
var elapsed := 0.0
var running := false
var phase := 0
var mode := "lesson"
var district := "Z1L1"
var checkpoint_ids: Array = []
var _paused := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge_material := ShaderMaterial.new()
	edge_material.shader = preload("res://assets/shaders/ui/scenario_edges.gdshader")
	material = edge_material
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(maxf(size.x,400),maxf(size.y,240))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)
	illustration = Node2D.new()
	viewport.add_child(illustration)
	illustration.draw.connect(_draw_example)
	explorer = AnimatedSprite2D.new()
	explorer.sprite_frames = FRAMES
	explorer.scale = Vector2.ONE * 0.4
	illustration.add_child(explorer)
	heater = Sprite2D.new()
	illustration.add_child(heater)
	viewport.size_changed.connect(_redraw)
	var overlay := CanvasLayer.new()
	overlay.layer = 60
	viewport.add_child(overlay)
	molecules = preload("res://Scripts/UI/water_molecules.gd").new()
	molecules.position = Vector2(165,145)
	molecules.visible = mode == "lesson"
	overlay.add_child(molecules)
	if mode == "play":
		touch_controls = preload("res://UI/HUD/TouchControls.tscn").instantiate()
		touch_controls.preview_on_desktop = true
		overlay.add_child(touch_controls)
		touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		touch_controls.set_enabled(true)
		touch_controls.get_node("Buttons/fire").modulate.a = 0.45
		demo_interaction = preload("res://UI/HUD/NearbyInteraction.tscn").instantiate()
		demo_interaction.text = "Activate heater"
		demo_interaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		demo_interaction.toggle_mode = true
		overlay.add_child(demo_interaction)
		touch_pointer = preload("res://Scripts/UI/mobile_tutorial_pointer.gd").new()
		overlay.add_child(touch_pointer)
	var row := REGISTRY.definition(district)
	checkpoint_ids = row.get("checkpoint_anchors",{}).keys()
	checkpoint_ids.sort()
	reset_scenario()

func replay() -> void:
	reset_scenario()

func toggle_playback() -> void:
	_paused = not _paused

func reset_scenario() -> void:
	elapsed = 0.0
	phase = 0
	running = true
	_paused = false
	molecules.liquid_fraction = 0.0
	molecules.clock = 0.0
	if is_instance_valid(touch_controls):touch_controls.reset_input()
	_redraw()
	_narrate()

func advance_dialogue() -> void:
	if not running:return
	if phase == 3:
		elapsed = 9.0
		_redraw()
		running = false
		finished.emit()
		return
	elapsed = _cuts()[phase]
	phase += 1
	_narrate()
	_redraw()

func _cuts() -> Array:
	return [2.0,3.0,6.0,9.0] if mode == "lesson" else [2.0,4.0,7.0,9.0]

func _narrate() -> void:
	var captions := LESSON if mode == "lesson" else CONTROLS if mode == "play" else MAP
	narrated.emit(captions[phase])

func _process(delta: float) -> void:
	if not running or _paused:return
	elapsed = minf(_cuts()[phase],elapsed+delta)
	if mode == "map" and elapsed >= _cuts()[phase]:
		if phase == 3:
			reset_scenario()
		else:
			advance_dialogue()
	_redraw()

func _map_visible() -> bool:
	return mode == "map" or (mode == "play" and phase == 3)

func _heater_active() -> bool:
	return phase >= (1 if mode == "lesson" else 2)

func _melt() -> float:
	return clampf((elapsed-(3.0 if mode == "lesson" else 4.0))/3.0,0.0,1.0)

func _redraw() -> void:
	if not is_instance_valid(molecules):return
	var area := Vector2(viewport.size)
	var show_map := _map_visible()
	heater.visible = not show_map
	explorer.visible = not show_map
	heater.position = area * Vector2(0.54,0.6)
	heater.texture = HEATER_ON if _heater_active() else HEATER_OFF
	heater.scale = Vector2.ONE * 52.0 / maxf(1.0,heater.texture.get_width())
	var distance := clampf(elapsed/4.0,0.0,1.0)
	if mode == "lesson":distance=clampf(elapsed/2.0,0.0,1.0)*0.5+_melt()*0.5
	explorer.position = (area*Vector2(0.29,0.72)).lerp(area*Vector2(0.61,0.67),distance)
	explorer.play("run_south_east" if phase < 2 else "idle_south_east")
	molecules.liquid_fraction = _melt()
	if is_instance_valid(touch_controls):_present_controls()
	illustration.queue_redraw()

func _present_controls() -> void:
	touch_controls.visible = not _map_visible()
	touch_pointer.visible = touch_controls.visible
	touch_controls.active_finger = 0 if phase<2 else -1
	touch_controls.base_position = touch_controls.get_node("Joystick").get_global_rect().get_center()
	touch_controls.thumb_offset = Vector2(36,12)
	touch_controls.action_fingers.clear()
	touch_controls.interact_available = phase == 2
	if phase == 1:touch_controls.action_fingers[1] = "sprint"
	demo_interaction.visible = phase == 2
	demo_interaction.reset_size()
	demo_interaction.position = (heater.position-Vector2(72,82)).clamp(Vector2(8,20),Vector2(viewport.size)-demo_interaction.size)
	demo_interaction.set_pressed_no_signal(phase == 2)
	if phase == 0:touch_pointer.target = touch_controls.base_position+touch_controls.thumb_offset
	elif phase == 1:touch_pointer.target = touch_controls.get_node("Buttons/sprint").get_global_rect().get_center()
	else:touch_pointer.target = demo_interaction.get_global_rect().get_center()
	touch_controls.get_node("Joystick/Thumb").position = touch_controls._thumb_home+touch_controls.thumb_offset
	for action in touch_controls.button_rects:
		touch_controls.get_node("Buttons/"+action).set_pressed_no_signal(action in touch_controls.action_fingers.values())
	touch_controls.queue_redraw()

func _draw_example() -> void:
	var area := Vector2(viewport.size)
	illustration.draw_rect(Rect2(Vector2.ZERO,area),Color("e6ede7"))
	if _map_visible():
		_draw_map(area)
		return
	var ground := PackedVector2Array([area*Vector2(0.06,0.77),area*Vector2(0.51,0.32),area*Vector2(0.95,0.57),area*Vector2(0.66,0.94)])
	illustration.draw_colored_polygon(ground,Color("a9c4bc"))
	illustration.draw_line(area*Vector2(0.23,0.78),area*Vector2(0.77,0.57),Color("e7d7a9"),14.0,true)
	var ice := area*Vector2(0.71,0.6)
	var water := PackedVector2Array([ice+Vector2(-52,8),ice+Vector2(0,-18),ice+Vector2(52,8),ice+Vector2(0,34)])
	illustration.draw_colored_polygon(water,Color("73adbf"))
	var rise := lerpf(43.0,0.0,_melt())
	var face := PackedVector2Array([water[0],water[3],water[2],water[2]-Vector2(0,rise),water[3]-Vector2(0,rise),water[0]-Vector2(0,rise)])
	if rise > 0.5:
		illustration.draw_colored_polygon(face,Color("95d6e5"))
		illustration.draw_colored_polygon(Transform2D(0,Vector2(0,-rise))*water,Color("d5f7ff"))

func _draw_map(area: Vector2) -> void:
	var font := ThemeDB.fallback_font
	illustration.draw_string(font,Vector2(20,36),"Checkpoint map · example route",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("263c40"))
	var route := PackedVector2Array()
	var count := maxi(2,checkpoint_ids.size())
	for index in count:
		route.append(area*Vector2(lerpf(0.14,0.86,float(index)/float(count-1)),0.57-0.13*float(index%2)))
	illustration.draw_polyline(route,Color("8f9e83"),6.0,true)
	for index in checkpoint_ids.size():
		var at := route[index]
		illustration.draw_circle(at,12.0,Color("467f81") if index<2 else Color("8b9492"),true,-1.0,true)
		illustration.draw_string(font,at+Vector2(-11,36),checkpoint_ids[index],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("263c40"))
	var arrival := 1 if phase >= 2 else 0
	illustration.draw_circle(route[arrival]-Vector2(0,24),6,Color("ce7a4c"),true,-1.0,true)
	illustration.draw_string(font,Vector2(20,area.y-20),"Attuned pins can be selected",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("263c40"))
