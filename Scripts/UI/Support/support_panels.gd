extends Control
## Shared opt-in modal presentation. Emits intents; never acknowledges/saves/awards/travels.
signal intent_requested(panel_id: String,action: String,payload: Dictionary)
const STYLE=preload("res://Scripts/UI/Support/support_style.gd")
const SCIENCE=preload("res://Scripts/UI/Support/science_card.gd")
const BADGE_ICON=preload("res://Scripts/UI/achievement_icon.gd")
const BADGES=preload("res://Scripts/Autoload/achievement_registry.gd")
const TEACHING=preload("res://Scripts/World/Learning/professor_content.gd")
const RANKS=preload("res://assets/ui/ranks/rank_badges.png")
var catalog: Dictionary={}
var portraits: Dictionary={}
var model: Dictionary={}
var panel_id:=""
var revision:=0
var safe_override:=Rect2()
var card: PanelContainer
var column: VBoxContainer
var header: HBoxContainer
var title: Label
var close_button: Button
var scroll: ScrollContainer
var body: VBoxContainer
var footer: GridContainer
var science: Control
var choices: Dictionary={}
var chosen_id:=""
var buttons: Array[Button]=[]
var text_views: Array[Control]=[]
var action_buttons: Dictionary={}
var search: LineEdit
var status: Label
var safe:=Rect2()
var portrait_views: Array[TextureRect]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("teaching_modal") # Retain original toast-deferral contract when this view is bound.
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/support/r3_v1/panels.json"))
	portraits=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/support/r3_v1/portrait-index.json"))
	var shade:=ColorRect.new();shade.name="ModalShade";shade.color=Color(.07,.12,.09,.74);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card=PanelContainer.new();card.name="SharedCard";add_child(card)
	column=VBoxContainer.new();column.add_theme_constant_override("separation",8);card.add_child(column)
	header=HBoxContainer.new();header.add_theme_constant_override("separation",12);column.add_child(header)
	title=Label.new();title.name="PanelTitle";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;header.add_child(title)
	close_button=Button.new();close_button.name="Close";close_button.text="Close";close_button.custom_minimum_size=Vector2(72,44);header.add_child(close_button)
	close_button.pressed.connect(func():_emit(str(model.get("close_action","close")),{},revision))
	column.add_child(HSeparator.new())
	scroll=ScrollContainer.new();scroll.name="ContentScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;column.add_child(scroll)
	body=VBoxContainer.new();body.name="Body";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);scroll.add_child(body)
	footer=GridContainer.new();footer.name="Actions";footer.add_theme_constant_override("h_separation",8);footer.add_theme_constant_override("v_separation",6);column.add_child(footer)
	resized.connect(reflow);hide()

func label(text: String,parent: Node,kind:="body") -> Label:
	var view:=Label.new();view.text=text;view.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view.add_theme_font_size_override("font_size",(22 if kind=="heading" else 16)+(3 if model.get("large_text",false) else 0));view.add_theme_color_override("font_color",STYLE.INK)
	parent.add_child(view);text_views.append(view);return view

func attach_guide_demo(preview: Control) -> void:
	var token := revision
	if is_instance_valid(preview):
		if is_instance_valid(science): science.hide()
		preview.process_mode = Node.PROCESS_MODE_ALWAYS
		preview.custom_minimum_size = Vector2(0,220)
		var narration := label("",body)
		preview.narrated.connect(func(words): narration.text = words)
		body.add_child(preview)
		body.move_child(preview,narration.get_index())
		for caption in ["Replay demonstration","Pause / Play"]:
			var control := Button.new()
			control.text = caption
			control.custom_minimum_size.y = 48
			body.add_child(control)
			var replay: bool = caption == "Replay demonstration"
			control.pressed.connect(func():
				if not visible or revision != token or not is_instance_valid(preview): return
				if replay: preview.replay()
				else: preview.toggle_playback())
		return
	if not is_instance_valid(science): return
	for process: String in model.get("guide_processes",[]):
		var control := Button.new()
		control.text = "Replay " + process.capitalize()
		control.custom_minimum_size.y = 48
		body.add_child(control)
		control.pressed.connect(func():
			if visible and revision == token:
				science.present(process,0,model.get("large_text",false))
				status.text = "Step 1 of 3 · demonstration"
				status.show())
	button("Previous step","demo_previous",body)
	button("Next step","demo_next",body)

