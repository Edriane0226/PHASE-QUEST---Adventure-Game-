extends Control
## Opt-in shared presentation. Model is read-only; signals request existing actions only.
signal action_requested(action: String)
signal mode_requested(mode: String)
signal selector_canceled
signal movement_preview(value: Vector2)
signal hold_preview(action: String, held: bool)
const PROGRESS=preload("res://Scripts/Content/phase_device_progress.gd")
const BUTTON=preload("res://Scripts/UI/WorldHUD/hud_action.gd")
const MINIMAP=preload("res://Scripts/UI/WorldHUD/hud_minimap.gd")
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const PORTRAIT=preload("res://assets/ui/hud/r3_v1/portrait_face.tres")
const WARNING=preload("res://assets/ui/hud/r3_v1/warning.svg")
const LOCK_ICON=preload("res://assets/ui/hud/r3_v1/lock.svg")
const ICON_ROOT="res://assets/ui/hud/r3_v1/"
const NAMES={"thermal":"Thermal","cryo":"Cryo","vacuum":"Vacuum","pressure":"Pressure"}
const COLORS={"thermal":Color("b77c35"),"cryo":Color("388da9"),"vacuum":Color("497d72"),"pressure":Color("8765a7")}
const LOCKS={"thermal":"Z1L1 · Melting","cryo":"Z1L3 · Freezing","vacuum":"Z3L1 · Sublimation","pressure":"Z3L3 · Deposition"}
@export var preview_input:=false
var model: Dictionary={}
var device: Dictionary=PROGRESS.defaults()
var controls: Dictionary={}
var labels: Dictionary={}
var rects: Dictionary={}
var safe_override:=Rect2()
var safe:=Rect2()
var minimap: Control
var joystick_value:=Vector2.ZERO
var pointers: Dictionary={}
var preview_mode:=""
var supported:=true
var unit:=1.0
var interaction_key:=""
var _context_token:=""
var _has_focus:=true
var _suspended:=false
var visible_quest_count:=0
var _layout_signature:=0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id in ["guides","pause","run","jump","fire","thermal","cryo","vacuum","pressure","selected","context"]:
		var view:=BUTTON.new();view.name=id.capitalize();view.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.focus_mode=Control.FOCUS_NONE
		view.caption=NAMES.get(id,{"guides":"Guides","pause":"Pause","run":"Run","jump":"Jump","fire":"Fire","context":"Use"}.get(id,""))
		view.shape="hex" if id=="selected" else ("square" if id in ["guides","pause","context"] else "circle")
		if id in NAMES:
			var glyph:=AtlasTexture.new();glyph.atlas=load("res://assets/ui/phase_dial/v1/"+id+"_icon.svg");glyph.region=Rect2(105,105,46,46);view.glyph=glyph;view.tint=COLORS[id]
		elif id=="fire":
			var glyph:=AtlasTexture.new();glyph.atlas=load("res://assets/ui/phase_dial/v1/thermal_icon.svg");glyph.region=Rect2(105,105,46,46);view.glyph=glyph
		elif id=="run":view.glyph=load("res://assets/ui/icons/mobile_sprint.svg")
		elif id!="selected":view.glyph=load(ICON_ROOT+{"context":"interact"}.get(id,id)+".svg")
		add_child(view);controls[id]=view
	for id in ["name","hp","warmth","quest_title","quest_0","quest_1","quest_2","tutorial","rotate","feedback"]:
		var label:=Label.new();label.name=id.capitalize();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_override("font",FONT);label.add_theme_color_override("font_color",Color("fff8df"));label.add_theme_color_override("font_outline_color",Color("203127"));label.add_theme_constant_override("outline_size",2);label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(label);labels[id]=label
	for id in ["hp","warmth","rotate","feedback"]:labels[id].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for id in ["quest_0","quest_1","quest_2","tutorial"]:labels[id].autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;labels[id].max_lines_visible=2
	labels.tutorial.add_theme_color_override("font_color",Color("26362c"));labels.tutorial.add_theme_constant_override("outline_size",0);labels.tutorial.max_lines_visible=3
	minimap=MINIMAP.new();minimap.name="Minimap";add_child(minimap)
	resized.connect(reflow)
	present({})

