extends RefCounted
## Separate bounded discovery ledger. No completion, abilities, rewards or attempt mutation.
const CELL:=96
const SIZE:=Vector2i(220,105)
var cells: Dictionary={}
var revision:=0
var saved_revision:=-1
var path:=""
var last_error:=""
var read_only:=false
var retained: Dictionary={}
var recovered_backup:=false
func bind_profile(profile: Node) -> bool:
	var identity: String = profile.world_discovery_namespace()
	if identity.is_empty(): read_only=true;last_error="Unsupported world discovery metadata retained.";return false
	# Fixture storage is isolated by its runner; production identity must commit first.
	if not profile.get_meta("r3_015_fixture", false) and not profile.save_profile():
		read_only=true;last_error=profile.last_error;return false
	path="user://world-discovery/"+identity+".json"
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): return load_ledger()
	# One-time019 import. Original ledger remains untouched; future schema stays read-only.
	var target:=path
	var legacy: String=(profile.save_path+":"+str(profile.data.player_name)+":isolated019").sha256_text()
	path="user://world-discovery/"+legacy+".json"
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		var loaded:=load_ledger();path=target
		if loaded:revision+=1;saved_revision=-1;recovered_backup=false
		return loaded
	path=target
	return true
func valid_path() -> bool:
	var prefix:="user://world-discovery/"
	var name: String=path.trim_prefix(prefix)
	return path.begins_with(prefix) and name.ends_with(".json") and not name.contains("/") and not name.contains("\\") and name.is_valid_filename()
func center(key: Vector2i) -> Vector2:return (Vector2(key)+Vector2.ONE*.5)*CELL
func key_at(point: Vector2) -> Vector2i:return Vector2i((point/CELL).floor())
func known(point: Vector2) -> bool:return cells.has(key_at(point))
func observe(point: Vector2,policy: RefCounted,radius:=260.0) -> bool:
	if not policy.point_allowed(point):return false
	var origin:=key_at(point);var before:=cells.size();var n:=ceili(radius/CELL)
	for y in range(maxi(0,origin.y-n),mini(SIZE.y,origin.y+n+1)):
		for x in range(maxi(0,origin.x-n),mini(SIZE.x,origin.x+n+1)):
			var key:=Vector2i(x,y);var at:=center(key)
			if at.distance_to(point)<=radius and policy.point_allowed(at):cells[key]=true
	if cells.size()!=before:revision+=1;return true
	return false
func document() -> Dictionary:
	var values: Array=[]
	var keys:=cells.keys();keys.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else a.x<b.x)
	for key: Vector2i in keys:values.append([key.x,key.y])
	var value: Dictionary=retained.duplicate(true);value.version=1;value.cell_size=CELL;value.cells=values;return value
func load_ledger() -> bool:
	last_error=""
	if not valid_path():last_error="Invalid discovery namespace.";return false
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:continue
		var value=parser.data
		if candidate==path and value is Dictionary and value.get("version")!=1:
			read_only=true;last_error="Unknown discovery version retained; writing disabled.";return false
		if not value is Dictionary or value.get("version")!=1 or value.get("cell_size")!=CELL or not value.get("cells") is Array or value.cells.size()>SIZE.x*SIZE.y:continue
		var parsed: Dictionary={};var valid:=true
		for pair in value.cells:
			if not pair is Array or pair.size()!=2 or not (pair[0] is float or pair[0] is int) or not (pair[1] is float or pair[1] is int):valid=false;break
			if not is_finite(float(pair[0])) or not is_finite(float(pair[1])) or float(pair[0])<0 or float(pair[1])<0 or float(pair[0])>=SIZE.x or float(pair[1])>=SIZE.y:valid=false;break
			var key:=Vector2i(pair[0],pair[1])
			if float(pair[0])!=key.x or float(pair[1])!=key.y:valid=false;break
			parsed[key]=true
		if not valid:continue
		cells=parsed;retained=value.duplicate(true);recovered_backup=candidate!=path;revision+=1;saved_revision=revision;read_only=false;return true
	if FileAccess.file_exists(path):read_only=true;last_error="Invalid discovery retained; writing disabled."
	return false
func save_ledger() -> bool:
	last_error=""
	if read_only:last_error="Discovery file retained; writing disabled.";return false
	if not valid_path():last_error="Invalid discovery namespace.";return false
	if revision==saved_revision:return true
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:last_error="Cannot create discovery storage.";return false
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:last_error="Cannot write discovery.";return false
	file.store_string(JSON.stringify(document()));file.flush();var error:=file.get_error();file.close()
	if error!=OK:last_error="Cannot finish discovery write.";return false
	if FileAccess.file_exists(path):
		var backup: String=path+".corrupt" if recovered_backup else path+".bak"
		if DirAccess.copy_absolute(path,backup)!=OK:last_error="Cannot back up discovery.";return false
		if DirAccess.remove_absolute(path)!=OK:last_error="Cannot replace discovery.";return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:
		if FileAccess.file_exists(path+".bak"):DirAccess.copy_absolute(path+".bak",path)
		last_error="Cannot commit discovery; backup retained.";return false
	saved_revision=revision;recovered_backup=false;return true