static func journal_model(profile: Node) -> Dictionary:
	var rows: Array = []
	for row in profile.WORLD_SAVE.REGISTRY.definitions():
		if profile.is_level_complete(row.zone_id,row.level):
			rows.append({"title":row.name,"text":"Completed district"})
	for record: Dictionary in profile.guide_records().values():
		var district := TEACHING.REGISTRY.definition(TEACHING.region_for(record.zone,record.level))
		rows.append({"title":TEACHING.guide(record).title,"text":"Guide · " + district.get("name","")})
	var badges: Array = []
	var achievements: Dictionary = profile.achievement_state()
	for item: Dictionary in BADGES.DEFINITIONS:
		badges.append({"id":item.id,"earned":achievements.unlocks.has(item.id),"count":BADGES.progress_count(item,achievements)})
	var stars: int = profile.total_stars()
	return {"title":"Journal","body":"%s · %d stars" % [profile.rank_name(),stars],
		"rows":rows,"badges":badges,"rank_index":0 if stars <= 6 else 1 if stars <= 12 else 2}

func button(text: String,id: String,parent: Node,value: Variant=null,enabled:=true) -> Button:
	var view:=Button.new();view.text=text;view.name="Intent_"+id.validate_node_name();view.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;view.custom_minimum_size=Vector2(0,48);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.disabled=not enabled
	var token:=revision
	view.pressed.connect(func():
		if id=="choose_answer":_choose(str(value),token)
		_emit(id,{"value":value},token))
	parent.add_child(view);buttons.append(view);return view

func _emit(action: String,payload: Dictionary,token: int) -> void:
	if not visible or token!=revision:return
	if action_buttons.has(action) and action_buttons[action].disabled:return
	if action=="close" and not model.get("can_close",true):return
	if action in ["demo_replay","demo_next","demo_previous"] and is_instance_valid(science):
		var next:=0 if action=="demo_replay" else clampi(science.stage+(-1 if action=="demo_previous" else 1),0,2)
		science.present(science.process,next,model.get("large_text",false),model.get("reduced_motion",true));status.text="Step %d of 3 · demonstration only"%(next+1);status.show()
	payload=payload.duplicate(true);payload.selected_choice=chosen_id;payload.context_key=model.get("context_key","");payload.view_revision=revision
	intent_requested.emit(panel_id,action,payload)

func open_panel(id: String,override: Dictionary={}) -> bool:
	if not catalog.get("panels",{}).has(id):return false
	revision+=1;panel_id=id;model=catalog.panels[id].duplicate(true);model.merge(override.duplicate(true),true)
	theme=STYLE.theme_for(model.get("large_text",false),model.get("high_contrast",false));card.add_theme_stylebox_override("panel",STYLE.paper(model.get("high_contrast",false)))
	for parent in [body,footer]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	buttons.clear();text_views.clear();choices.clear();portrait_views.clear();action_buttons.clear();science=null;search=null
	title.text=str(model.get("title",""));title.tooltip_text=title.text;title.add_theme_font_size_override("font_size",24 if not model.get("large_text",false) else 27)
	close_button.disabled=not bool(model.get("can_close",true));chosen_id=str(model.get("selected_choice",""))
	status=label(str(model.get("status","")),body);status.visible=not status.text.is_empty()
	var speaker: String=portraits.legacy_aliases.get(str(model.get("speaker","")),str(model.get("speaker","")))
	if not speaker.is_empty():_portrait(speaker)
	else:label(str(model.get("body","")),body)
	if model.get("search",false):
		search=LineEdit.new();search.placeholder_text="Search Guides";search.clear_button_enabled=true;search.custom_minimum_size.y=48;body.add_child(search);search.text=str(model.get("search_text",""))
		var token:=revision;search.text_changed.connect(func(value):_emit("search",{"text":value},token))
	if model.has("field"):
		var field:=LineEdit.new();field.name="PlayerNameInput";field.placeholder_text="Your name";field.max_length=24;field.custom_minimum_size.y=48;field.text=str(model.field.get("value",""));body.add_child(field)
		var token:=revision;field.text_changed.connect(func(value):_emit("edit_name",{"text":value},token))
	var diagram: String=model.get("diagram","")
	if not diagram.is_empty():science=SCIENCE.new();body.add_child(science);science.present(diagram,int(model.get("demo_stage",0)),model.get("large_text",false),model.get("reduced_motion",true))
	if model.has("rank_index"):_rank(int(model.rank_index))
	for row: Dictionary in model.get("rows",[]):_row(row)
	for definition: Dictionary in model.get("badges",[]):_badge(definition)
	for choice: Dictionary in model.get("choices",[]):
		var view:=button(choice.label,"choose_answer",body,choice.id)
		view.toggle_mode=true;view.set_pressed_no_signal(str(choice.id)==chosen_id);choices[str(choice.id)]=view
	var feedback: String=model.get("feedback","")
	if not feedback.is_empty():
		var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",STYLE.paper(model.get("high_contrast",false)));body.add_child(frame);var explanation:=label(feedback,frame)
		_focus_feedback.call_deferred(explanation,revision)
	for setting: Dictionary in model.get("settings",[]):
		var view:=CheckButton.new();view.text=setting.label;view.custom_minimum_size.y=48;view.set_pressed_no_signal(setting.get("value",false));body.add_child(view);buttons.append(view)
		var token:=revision;view.toggled.connect(func(value):_emit("setting",{"setting_id":setting.id,"value":value},token))
	for spec: Dictionary in model.get("actions",[]):
		var view:=button(spec.label,spec.id,footer,null,spec.get("enabled",true));action_buttons[spec.id]=view
		if spec.id in ["submit","next_item"] and not choices.is_empty():view.disabled=view.disabled or chosen_id.is_empty()
	scroll.scroll_vertical=0;show();reflow();return true

