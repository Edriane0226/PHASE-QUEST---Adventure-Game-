extends SceneTree
const LAYER=preload("res://tools/art/menu_r3_v1/layer_source.gd")
const LOGO=preload("res://tools/art/menu_r3_v1/logo_source.gd")
const SOURCES={"gardens":preload("res://tools/art/menu_r3_v1/gardens-source.png"),"vale":preload("res://tools/art/menu_r3_v1/vale-source.png"),"laboratory":preload("res://tools/art/menu_r3_v1/laboratory-source.png")}
var output: String
var products: Array=[]
var canvas:=Vector2i.ZERO
var regions: Dictionary={}
func _initialize() -> void:call_deferred("run")
func json(name: String,value: Dictionary) -> void:
	var file:=FileAccess.open(output.path_join(name),FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close()
func record(path: String,image: Image) -> void:products.append({"file":path,"size":[image.get_width(),image.get_height()],"format":"RGBA8 native PNG"})
func render(node: Control,path: String,extent: Vector2i) -> void:
	var viewport:=SubViewport.new();viewport.size=extent;viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);viewport.add_child(node);node.size=Vector2(extent)
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	# Transparent viewport pixels are premultiplied. Export straight RGBA for normal texture blending.
	if path.ends_with("_veil.png") or path.ends_with("_atmosphere.png") or path=="title_logo.png":
		var data:=image.get_data()
		for i in range(0,data.size(),4):
			var alpha:=int(data[i+3])
			if alpha>0 and alpha<255:
				for channel in 3:data[i+channel]=clampi(roundi(float(data[i+channel])*255.0/alpha),0,255)
		image=Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,data)
	if image.save_png(output.path_join(path))!=OK:push_error("Export failed "+path);quit(1);return
	record(path,image);viewport.free();await process_frame