func computed_safe() -> Rect2:
	var area:=Rect2(Vector2.ZERO,size)
	if safe_override.has_area():return area.intersection(safe_override).grow(-8)
	if OS.has_feature("android"):
		var display:=DisplayServer.get_display_safe_area();var inverse:=get_viewport().get_screen_transform().affine_inverse()
		var usable:=Rect2(inverse*Vector2(display.position),inverse*Vector2(display.end)-inverse*Vector2(display.position))
		if usable.has_area():area=area.intersection(usable)
	return area.grow(-8)

func place(id: String,at: Vector2,extent: Vector2) -> void:
	rects[id]=Rect2(at,extent)
	if controls.has(id):controls[id].position=at if at.is_finite() else Vector2.ZERO;controls[id].size=extent
	if labels.has(id):labels[id].position=at if at.is_finite() else Vector2.ZERO;labels[id].size=extent

func reflow() -> void:
	if not is_node_ready():return
	safe=computed_safe()
	var signature:=hash([safe,size,mini(2 if safe.size.y<440 else 3,model.get("quests",[]).size())])
	if signature!=_layout_signature:reset_preview();_layout_signature=signature
	rects.clear()
	supported=safe.size.x>=540 and safe.size.y>=300 and safe.size.x>safe.size.y
	unit=clampf(minf(safe.size.x/1280,safe.size.y/720),.45,1.5)
	var left:=safe.position.x;var top:=safe.position.y;var right:=safe.end.x;var bottom:=safe.end.y
	place("identity",Vector2(left,top),Vector2(maxf(226,330*unit),maxf(82,110*unit)))
	var identity: Rect2=rects.identity;var diamond:=identity.size.y
	place("name",identity.position+Vector2(diamond*.85,1),Vector2(identity.size.x-diamond*.85-12,22*maxf(.65,unit)))
	place("hp",identity.position+Vector2(diamond*.85,identity.size.y*.35),Vector2(identity.size.x-diamond*.85-8,identity.size.y*.25))
	place("warmth",identity.position+Vector2(diamond*.85,identity.size.y*.66),Vector2(identity.size.x-diamond*.85-20,identity.size.y*.25))
	visible_quest_count=mini(2 if safe.size.y<440 else 3,model.get("quests",[]).size())
	var qrows: int=visible_quest_count
	var row_h:=maxf(38,ceilf(FONT.get_height(maxi(12,roundi(15*unit)))*2+6))
	labels.quest_title.text=str(model.get("quest_title","Current objective"))
	if model.get("quests",[]).size()>visible_quest_count:labels.quest_title.text+=" (+%d)"%(model.quests.size()-visible_quest_count)
	place("quest",Vector2(left,identity.end.y+8),Vector2(maxf(200,300*unit),maxf(52,30+qrows*row_h)))
	place("quest_title",rects.quest.position+Vector2(27,7),Vector2(rects.quest.size.x-36,20))
	for i in 3:place("quest_"+str(i),rects.quest.position+Vector2(28,30+i*row_h),Vector2(rects.quest.size.x-36,row_h))
	var map_d:=maxf(94,180*unit);var square:=maxf(44,64*unit)
	place("minimap",Vector2(right-map_d,top),Vector2.ONE*map_d);minimap.position=rects.minimap.position;minimap.size=rects.minimap.size
	place("pause",Vector2(right-map_d-10-square,top),Vector2.ONE*square)
	place("guides",Vector2(rects.pause.position.x-10-square,top),Vector2.ONE*square)
	var stick_d:=maxf(96,164*unit);place("joystick",Vector2(left+4,bottom-stick_d-4),Vector2.ONE*stick_d)
	var slot:=maxf(52,68*unit);var gap:=maxf(8,10*unit);var width:=3*slot+2*gap;var cluster:=Vector2(safe.get_center().x-width/2,bottom-(2*slot+gap+6))
	place("vacuum",cluster+Vector2(width*.32-slot/2,0),Vector2.ONE*slot)
	place("pressure",cluster+Vector2(width*.68-slot/2,0),Vector2.ONE*slot)
	place("thermal",cluster+Vector2(0,slot+gap),Vector2.ONE*slot)
	place("selected",cluster+Vector2(width/2-slot/2-3,slot+gap-3),Vector2.ONE*(slot+6))
	place("cryo",cluster+Vector2(width-slot,slot+gap),Vector2.ONE*slot)
	var fire:=maxf(66,100*unit);var jump:=maxf(44,74*unit);var run:=maxf(44,68*unit)
	place("fire",Vector2(right-fire,bottom-fire),Vector2.ONE*fire)
	place("jump",Vector2(right-fire-12-jump,bottom-jump),Vector2.ONE*jump)
	place("run",Vector2(right-fire/2-run/2,bottom-fire-12-run),Vector2.ONE*run)
	place("feedback",Vector2(cluster.x-20,cluster.y-24),Vector2(width+40,22))
	for id in labels:labels[id].add_theme_font_size_override("font_size",maxi(12,roundi((18 if id in ["name","hp","warmth"] else 15)*unit)))
	for id in controls:controls[id].label_size=maxi(11,roundi(16*unit))
	# Context/tutorial seek free screen space, never overwrite fixed HUD controls.
	var target: Vector2=model.get("context_at",safe.get_center())
	var context_size:=Vector2(maxf(108,150*unit),maxf(44,52*unit))
	place("context",free_position(context_size,target+Vector2(18,12)),context_size)
	var bubble_size:=Vector2(maxf(166,280*unit),maxf(72,92*unit))
	place("bubble",free_position(bubble_size,target-bubble_size-Vector2(18,12),true),bubble_size)
	place("tutorial",rects.bubble.position+Vector2(10,8),rects.bubble.size-Vector2(20,16))
	place("rotate",safe.position,Vector2(maxf(0,safe.size.x),maxf(0,safe.size.y)))
	_refresh_visibility();queue_redraw()

