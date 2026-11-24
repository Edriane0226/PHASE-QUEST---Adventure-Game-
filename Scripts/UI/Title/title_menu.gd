extends Control
## Opt-in title presentation. Provider supplies resume validity/region; all actions remain intents.
signal action_requested(action: String,payload: Dictionary)
const BACKDROP=preload("res://Scripts/UI/Title/menu_backdrop.gd")
const ACTION=preload("res://Scripts/UI/Title/title_action.gd")
const SUPPORT=preload("res://UI/Support/SupportPanels.tscn")
const FONT=preload("res://assets/fonts/InterfaceSans.tres")
const LOGO=preload("res://assets/ui/main_menu/r3_v1/title_logo.png")
var model: Dictionary={}
var backdrop: Control
var logo: TextureRect
var menu: VBoxContainer
var buttons: Dictionary={}
var version: Label
var region_label: Label
var orientation: Label
var dialog: Control
var dialog_specs: Dictionary={}
var dialog_id:=""
var revision:=0
var safe_override:=Rect2()
var safe:=Rect2()
var supported:=true
var _before_modal_reduce:=true

func _ready() -> void:
	backdrop=BACKDROP.new();backdrop.name="RegionalBackdrop";add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo=TextureRect.new();logo.name="PhaseQuestTitle";logo.texture=LOGO;logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(logo)
	menu=VBoxContainer.new();menu.name="QuietActions";menu.add_theme_constant_override("separation",0);add_child(menu)
	for id in ["continue","new_game","options","exit"]:
		var button:=ACTION.new();button.name=id.capitalize();button.text={"continue":"Continue","new_game":"New Game","options":"Options","exit":"Exit"}[id];button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu.add_child(button);buttons[id]=button;button.pressed.connect(_activate.bind(id))
	version=Label.new();version.name="Version";region_label=Label.new();region_label.name="Region";orientation=Label.new();orientation.name="RotateHint"
	for view in [version,region_label,orientation]:
		view.add_theme_font_override("font",FONT);view.add_theme_color_override("font_color",Color("e4e8dd"));view.add_theme_color_override("font_outline_color",Color("14262a"));view.add_theme_constant_override("outline_size",2);view.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(view)
	orientation.text="Rotate device to landscape";orientation.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;orientation.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	dialog=SUPPORT.instantiate();dialog.name="SupportingDialogs";add_child(dialog);dialog.intent_requested.connect(_dialog_intent)
	var path:="res://assets/ui/main_menu/r3_v1/dialogs.json"
	if FileAccess.file_exists(path):
		var spec: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if spec is Dictionary and spec.get("dialogs") is Dictionary:dialog_specs=spec.dialogs
	resized.connect(reflow);present({})

func present(value: Dictionary) -> void:
	revision+=1;model=value.duplicate(true);dialog_id="";dialog.hide()
	var region:=str(model.get("region","gardens"));var reduce: bool=model.get("reduced_motion",true)
	backdrop.present(region,reduce,str(model.get("variant","static")),model.get("force_missing_background",false))
	buttons["continue"].visible=bool(model.get("continue_available",false))
	buttons.exit.visible=bool(model.get("exit_supported",true))
	for id: String in buttons:
		buttons[id].disabled=not bool(model.get("interactions_enabled",true)) or not bool(model.get(id+"_enabled",true))
		buttons[id].visual_override=str(model.get("visual_state","")) if id=="new_game" else "";buttons[id].queue_redraw()
	version.text=str(model.get("version",""));version.visible=not version.text.is_empty()
	region_label.text="" if backdrop.fallback else str(backdrop.entries[backdrop.current_region].get("label",""))
	reflow()
	if model.has("dialog"):open_dialog(str(model.dialog))