func _focus_feedback(explanation: Control,token: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if token==revision and is_instance_valid(explanation):scroll.ensure_control_visible(explanation)

func _choose(id: String,token: int) -> void:
	if token!=revision:return
	chosen_id=id
	for key: String in choices:choices[key].set_pressed_no_signal(key==id)
	for key: String in ["submit","next_item"]:
		if action_buttons.has(key):
			var specs: Array=model.get("actions",[]).filter(func(spec):return spec.id==key)
			action_buttons[key].disabled=specs.is_empty() or not specs[0].get("enabled",true)

func _portrait(speaker: String) -> void:
	var info: Dictionary=portraits.roles.get(speaker,{})
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);body.add_child(row)
	if not info.is_empty():
		var view:=TextureRect.new();view.texture=load(info.portraits.get(str(model.get("expression","neutral")),info.portraits.neutral));view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.custom_minimum_size=Vector2(100,125);row.add_child(view);portrait_views.append(view)
		view.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
	label(str(info.get("name","Speaker unavailable")),words,"heading");label(str(model.get("body","")),words)

func _row(data: Dictionary) -> void:
	var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",STYLE.paper());body.add_child(frame)
	var stack:=VBoxContainer.new();frame.add_child(stack)
	label(str(data.get("title","")),stack,"heading");label(str(data.get("text","")),stack)
	if data.has("action"):button("Open",str(data.action),stack,data.get("id",""),data.get("enabled",true))

func _badge(record: Dictionary) -> void:
	var matches: Array=BADGES.DEFINITIONS.filter(func(item):return item.id==record.get("id"))
	if matches.is_empty():return
	var definition: Dictionary=matches[0];var earned: bool=record.get("earned",false);var hidden: bool=definition.get("hidden",false) and not earned
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);body.add_child(row)
	var icon:=BADGE_ICON.new();icon.kind="hidden" if hidden else definition.icon;icon.earned=earned;row.add_child(icon)
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
	label("Hidden discovery" if hidden else definition.name,words,"heading")
	label("Keep exploring to discover this achievement." if hidden else definition.condition,words)
	label("Earned" if earned else "Locked" if hidden else "Locked · %d / %d"%[int(record.get("count",0)),BADGES.target(definition)],words)

func _rank(index: int) -> void:
	index=clampi(index,0,2);var texture:=AtlasTexture.new();texture.atlas=RANKS;var width:=RANKS.get_width()/3.0;var height:=minf(width,RANKS.get_height());texture.region=Rect2(index*width,(RANKS.get_height()-height)/2,width,height)
	var view:=TextureRect.new();view.texture=texture;view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.custom_minimum_size.y=100;body.add_child(view)

func reflow() -> void:
	if not is_node_ready():return
	safe=Rect2(Vector2.ZERO,size)
	if safe_override.has_area():safe=safe.intersection(safe_override)
	elif OS.has_feature("android"):
		var display:=DisplayServer.get_display_safe_area();var inverse:=get_viewport().get_screen_transform().affine_inverse();var display_rect:=Rect2(inverse*Vector2(display.position),inverse*Vector2(display.end)-inverse*Vector2(display.position));safe=safe.intersection(display_rect)
	safe=safe.grow(-8);card.size=Vector2(minf(920,safe.size.x),minf(640,safe.size.y));card.position=safe.get_center()-card.size/2
	footer.columns=mini(3,maxi(1,footer.get_child_count()))
	for view in portrait_views:view.custom_minimum_size=Vector2(76,95) if safe.size.y<440 else Vector2(144,180)
	for view in buttons:view.add_theme_font_size_override("font_size",19 if model.get("large_text",false) else 16)