func occupied() -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for id in ["identity","quest","guides","pause","minimap","joystick","thermal","cryo","vacuum","pressure","selected","run","jump","fire"]:
		if id=="quest" and model.get("quests",[]).is_empty():continue
		result.append(rects[id])
	return result

func free_position(extent: Vector2,preferred: Vector2,avoid_context:=false) -> Vector2:
	var blocked:=occupied()
	if avoid_context and not model.get("context","").is_empty():blocked.append(rects.context)
	var candidates: Array[Vector2]=[preferred,Vector2(safe.get_center().x-extent.x/2,safe.position.y+92),safe.get_center()-extent/2]
	# Exact obstacle edges preserve narrow usable bands that an8pxgrid can miss.
	var xs: Array[float]=[safe.position.x,safe.end.x-extent.x,preferred.x]
	var ys: Array[float]=[safe.position.y,safe.end.y-extent.y,preferred.y]
	for obstacle: Rect2 in blocked:
		xs.append_array([obstacle.position.x-extent.x-4,obstacle.end.x+4]);ys.append_array([obstacle.position.y-extent.y-4,obstacle.end.y+4])
	for y: float in ys:
		for x: float in xs:candidates.append(Vector2(x,y))
	for y in range(int(safe.position.y),int(safe.end.y-extent.y)+1,8):
		for x in range(int(safe.position.x),int(safe.end.x-extent.x)+1,8):candidates.append(Vector2(x,y))
	for at in candidates:
		at=at.clamp(safe.position,safe.end-extent);var area:=Rect2(at,extent)
		if not blocked.any(func(obstacle):return area.grow(3).intersects(obstacle)):return at
	return Vector2(INF,INF) # Visibility hides unplaceable optional content; caller can defer tutorial.