func reflow() -> void:
	if not is_node_ready():return
	safe=Rect2(Vector2.ZERO,size)
	if safe_override.has_area():safe=safe.intersection(safe_override)
	elif OS.has_feature("android"):
		var area:=DisplayServer.get_display_safe_area();var inverse:=get_viewport().get_screen_transform().affine_inverse();var transformed:=Rect2(inverse*Vector2(area.position),inverse*Vector2(area.end)-inverse*Vector2(area.position));safe=safe.intersection(transformed)
	safe=safe.grow(-8);supported=safe.size.x>=540 and safe.size.y>=300 and safe.size.x>safe.size.y
	var compact:=safe.size.y<440
	var count:=buttons.values().filter(func(button):return button.visible).size();var height:=44 if compact else 56
	var top:=minf(safe.position.y+safe.size.y*.50,safe.end.y-count*height-12)
	var aspect:=float(LOGO.get_width())/LOGO.get_height()
	var logo_h:=minf((minf(safe.size.x-32,760 if not compact else 440))/aspect,minf(safe.size.y*.27,maxf(48,top-safe.position.y-20)))
	logo.size=Vector2(logo_h*aspect,logo_h);var center_y:=minf(safe.position.y+safe.size.y*.32,top-10-logo_h/2)
	logo.position=Vector2(safe.get_center().x-logo.size.x/2,center_y-logo_h/2)
	menu.size=Vector2(minf(296,safe.size.x*.62),count*height);menu.position=Vector2(safe.get_center().x-menu.size.x/2,top)
	for button in buttons.values():button.custom_minimum_size.y=height;button.add_theme_font_size_override("font_size",18 if compact else 24)
	version.position=safe.position;version.size=Vector2(minf(170,safe.size.x*.32),20);version.add_theme_font_size_override("font_size",12)
	region_label.position=Vector2(safe.position.x,safe.end.y-22);region_label.size=Vector2(safe.size.x*.42,22);region_label.add_theme_font_size_override("font_size",12 if compact else 15)
	orientation.position=safe.position;orientation.size=safe.size;orientation.add_theme_font_size_override("font_size",18);orientation.visible=not supported
	logo.visible=supported;menu.visible=supported and dialog_id.is_empty();region_label.visible=supported and not region_label.text.is_empty()
	dialog.safe_override=safe_override;dialog.reflow()

func _activate(id: String) -> void:
	if not supported or not dialog_id.is_empty() or not buttons.has(id) or not buttons[id].visible or buttons[id].disabled:return
	if id=="continue" and not bool(model.get("continue_available",false)):return
	if id=="options":open_dialog("options");return
	if id=="new_game" and not model.get("confirm_new_game_in_provider",false) and (bool(model.get("has_progress",false)) or bool(model.get("continue_available",false))):open_dialog("new_game");return
	if id=="exit":open_dialog("exit");return
	action_requested.emit(id,{"view_revision":revision,"context_key":model.get("context_key","")})

func open_dialog(key: String) -> bool:
	if not supported or not dialog_specs.has(key):return false
	if dialog_id.is_empty():_before_modal_reduce=backdrop.reduced_motion
	dialog_id=key;menu.hide();backdrop.reduced_motion=true;backdrop.queue_redraw()
	var spec: Dictionary=dialog_specs[key].duplicate(true);spec.large_text=model.get("large_text",false);spec.high_contrast=model.get("high_contrast",false);spec.context_key=model.get("context_key","")
	dialog.open_panel("pause.open",spec);return true

func _dialog_intent(_panel: String,action: String,payload: Dictionary) -> void:
	if dialog_id.is_empty() or not dialog.visible:return
	if action in ["menu_back","close"]:
		dialog_id="";dialog.hide();menu.visible=supported;backdrop.reduced_motion=_before_modal_reduce;backdrop.queue_redraw();return
	payload=payload.duplicate(true);payload.menu_dialog=dialog_id;payload.menu_revision=revision
	action_requested.emit(action,payload) # No reset/save/scene change/quit here, even for confirmations.
