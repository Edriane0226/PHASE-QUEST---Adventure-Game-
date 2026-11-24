extends Control
## Recorded teaching examples with local illustrations and no campaign services.
signal narrated(text: String)

const PROPS := "res://assets/zones/zone_1/flat_v1/props/"
const LESSONS = preload("res://Scripts/UI/mechanic_visual.gd").LESSONS
const ART := {
	"melting": ["ice_cracked", "ice_cracked", "inspection_tool"],
	"fuel_air": ["wood", "fan_housing", "heater_on"],
	"reflection": ["mirror_1", "mirror_3", "receiver_on"],
	"warmth": ["heater_off", "heater_on", "camp"],
	"coat": ["snow_heather", "camp", "lantern"],
	"crystals": ["ice_cracked", "inspection_tool", "@crystal"],
	"fuel": ["wood", "wood", "heater_off"],
	"fan_blades": ["fan_blade", "fan_housing", "heater_on"],
	"notes": ["sign", "sign", "waypoint_on"],
	"professor": ["@professor", "@professor", "@professor"],
	"altar": ["waypoint_off", "inspection_tool", "waypoint_on"],
	"exit": ["gate_closed", "@crystal", "gate_open"],
	"movement": ["sign", "jump_log", "waypoint_on"],
}
const CAPTIONS := {
	"melting": ["Solid ice blocks the path.", "Select Thermal. Aim at the ice and hold Fire to transfer heat into it.", "The ice becomes liquid water. The water stays the same substance."],
	"movement": ["Use the joystick to follow the trail.", "Hold Run to move faster and use Jump to cross a marked gap.", "Approach equipment to reveal its nearby action."],
	"exit": ["The exit checks the district objectives.", "Finish the puzzles and collect all six crystals.", "Use the exit, then follow the trail to the next district."],
}

var topic := "melting"
var elapsed := 0.0
var playing := true
var step := 0
var textures: Array[Texture2D] = []

static func supports(id: String) -> bool:
	return ART.has(id)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for prop: String in ART[topic]:
		match prop:
			"@crystal": textures.append(preload("res://assets/zones/zone_1/smooth_v1/effects/ice_crystal_7.tres"))
			"@professor": textures.append(load(_professor_portrait()))
			_: textures.append(load(PROPS + prop + ".tres"))
	replay()

func _professor_portrait() -> String:
	var path := "res://assets/characters/professors/r3_v1/cast_registry.json"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return catalog.actors.professor_z1.portraits.professor_z1_portrait_explaining

func replay() -> void:
	elapsed = 0.0
	playing = true
	_show_step(0)

func toggle_playback() -> void:
	playing = not playing

func _process(delta: float) -> void:
	if not playing:return
	elapsed = fmod(elapsed + delta, 10.5)
	var next := int(elapsed / 3.5)
	if next != step:_show_step(next)
	if topic == "melting" or topic == "reflection":queue_redraw()

func _show_step(next: int) -> void:
	step = next
	var lines: Array = CAPTIONS.get(topic, LESSONS[topic][1])
	narrated.emit(str(lines[step]).trim_prefix("BEFORE: ").trim_prefix("DO: ").trim_prefix("RESULT: "))
	queue_redraw()

func _draw() -> void:
	if textures.size() != 3:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e6ede7"))
	var centers := [size * Vector2(.2,.54), size * Vector2(.5,.54), size * Vector2(.8,.54)]
	var extent := minf(size.x * .22, size.y * .56)
	draw_line(centers[0],centers[2],Color("acbba9"),3,true)
	for index in centers.size():
		var at: Vector2 = centers[index]
		draw_circle(at,extent*.58,Color("cfdfd4") if index == step else Color("dfe7df"),true,-1.0,true)
		if topic == "melting" and index == 2:
			draw_set_transform(at,0,Vector2(1,.38))
			draw_circle(Vector2.ZERO,extent*.45,Color("7eb9c8"),true,-1.0,true)
			draw_set_transform(Vector2.ZERO)
		else:
			var texture := textures[index]
			if texture == null:continue
			var fit := texture.get_size() * (extent / maxf(texture.get_width(),texture.get_height()))
			draw_texture_rect(texture,Rect2(at - fit*.5,fit),false,Color.WHITE if index <= step else Color(1,1,1,.55))
	if step == 1 and topic in ["melting","reflection"]:
		var tint := Color("c87d43") if topic == "melting" else Color("ddb752")
		var end: Vector2 = centers[0].lerp(centers[1],fmod(elapsed,1.35)/1.35)
		draw_line(centers[0],end,tint,4,true)