func present(value: Dictionary) -> void:
	var old_selected: String=device.selected_mode
	model=value.duplicate(true);device=PROGRESS.normalize(value.get("device",{}))
	interaction_key=str(value.get("context_key",""))
	labels.name.text=str(value.get("name","Explorer"))
	if labels.name.text.strip_edges().is_empty():labels.name.text="Explorer"
	labels.name.tooltip_text=labels.name.text
	var hp:=clampf(float(value.get("hp",10)),0,10);var warmth:=clampf(float(value.get("warmth",100)),0,100)
	labels.hp.text="%d/10"%ceili(hp);labels.warmth.text="Warmth %d%%"%ceili(warmth)
	labels.quest_title.text=str(value.get("quest_title","Current objective"));labels.quest_title.tooltip_text=labels.quest_title.text
	var quests: Array=value.get("quests",[])
	for i in 3:
		labels["quest_"+str(i)].text=str(quests[i].get("text","")) if i<quests.size() else ""
		labels["quest_"+str(i)].tooltip_text=labels["quest_"+str(i)].text
	labels.tutorial.text=str(value.get("tutorial",""));labels.feedback.text=str(value.get("feedback",""))
	for mode: String in NAMES:
		controls[mode].locked=not device.unlocked_modes.has(mode);controls[mode].selected=device.selected_mode==mode
		controls[mode].tooltip_text=NAMES[mode]+(" · Learn "+LOCKS[mode] if controls[mode].locked else " · Select mode")
		controls[mode].reduced=bool(value.get("reduced_effects",false));controls[mode].queue_redraw()
	controls.selected.locked=device.selected_mode.is_empty();controls.selected.glyph=controls[device.selected_mode].glyph if not device.selected_mode.is_empty() else null
	controls.selected.tint=COLORS.get(device.selected_mode,Color("4b5e45"));controls.selected.tooltip_text="Selected: "+NAMES.get(device.selected_mode,"None")+" · Cancel selection preview"
	controls.context.caption=str(value.get("context",""));controls.context.disabled=not bool(value.get("context_enabled",true))
	for id in ["run","jump","fire"]:controls[id].disabled=not bool(value.get(id+"_enabled",true))
	controls.fire.disabled=controls.fire.disabled or device.selected_mode.is_empty()
	minimap.present(value.get("minimap",{}));reflow()
	if bool(model.get("modal",false)) or old_selected!=device.selected_mode:reset_preview()
	else:
		for index in pointers.keys():
			var id: String=pointers[index]
			if id=="joystick":continue
			if not controls[id].visible or controls[id].disabled or (id=="context" and _context_token!=interaction_key):route_touch(index,Vector2.ZERO,false,true)

func _refresh_visibility() -> void:
	var modal:=bool(model.get("modal",false));var active:=supported and not modal
	for id in controls:controls[id].visible=active;controls[id].queue_redraw()
	for id in labels:labels[id].visible=active
	labels.rotate.visible=not supported;labels.rotate.text="Rotate device to landscape" if safe.size.x<safe.size.y else "Larger landscape viewport required"
	labels.rotate.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	minimap.visible=active
	for i in 3:labels["quest_"+str(i)].visible=active and i<visible_quest_count
	labels.quest_title.visible=active and not model.get("quests",[]).is_empty()
	controls.context.visible=active and not model.get("context","").is_empty() and rects.context.position.is_finite()
	labels.tutorial.visible=active and not labels.tutorial.text.is_empty() and rects.bubble.position.is_finite()

