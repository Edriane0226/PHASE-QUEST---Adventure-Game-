extends Control
## One title session, one chosen geographic view. Opening writes presentation prefs only.
const TITLE=preload("res://UI/Menus/Title/TitleMenu.tscn")
const SESSION=preload("res://Scripts/UI/Title/menu_session.gd")
const TEACHING=preload("res://Scripts/World/Learning/professor_content.gd")
const SUPPORT=preload("res://Scripts/UI/Support/support_panels.gd")
const VIEWS="res://assets/ui/main_menu/world_v1/views.json"
var view: Control
var preferences: RefCounted
var profile: Node
var chosen_region:=""
var context:=""
var pending_context:=""
var pending_revision:=-1
var name_input: LineEdit
var error_label: Label
var guide_preview: Node
var busy:=false
var resume: Dictionary={}
func _ready() -> void:
	profile=get_node("/root/PlayerSave")
	preferences=SESSION.new();preferences.load_preferences()
	view=TITLE.instantiate();add_child(view)
	# Quiet action contrast over actual terrain. Presentation only; no world simulation.
	var shade:=TextureRect.new();shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(.025,.06,.07,.50),Color(.025,.06,.07,.08)])
	var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.width=256;texture.height=256;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.55);texture.fill_to=Vector2(.5,0)
	shade.texture=texture;shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.add_child(shade);view.move_child(shade,1);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog: Variant=JSON.parse_string(FileAccess.get_file_as_string(VIEWS)) if FileAccess.file_exists(VIEWS) else null
	view.backdrop.entries=catalog.regions if catalog is Dictionary and catalog.get("regions") is Dictionary else {}
	resume=profile.menu_resume()
	chosen_region=preferences.choose(str(resume.get("region","")))
	view.action_requested.connect(_intent)
	view.dialog.visibility_changed.connect(func():
		if not view.dialog.visible:_clear_preview())
	profile.changed.connect(_profile_changed);profile.restored.connect(_profile_changed)
	_refresh()
	if profile.read_only:
		var recovery: Dictionary = view.dialog_specs.unsupported_save.duplicate(true)
		recovery.title = "Adventure recovery"
		recovery.body = profile.last_error + " Keep this save and its backups."
		view.dialog_specs.unsupported_save = recovery
		view.open_dialog("unsupported_save")
func _refresh() -> void:
	context=profile.menu_context();resume=profile.menu_resume()
	view.present({"region":chosen_region,"reduced_motion":preferences.reduced_motion,"variant":"static" if preferences.reduced_motion else "layered","continue_available":not resume.is_empty(),"new_game_enabled":not profile.read_only,"confirm_new_game_in_provider":true,"has_progress":not profile.data.active_run.is_empty() or not profile.data.completed.is_empty(),"context_key":context,"exit_supported":not OS.has_feature("web"),"interactions_enabled":not busy,"version":ProjectSettings.get_setting("application/config/version","")})
func _profile_changed() -> void:
	# Keep view fixed for this opening; invalidate any stale destructive dialog.
	pending_context="";pending_revision=-1
	_refresh()
func _new_game_dialog() -> void:
	_clear_preview()
	pending_context=profile.menu_context();pending_revision=view.revision
	var spec: Dictionary=view.dialog_specs.new_game.duplicate(true)
	spec.body="Start a new adventure? Current progress will be replaced. A recovery copy of your whole current profile is kept first. Cancel to keep playing your current adventure."
	view.dialog_specs.new_game=spec
	view.open_dialog("new_game")
	name_input=LineEdit.new();name_input.placeholder_text="Explorer name";name_input.text=str(profile.data.player_name);name_input.max_length=24;name_input.custom_minimum_size.y=48;view.dialog.body.add_child(name_input)
	error_label=Label.new();error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;view.dialog.body.add_child(error_label)
	name_input.grab_focus()