func run() -> void:
	output=ProjectSettings.globalize_path("res://assets/ui/main_menu/r3_v1");DirAccess.make_dir_recursive_absolute(output)
	canvas=Vector2i(SOURCES.gardens.get_size())
	for key: String in SOURCES:
		if Vector2i(SOURCES[key].get_size())!=canvas:push_error("Unregistered background source size");quit(1);return
		var image: Image=SOURCES[key].get_image();image.convert(Image.FORMAT_RGBA8);image.save_png(output.path_join(key+"_painting.png"));record(key+"_painting.png",image)
		for kind: String in ["veil","atmosphere","static"]:
			var layer:=LAYER.new();layer.region=key;layer.painting=SOURCES[key];layer.layer=kind;await render(layer,key+"_"+kind+".png",canvas)
		var entry:={"zone_id":{"gardens":"melting_and_freezing","vale":"vaporization_and_condensation","laboratory":"sublimation_and_deposition"}[key],"label":{"gardens":"Melting Gardens","vale":"Sunpetal Vale","laboratory":"Phaseworks Laboratory"}[key],"source":"tools/art/menu_r3_v1/"+key+"-source.png","canvas":[canvas.x,canvas.y],"geography":"Staged shared mainland: snow terraces, river lowlands, pale lab ridge; final actual world viewpoints remain021","spoilers":"Exterior scenery only; no puzzle mechanisms/targets/routes/discovery state","runtime_layers":["painting","veil","atmosphere"]}
		for kind: String in ["painting","veil","atmosphere","static"]:entry[kind]="res://assets/ui/main_menu/r3_v1/"+key+"_"+kind+".png"
		regions[key]=entry
	var logo_width:=ceili(LOGO.FONT.get_string_size(LOGO.TEXT,HORIZONTAL_ALIGNMENT_LEFT,-1,LOGO.PX).x)+96
	await render(LOGO.new(),"title_logo.png",Vector2i(logo_width,240))
	# Neutral safe fallback has no zone identity and exposes no progression state.
	var fallback:=Control.new();fallback.set_script(preload("res://Scripts/UI/Title/menu_backdrop.gd"));fallback.fallback=true
	# It reads regions.json in _ready, so publish metadata before its export.
	json("regions.json",{"schema_version":1,"owner":"R3 011","regions":regions,"fallback":"res://assets/ui/main_menu/r3_v1/fallback_static.png","selection_owner":"R3 021; metadata mapping is not save lookup/rotation"})
	await render(fallback,"fallback_static.png",canvas)
	var dialogs:={
		"options":{"title":"Options","body":"Take your time. Guides and learning help are free.","rows":[{"title":"Guides","text":"Lessons and demonstrations","action":"guides"},{"title":"Journal","text":"Discoveries, ranks and achievements","action":"journal"},{"title":"Settings","text":"Audio and accessibility","action":"settings"},{"title":"Study Assessment","text":"Assigned pre/post study forms","action":"study"}],"actions":[{"id":"menu_back","label":"Back","enabled":true}]},
		"new_game":{"title":"Start a new adventure?","body":"Starting a new adventure replaces the current adventure's progress. Continue your existing adventure to keep it.","rows":[],"actions":[{"id":"confirm_new_game","label":"Start new adventure","enabled":true},{"id":"menu_back","label":"Keep current adventure","enabled":true}]},
		"exit":{"title":"Exit Phase Quest?","body":"Leave the game? Your last successfully saved progress remains available.","rows":[],"actions":[{"id":"confirm_exit","label":"Exit","enabled":true},{"id":"menu_back","label":"Stay","enabled":true}]},
		"continue_unavailable":{"title":"Adventure unavailable","body":"This adventure could not be resumed. Your save has not been reset. Return and review recovery options.","rows":[],"actions":[{"id":"recovery","label":"Recovery options","enabled":true},{"id":"menu_back","label":"Back","enabled":true}]},
		"unsupported_save":{"title":"Save needs a newer version","body":"Keep this save unchanged. Return safely rather than resetting the profile.","rows":[],"actions":[{"id":"menu_back","label":"Back","enabled":true}],"can_close":true},
		"save_error":{"title":"Progress not saved","body":"Saving could not finish. Retry before leaving; no replacement or new adventure is confirmed.","rows":[],"actions":[{"id":"retry_save","label":"Retry save","enabled":true},{"id":"menu_back","label":"Stay here","enabled":true}]},
		"loading":{"title":"Opening adventure","body":"Please wait for your adventure to open.","rows":[],"actions":[{"id":"wait","label":"Opening…","enabled":false}],"can_close":false}
	}
	json("dialogs.json",{"owner":"R3 011","scope":"Presentation/confirmation intents only; no reset/save/exit/scene mutation","dialogs":dialogs})
	var states:={"fresh":{"region":"gardens","continue_available":false},"continue_gardens":{"region":"gardens","continue_available":true},"continue_vale":{"region":"vale","continue_available":true},"continue_laboratory":{"region":"laboratory","continue_available":true},"disabled":{"region":"vale","continue_available":true,"interactions_enabled":false},"focus":{"region":"gardens","continue_available":true,"visual_state":"focus"},"hovered":{"region":"vale","continue_available":false,"visual_state":"hovered"},"pressed":{"region":"laboratory","continue_available":true,"visual_state":"pressed"},"missing_assets":{"region":"gardens","force_missing_background":true},"unknown_region":{"region":"unknown"},"reduced_motion":{"region":"vale","reduced_motion":true,"variant":"layered"},"layered":{"region":"laboratory","reduced_motion":false,"variant":"layered"}}
	for key: String in dialogs:states["dialog_"+key]={"region":"gardens","continue_available":true,"dialog":key,"has_progress":true}
	json("menu_states.json",{"owner":"R3 011","scope":"Disposable presentation fixtures; no selection or saved-progress authority","states":states})
	json("build-products.json",{"owner":"R3 011","products":products,"source_canvas":[canvas.x,canvas.y],"source_kind":"Three original built-in imagegen paintings plus native registered overlays/title/fallback","layers":"Generated paintings are flattened; added atmosphere/veil are independently editable, not recovered object layers","zone_count":3})
	print("R3 011 BUILD PASS / ",products.size()," native PNG products /3regional sets / ",canvas.x,"x",canvas.y)
	quit()