func reset_preview() -> void:
	for action in ["fire","run"]:
		if pointers.values().has(action):hold_preview.emit(action,false)
	pointers.clear();joystick_value=Vector2.ZERO;preview_mode="";_context_token=""
	for view in controls.values():view.set_pressed_no_signal(false);view.visual_override="";view.queue_redraw()
	movement_preview.emit(Vector2.ZERO);queue_redraw()

func _request(id: String) -> void:
	if id in NAMES:
		if controls[id].locked:labels.feedback.text="Learn "+LOCKS[id];return
		mode_requested.emit(id) # Do not mutate committed selection; adapter must confirm/save it.
	elif id=="selected":preview_mode="";labels.feedback.text="";selector_canceled.emit()
	elif id=="context":action_requested.emit("interact")
	else:action_requested.emit(id)

func route_touch(index: int,point: Vector2,pressed: bool,canceled:=false) -> bool:
	if not supported or bool(model.get("modal",false)) or not _has_focus or _suspended or get_tree().paused:reset_preview();return false
	if pointers.has(index):
		var id: String=pointers[index]
		if pressed and not canceled:return true
		pointers.erase(index)
		if id=="joystick":joystick_value=Vector2.ZERO;movement_preview.emit(joystick_value);queue_redraw();return true
		controls[id].set_pressed_no_signal(false);controls[id].queue_redraw()
		if id in ["fire","run"]:hold_preview.emit(id,false)
		elif not canceled and controls[id]._has_point(point-controls[id].position) and (id!="context" or _context_token==interaction_key):_request(id)
		return true
	if not pressed or canceled:return false
	if rects.joystick.has_point(point) and not pointers.values().has("joystick"):
		pointers[index]="joystick";route_drag(index,point);return true
	for id: String in controls:
		var button: Button=controls[id]
		if not button.visible or button.disabled or pointers.values().has(id) or not button._has_point(point-button.position):continue
		pointers[index]=id;button.set_pressed_no_signal(true);button.queue_redraw()
		if id in ["fire","run"]:hold_preview.emit(id,true)
		if id in NAMES:preview_mode=id
		if id=="context":_context_token=interaction_key
		return true
	return false

func route_drag(index: int,point: Vector2) -> bool:
	if not pointers.has(index):return false
	if pointers[index]=="joystick":
		joystick_value=((point-rects.joystick.get_center())/(rects.joystick.size.x*.32)).limit_length()
		if joystick_value.length()<.12:joystick_value=Vector2.ZERO
		movement_preview.emit(joystick_value);queue_redraw()
	return true

func _input(event: InputEvent) -> void:
	if not preview_input:return
	# A native touch owns its own ID. Godot's emulated mouse must not claim it first.
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:return
	var used:=false
	if event is InputEventScreenTouch:used=route_touch(event.index,event.position,event.pressed,event.canceled)
	elif event is InputEventScreenDrag:used=route_drag(event.index,event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:used=route_touch(-2,event.position,event.pressed)
	elif event is InputEventMouseMotion:
		used=route_drag(-2,event.position)
		if not used:
			for button in controls.values():button.visual_override="hovered" if not button.locked and not button.disabled and button.visible and button._has_point(event.position-button.position) else "";button.queue_redraw()
	if used:get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_has_focus=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_has_focus=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:_suspended=true
	elif what==NOTIFICATION_APPLICATION_RESUMED:_suspended=false
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]:reset_preview()

func _process(_delta: float) -> void:
	if get_tree().paused and not pointers.is_empty():reset_preview()

func polygon(points: Array,at: Vector2,color: Color) -> void:
	var p:=PackedVector2Array()
	for point: Vector2 in points:p.append(point+at)
	draw_colored_polygon(p,color);p.append(p[0]);draw_polyline(p,Color("d9dfc2"),1.5,true)

func panel(area: Rect2,cream:=false) -> void:
	var style:=StyleBoxFlat.new();style.bg_color=Color("f5e9c2") if cream else Color(.11,.18,.12,.83);style.border_color=Color("bbbe9c");style.set_border_width_all(2);style.set_corner_radius_all(10);style.shadow_color=Color(0,0,0,.25);style.shadow_size=4;draw_style_box(style,area)