func _intent(action: String,payload: Dictionary) -> void:
	if busy:return
	var token: int=payload.get("menu_revision",payload.get("view_revision",-1))
	if token!=view.revision or payload.get("context_key",context)!=context:return
	match action:
		"new_game":_new_game_dialog()
		"confirm_new_game":
			if view.dialog_id!="new_game" or pending_revision!=view.revision or pending_context!=profile.menu_context() or not is_instance_valid(name_input):return
			var path: String=profile.start_new_world(name_input.text,pending_context)
			if path.is_empty():
				if is_instance_valid(error_label):error_label.text=profile.last_error
				return
			_open_world(path)
		"continue":
			var path: String=profile.request_world_continue()
			if path.is_empty():view.open_dialog("continue_unavailable");return
			_open_world(path)
		"confirm_exit":
			if view.dialog_id=="exit" and not OS.has_feature("web"):get_tree().quit()
		"settings":_settings()
		"setting":
			if view.dialog_id!="runtime_settings":return
			var id: String=str(payload.get("setting_id",""))
			if id=="reduced_motion":
				preferences.reduced_motion=payload.get("value",true)==true;preferences.save_preferences();view._before_modal_reduce=preferences.reduced_motion
			elif id in ["music","sfx"]:get_node("/root/GameAudio").set_enabled(id,payload.get("value",true)==true)
		"journal":_journal()
		"guides":_guides()
		"open_guide":_guide(str(payload.get("value","")))
		"study":_panel("runtime_study",{"title":"Study Assessment","body":"Study participants use paper forms from their study coordinator before and after playing. You can play without an assessment."})
		"recovery":_panel("runtime_recovery",{"title":"Adventure recovery","body":"Your save remains unchanged. Keep your profile and backup files; return with the matching game version or retry after restoring a known-good copy."})
func _open_world(path: String) -> void:
	busy=true;_clear_preview();view.dialog.hide();view.dialog_id="";view.menu.hide()
	get_tree().paused=false
	var transition:=get_node("/root/SceneTransition")
	transition.run(_change_world.bind(path),true,path)
func _change_world(path: String) -> void:
	var error: Error=await get_node("/root/SceneTransition").change_scene(path)
	if error!=OK:busy=false;_refresh();view.open_dialog("continue_unavailable")
func _panel(id: String,spec: Dictionary) -> void:
	_clear_preview()
	for key in ["rows","settings","badges","choices"]:
		if not spec.has(key):spec[key]=[]
	spec.search=false
	spec.actions=[{"id":"menu_back","label":"Back","enabled":true}]
	view.dialog_specs[id]=spec;view.open_dialog(id)
func _settings() -> void:
	var audio:=get_node("/root/GameAudio")
	_panel("runtime_settings",{"title":"Settings","body":"Audio and accessibility","settings":[{"id":"music","label":"Music","value":audio.music_enabled},{"id":"sfx","label":"Sound effects","value":audio.sfx_enabled},{"id":"reduced_motion","label":"Reduced menu motion","value":preferences.reduced_motion}]})
func _journal() -> void:
	_panel("runtime_journal",SUPPORT.journal_model(profile))
func _guides() -> void:
	var rows: Array=[]
	for key in profile.guide_records():
		var record: Dictionary=profile.guide_records()[key]
		var guide := TEACHING.guide(record)
		var district := TEACHING.REGISTRY.definition(TEACHING.region_for(record.zone,record.level))
		rows.append({"title":guide.title,"text":district.get("name",""),"action":"open_guide","id":key})
	_panel("runtime_guides",{"title":"Guides","body":"Free lessons and demonstrations","rows":rows})
func _guide(key: String) -> void:
	var record: Dictionary=profile.guide_records().get(key,{})
	if record.is_empty():return
	_panel("runtime_guide",TEACHING.guide(record))
	guide_preview=TEACHING.preview(record)
	view.dialog.attach_guide_demo(guide_preview)
func _clear_preview() -> void:
	if is_instance_valid(guide_preview):guide_preview.queue_free()
	guide_preview=null
func _exit_tree() -> void:_clear_preview()