func _draw() -> void:
	if rects.is_empty() or not supported or bool(model.get("modal",false)):return
	var identity: Rect2=rects.identity;var at:=identity.position;var d:=identity.size.y
	for id in ["name","hp","warmth"]:
		var area: Rect2=rects[id];var h:=area.size.y
		var color:=Color("334c32") if id=="name" else Color("641e24") if id=="hp" else Color("153e51")
		polygon([Vector2(-5,0),Vector2(area.size.x-9,0),Vector2(area.size.x,h/2),Vector2(area.size.x-9,h),Vector2(-5,h),Vector2(-12,h/2)],area.position,color)
		if id!="name":
			var fraction:=clampf(float(model.get(id,10 if id=="hp" else 100))/(10 if id=="hp" else 100),0,1)
			var fill:=Rect2(area.position+Vector2(0,3),Vector2((area.size.x-12)*fraction,maxf(1,h-6)));draw_rect(fill,Color("c63842") if id=="hp" else Color("21a7ce"));draw_line(fill.position,Vector2(fill.end.x,fill.position.y),Color(1,1,1,.3),2,true)
	var diamond:=PackedVector2Array([at+Vector2(d*.5,0),at+Vector2(d,d*.5),at+Vector2(d*.5,d),at+Vector2(0,d*.5)])
	draw_colored_polygon(diamond,Color("182a24"));diamond.append(diamond[0]);draw_polyline(diamond,Color("e2e5cb"),3,true)
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	for p in [Vector2(.5,.09),Vector2(.91,.5),Vector2(.5,.91),Vector2(.09,.5)]:points.append(at+p*d);uv.append(p)
	draw_polygon(points,PackedColorArray([Color.WHITE]),uv,PORTRAIT)
	if not model.get("quests",[]).is_empty():
		panel(rects.quest);draw_texture_rect(WARNING,Rect2(rects.quest.position+Vector2(7,7),Vector2(16,16)),false)
		for i in visible_quest_count:
			var area: Rect2=rects["quest_"+str(i)];var box:=Rect2(area.position+Vector2(-19,3),Vector2(13,13));draw_rect(box,Color("e2e7d1"),false,1.5)
			var state: String=model.quests[i].get("state","pending")
			if state=="done":draw_polyline(PackedVector2Array([box.position+Vector2(2,7),box.position+Vector2(5,10),box.position+Vector2(12,2)]),Color("f8e9b1"),2,true)
			elif state=="blocked":draw_texture_rect(LOCK_ICON,box,false)
			elif state=="active":draw_circle(box.get_center(),3,Color("f6d788"))
	var stick: Rect2=rects.joystick;var center:=stick.get_center();var radius:=stick.size.x/2
	draw_circle(center,radius-2,Color(.14,.23,.14,.64));draw_arc(center,radius-2,0,TAU,72,Color("e3e7ce"),2,true);draw_arc(center,radius-7,0,TAU,72,Color("768b67"),1,true)
	for i in 4:
		var arrow:=PackedVector2Array()
		for p in [Vector2(0,-radius+12),Vector2(-6,-radius+23),Vector2(6,-radius+23)]:arrow.append(center+p.rotated(i*PI/2))
		draw_colored_polygon(arrow,Color("fff6d6"))
	draw_circle(center+joystick_value*radius*.32,radius*.27,Color("d7dec6"));draw_arc(center+joystick_value*radius*.32,radius*.27,0,TAU,48,Color("f6f3d9"),2,true)
	if labels.tutorial.visible:
		panel(rects.bubble,true);var bubble: Rect2=rects.bubble
		polygon([Vector2(-8,0),Vector2(8,0),Vector2(0,10)],Vector2(bubble.get_center().x,bubble.end.y),Color("f5e9c2"))
