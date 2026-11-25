extends SceneTree
## Checks exported pixel sheets against the standard. Reads files only; never draws or changes art.
## Run through validate.ps1. It uses an empty project, so no game autoload or save is touched.

const COLOUR_LIMIT := {"prop":6, "character":12, "machine":16, "card":8, "tile_cap":4, "tile_edge":4, "tile_side":6, "shadow":1}
const CELLS := {"tile_cap":[40,20], "tile_edge":[40,24], "tile_side":[40,40], "character":[64,64]}
const MIN_MS := 60
const MAX_MS := 1000
const MIN_DISTANCE := 30.0
const MIN_STEP := 11.0
const MIN_MEANING := 20.0
const MARK_LIMIT := 0.15
const SEAM_RATIO := 1.6
const TAGS := "^(idle|use|wrong|solved|walk|run|jump|lift|place|operate|touch|carry|aim|fire|holster|attentive|explaining|success|variant|mask|start|loop|stop|impact|blocked)(_[a-z0-9_]+)?$|^to_[a-z0-9_]+_from_[a-z0-9_]+$"
const SIM := {
	"protan":[0.152286,1.052583,-0.204868,0.114503,0.786281,0.099216,-0.003882,-0.048116,1.051998],
	"deutan":[0.367322,0.860646,-0.227968,0.280085,0.672501,0.047413,-0.011820,0.042940,0.968881],
	"tritan":[1.255528,-0.076749,-0.178779,-0.078411,0.930809,0.147602,0.004733,0.691367,0.303900],
}
var project := ""
var assets := ""
var source := ""
var palette: Dictionary = {}
var colours: Array = []
var subsets: Dictionary = {}
var meaning: Array = []
var lines: PackedStringArray = []
var total_problems := 0
var name_pattern := RegEx.new()

func _initialize() -> void:
	name_pattern.compile(TAGS)
	var legacy: PackedStringArray = []
	var report := ""
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):project = arg.trim_prefix("--root=")
		elif arg.begins_with("--assets="):assets = arg.trim_prefix("--assets=")
		elif arg.begins_with("--source="):source = arg.trim_prefix("--source=")
		elif arg.begins_with("--legacy="):legacy.append(arg.trim_prefix("--legacy="))
		elif arg.begins_with("--report="):report = arg.trim_prefix("--report=")
		elif arg.begins_with("--only="):only = arg.trim_prefix("--only=")
	if assets.is_empty():assets = project + "/assets/pixel_v1"
	if source.is_empty():source = project + "/art_src/pixel_v1"
	if not read_palette():
		print("VALIDATE FAIL cannot read the master palette")
		quit(2)
		return
	var passed := true
	if not legacy.is_empty():
		for path in legacy:
			var found := check_image(Image.load_from_file(path), colours_of("master"), 16)
			emit(path.get_file(), found)
			passed = passed and found.is_empty()
	else:
		if only.is_empty():
			var found := check_palette()
			emit("master palette", found)
			passed = found.is_empty()
		var sheets := list_files(assets, "png")
		var manifest := read_json(assets + "/manifest.json")
		var recorded: Dictionary = manifest.get("sheets", {})
		for rel in sheets:
			if not only.is_empty() and not rel.begins_with(only):continue
			var found := check_sheet(rel, recorded)
			emit(rel, found)
			passed = passed and found.is_empty()
		if only.is_empty():
			var found := check_orphans(sheets, recorded)
			emit("folder and manifest", found)
			passed = passed and found.is_empty()
	print("VALIDATE ", "PASS" if passed else "FAIL", " problems=", total_problems)
	if not report.is_empty():
		var file := FileAccess.open(report, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
	quit(0 if passed else 1)

func emit(title: String, found: Array) -> void:
	total_problems += found.size()
	print("PASS " if found.is_empty() else "FAIL ", title)
	lines.append(("- PASS `%s`" if found.is_empty() else "- FAIL `%s`") % title)
	for item in found:
		print("   ", item)
		lines.append("  - " + str(item))

# ---------------------------------------------------------------- files

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func list_files(folder: String, extension: String, prefix := "") -> PackedStringArray:
	var result: PackedStringArray = []
	for name in DirAccess.get_files_at(folder):
		if name.get_extension() == extension:result.append(prefix + name.get_basename())
	for sub in DirAccess.get_directories_at(folder):
		result.append_array(list_files(folder + "/" + sub, extension, prefix + sub + "/"))
	return result

func read_palette() -> bool:
	var base := project + "/art_src/pixel_v1/palette/phase_quest_master"
	if not FileAccess.file_exists(base + ".gpl"):return false
	for line in FileAccess.get_file_as_string(base + ".gpl").split("\n"):
		var parts := line.strip_edges().replace("\t", " ").split(" ", false)
		if parts.size() != 4 or not parts[0].is_valid_int():continue
		var rgb := (int(parts[0]) << 16) | (int(parts[1]) << 8) | int(parts[2])
		palette[rgb] = parts[3]
		colours.append({"name":parts[3], "rgb":rgb})
	var data := read_json(base + ".json")
	subsets = data.get("subsets", {})
	meaning = data.get("meaning", [])
	return colours.size() > 0 and not subsets.is_empty()

func colours_of(subset: String) -> Dictionary:
	var allowed := {}
	var names: Array = subsets.get(subset, [])
	for c in colours:
		if c.name in names:allowed[c.rgb] = c.name
	return allowed

# ---------------------------------------------------------------- palette

static func channels(rgb: int) -> Vector3:return Vector3((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255)

static func to_linear(v: float) -> float:
	v /= 255.0
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

static func lab_of(linear: Vector3) -> Vector3:
	var l := linear.clamp(Vector3.ZERO, Vector3.ONE)
	var xyz := [(0.4124 * l.x + 0.3576 * l.y + 0.1805 * l.z) / 0.95047, 0.2126 * l.x + 0.7152 * l.y + 0.0722 * l.z, (0.0193 * l.x + 0.1192 * l.y + 0.9505 * l.z) / 1.08883]
	var f: Array = []
	for t: float in xyz:f.append(pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0)
	return Vector3(116.0 * f[1] - 16.0, 500.0 * (f[0] - f[1]), 200.0 * (f[1] - f[2]))

static func seen(rgb: int, kind := "") -> Vector3:
	var c := channels(rgb)
	var l := Vector3(to_linear(c.x), to_linear(c.y), to_linear(c.z))
	if SIM.has(kind):
		var m: Array = SIM[kind]
		l = Vector3(m[0] * l.x + m[1] * l.y + m[2] * l.z, m[3] * l.x + m[4] * l.y + m[5] * l.z, m[6] * l.x + m[7] * l.y + m[8] * l.z)
	return lab_of(l)

func check_palette() -> Array:
	var found: Array = []
	if colours.size() != 49 or palette.size() != 49:found.append("expected 49 different colours, found %d" % palette.size())
	var closest := 999.0
	var pair := ""
	for i in colours.size():
		for j in range(i + 1, colours.size()):
			var d := channels(colours[i].rgb).distance_to(channels(colours[j].rgb))
			if d < closest:
				closest = d
				pair = colours[i].name + " and " + colours[j].name
			if d < MIN_DISTANCE:found.append("%s and %s are %.1f apart, minimum %d" % [colours[i].name, colours[j].name, d, MIN_DISTANCE])
	lines.append("- Closest pair: %s, %.1f RGB units" % [pair, closest])
	print("   closest pair ", pair, " ", snappedf(closest, .1))
	# Ramp steps must be visible, and shadows cooler than highlights.
	for i in range(1, colours.size()):
		var a: Dictionary = colours[i - 1]
		var b: Dictionary = colours[i]
		if a.name.rstrip("0123456789") != b.name.rstrip("0123456789"):continue
		var step := seen(b.rgb).x - seen(a.rgb).x
		if step < MIN_STEP:found.append("%s to %s is only %.1f lighter" % [a.name, b.name, step])
	var by_name := {}
	for c in colours:by_name[c.name] = c.rgb
	for m in meaning:
		var worst := 999.0
		var worst_kind := ""
		for kind in ["normal", "protan", "deutan", "tritan"]:
			var d := seen(by_name[m[1]], kind).distance_to(seen(by_name[m[2]], kind))
			if d < worst:
				worst = d
				worst_kind = kind
		lines.append("- Meaning pair %s (%s, %s): worst %.0f, %s" % [m[0], m[1], m[2], worst, worst_kind])
		if worst < MIN_MEANING:found.append("%s (%s, %s) is only %.1f apart for %s" % [m[0], m[1], m[2], worst, worst_kind])
	# Any two colours that merge for colour-blind players. Advice, not an error.
	for kind in SIM:
		var merged: PackedStringArray = []
		for i in colours.size():
			for j in range(i + 1, colours.size()):
				if colours[i].name.rstrip("0123456789") == colours[j].name.rstrip("0123456789"):continue
				if seen(colours[i].rgb, kind).distance_to(seen(colours[j].rgb, kind)) < 6.0:merged.append(colours[i].name + "/" + colours[j].name)
		lines.append("- Looks alike for %s, never use as the only difference (%d): %s" % [kind, merged.size(), ", ".join(merged)])
		print("   alike for ", kind, ": ", merged.size())
	return found

# ---------------------------------------------------------------- images

func check_image(image: Image, allowed: Dictionary, limit: int) -> Array:
	if image == null:return ["cannot read the image"]
	image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var soft := 0
	var off := 0
	var used := {}
	var strange := {}
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a == 0:continue
		if a < 255:soft += 1
		var rgb := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
		used[rgb] = true
		if not allowed.has(rgb):
			off += 1
			strange[rgb] = true
	var found: Array = []
	if soft > 0:found.append("partial alpha: %d pixels" % soft)
	if off > 0:
		var sample: PackedStringArray = []
		for rgb in strange.keys().slice(0, 4):sample.append("%06x" % rgb)
		found.append("off palette: %d pixels, %d colours, for example %s" % [off, strange.size(), ", ".join(sample)])
	if used.size() > limit:found.append("colour limit: %d colours, limit %d" % [used.size(), limit])
	return found

func check_sheet(rel: String, recorded: Dictionary) -> Array:
	var found: Array = []
	var meta := read_json(assets + "/" + rel + ".meta.json")
	var data := read_json(assets + "/" + rel + ".json")
	var image := Image.load_from_file(assets + "/" + rel + ".png")
	if meta.is_empty():found.append("missing or unreadable meta file")
	if data.is_empty() or not data.get("frames") is Array or not data.get("meta") is Dictionary:found.append("missing or unreadable sheet data")
	if image == null:found.append("cannot read the image")
	if not found.is_empty():return found
	var kind: String = meta.get("class", "")
	if not COLOUR_LIMIT.has(kind):found.append("unknown class '%s'" % kind)
	if not subsets.has(meta.get("palette", "")):found.append("unknown palette subset '%s'" % meta.get("palette", ""))
	if meta.get("group", "") != rel.get_file():found.append("group name does not match the file name")
	found.append_array(check_image(image, colours_of(meta.get("palette", "master")), COLOUR_LIMIT.get(kind, 0)))
	found.append_array(check_cells(image, data, meta, kind))
	found.append_array(check_clips(data, meta, kind))
	found.append_array(check_pivot(image, data, meta, kind))
	if kind.begins_with("tile_"):found.append_array(check_tile(image, data, meta, kind))
	found.append_array(check_provenance(rel, recorded))
	return found

func cell_of(meta: Dictionary) -> Vector2i:
	var c: Array = meta.get("cell", [0, 0])
	return Vector2i(int(c[0]), int(c[1]))

func check_cells(image: Image, data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var found: Array = []
	var cell := cell_of(meta)
	if cell.x <= 0 or cell.y <= 0:return ["cell size is missing"]
	if CELLS.has(kind) and cell != Vector2i(CELLS[kind][0], CELLS[kind][1]):found.append("cell size: %s cells are %dx%d, not %dx%d" % [kind, CELLS[kind][0], CELLS[kind][1], cell.x, cell.y])
	if cell.x > 256 or cell.y > 256:found.append("cell size: larger than 256")
	if image.get_width() % cell.x != 0 or image.get_height() % cell.y != 0:found.append("cell size: sheet %dx%d does not divide by %dx%d" % [image.get_width(), image.get_height(), cell.x, cell.y])
	var index := 0
	for f in data.frames:
		var r: Dictionary = f.frame
		if Vector2i(int(r.w), int(r.h)) != cell or f.get("trimmed", false) or f.get("rotated", false):
			found.append("cell size: frame %d is %dx%d or trimmed" % [index, r.w, r.h])
			break
		if int(r.x) != (index % 8) * cell.x or int(r.y) != (index / 8) * cell.y:
			found.append("cell size: frame %d is not in row order, 8 per row" % index)
			break
		index += 1
	return found

func check_clips(data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var found: Array = []
	var tags: Array = data.meta.get("frameTags", [])
	if tags.is_empty():return ["no clips (tags)"]
	var clips: Dictionary = meta.get("clips", {})
	var names := {}
	var covered := 0
	for t in tags:
		var name: String = t.name
		if names.has(name):found.append("clip '%s' appears twice" % name)
		names[name] = true
		covered += int(t.to) - int(t.from) + 1
		if name_pattern.search(name) == null:found.append("clip name '%s' is not in the standard" % name)
		if not clips.has(name):found.append("clip '%s' is not in the meta file" % name)
		if kind.begins_with("tile_") or kind == "shadow":continue
		for i in range(int(t.from), int(t.to) + 1):
			var ms := int(data.frames[i].duration)
			if t.from != t.to and (ms < MIN_MS or ms > MAX_MS):
				found.append("frame time: '%s' frame %d is %d ms, allowed %d-%d" % [name, i, ms, MIN_MS, MAX_MS])
				break
	if covered != data.frames.size():found.append("clips cover %d of %d frames" % [covered, data.frames.size()])
	for name in clips:
		if not names.has(name):found.append("meta clip '%s' is not in the sheet" % name)
		var next: String = clips[name].get("next", "")
		if not next.is_empty() and not clips.has(next):found.append("clip '%s' continues to missing '%s'" % [name, next])
	return found

func check_pivot(image: Image, data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var p: Array = meta.get("pivot", [])
	if p.size() != 2:return ["pivot is missing"]
	if p[0] != floorf(p[0]) or p[1] != floorf(p[1]):return ["pivot is not a whole pixel"]
	var cell := cell_of(meta)
	var pivot := Vector2i(int(p[0]), int(p[1]))
	if not Rect2i(Vector2i.ZERO, cell).has_point(pivot):return ["pivot %d,%d is outside the %dx%d cell" % [pivot.x, pivot.y, cell.x, cell.y]]
	if kind.begins_with("tile_"):return [] if pivot == Vector2i(20, 10) else ["pivot of a tile must be 20,10"]
	var box := image.get_region(Rect2i(Vector2i.ZERO, cell)).get_used_rect()
	if not box.has_area():return ["first frame is empty"]
	if pivot.x < box.position.x or pivot.x >= box.end.x:return ["pivot is beside the first frame, not under it"]
	if absi(box.end.y - pivot.y) > 40:return ["pivot is %d px from the base of the first frame" % absi(box.end.y - pivot.y)]
	return []

# ---------------------------------------------------------------- tiles

func tile(image: Image, frame: int, cell: Vector2i) -> Image:
	return image.get_region(Rect2i(Vector2i((frame % 8) * cell.x, (frame / 8) * cell.y), cell))

## Stamps a lattice and returns how often each pixel of the middle is covered.
func cover(t: Image, cell: Vector2i, steps: Array, window: Rect2i) -> Dictionary:
	var count := {}
	for offset: Vector2i in steps:
		for y in cell.y:
			for x in cell.x:
				if t.get_pixel(x, y).a == 0.0:continue
				var at := Vector2i(x, y) + offset
				if window.has_point(at):count[at] = int(count.get(at, 0)) + 1
	return count

func check_tile(image: Image, data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var found: Array = []
	var cell := cell_of(meta)
	if image.get_width() % cell.x != 0 or image.get_height() % cell.y != 0:return found
	if kind == "tile_edge":
		if data.frames.size() != 16:found.append("edge masks: %d frames, expected 16" % data.frames.size())
		else:
			if tile(image, 0, cell).get_used_rect().has_area():found.append("edge masks: mask 0 must be empty")
			for mask in range(1, 16):
				if not tile(image, mask, cell).get_used_rect().has_area():found.append("edge masks: mask %d is empty" % mask)
		return found
	if kind == "tile_side":
		for tag in data.meta.frameTags:
			for frame in range(int(tag.from), int(tag.to) + 1):
				var t := tile(image, frame, cell)
				# A cliff run steps one tile along the grid; stacked cubes step 20 down.
				var direction := Vector2i(20, 10) if str(tag.name).ends_with("left") else Vector2i(20, -10)
				var steps: Array = []
				for a in range(-2, 3):
					for b in range(-4, 5):steps.append(direction * a + Vector2i(0, 20) * b)
				var box := t.get_used_rect()
				var count := cover(t, cell, steps, box)
				for y in range(box.position.y, box.end.y):
					for x in range(box.position.x, box.end.x):
						# The repeated face fills the plane, so empty pixels are gaps too.
						if int(count.get(Vector2i(x, y), 0)) != 1:
							found.append("3x3 seam: side frame %d overlaps or leaves a gap at %d,%d" % [frame, x, y])
							return found
				if box.size.x != 20:
					found.append("3x3 seam: side frame %d is %d columns wide, expected 20" % [frame, box.size.x])
					return found
		return found
	# Caps: every variant next to every variant.
	var lattice: Array = []
	for a in range(-1, 2):
		for b in range(-1, 2):lattice.append(Vector2i((a - b) * 20, (a + b) * 10))
	for frame in data.frames.size():
		var t := tile(image, frame, cell)
		var window := Rect2i(Vector2i.ZERO, cell)
		var count := cover(t, cell, lattice, window)
		for y in cell.y:
			for x in cell.x:
				var n := int(count.get(Vector2i(x, y), 0))
				if n != 1:
					found.append("3x3 seam: cap frame %d has %s at %d,%d" % [frame, "a gap" if n == 0 else "an overlap", x, y])
					return found
		# Marks: pixels that differ from the most common colour.
		var tally := {}
		var total := 0
		for y in cell.y:
			for x in cell.x:
				var c := t.get_pixel(x, y)
				if c.a == 0.0:continue
				total += 1
				tally[c.to_rgba32()] = int(tally.get(c.to_rgba32(), 0)) + 1
		var most: int = tally.values().max()
		if float(total - most) / total > MARK_LIMIT:found.append("marks cover %.0f%% of cap frame %d, limit %.0f%%" % [100.0 * (total - most) / total, frame, 100 * MARK_LIMIT])
		# Seam contrast: colour change across tile borders against change inside the tile.
		var border := 0
		var border_n := 0
		var inner := 0
		var inner_n := 0
		for y in cell.y:
			for x in cell.x:
				if t.get_pixel(x, y).a == 0.0:continue
				for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var at := Vector2i(x, y) + step
					if window.has_point(at) and t.get_pixelv(at).a > 0.0:
						inner_n += 1
						if t.get_pixelv(at) != t.get_pixel(x, y):inner += 1
						continue
					for offset: Vector2i in lattice:
						var other := at - offset
						if offset == Vector2i.ZERO or not window.has_point(other) or t.get_pixelv(other).a == 0.0:continue
						border_n += 1
						if t.get_pixelv(other) != t.get_pixel(x, y):border += 1
						break
		var inside := maxf(float(inner) / maxi(inner_n, 1), 0.05)
		if border_n > 0 and float(border) / border_n > inside * SEAM_RATIO:found.append("3x3 seam: cap frame %d changes colour on %.0f%% of its border, %.0f%% inside" % [frame, 100.0 * border / border_n, 100.0 * inner / inner_n])
	return found

# ---------------------------------------------------------------- source and export

func check_provenance(rel: String, recorded: Dictionary) -> Array:
	var found: Array = []
	var path := source + "/" + rel + ".aseprite"
	if not FileAccess.file_exists(path):found.append("no source: %s.aseprite" % rel)
	if not recorded.has(rel):
		found.append("not in the export manifest")
		return found
	var record: Dictionary = recorded[rel]
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != record.get("source_sha256", ""):found.append("older than its source: export again")
	if FileAccess.get_sha256(assets + "/" + rel + ".png") != record.get("sheet_sha256", ""):found.append("sheet was changed after export")
	if record.get("audit", "") != "ok":found.append("source audit: " + str(record.get("audit", "")))
	return found

func check_orphans(sheets: PackedStringArray, recorded: Dictionary) -> Array:
	var found: Array = []
	for rel in list_files(assets, "json"):
		if rel == "manifest":continue
		var base := rel.trim_suffix(".meta")
		if not sheets.has(base):found.append("orphan file: %s.json has no sheet" % rel)
	for rel in recorded:
		if not sheets.has(rel):found.append("orphan record: %s has no sheet" % rel)
	for rel in list_files(source, "aseprite"):
		if rel.begins_with("_template/") or rel.begins_with("palette/"):continue
		if not sheets.has(rel):found.append("source without sheet: %s.aseprite is not exported" % rel)
	for folder in [assets]:
		for name in all_files(folder):
			if name.get_extension() in ["png", "json", "import"]:continue
			found.append("orphan file: %s" % name)
	return found

static func all_files(folder: String, prefix := "") -> PackedStringArray:
	var result: PackedStringArray = []
	for name in DirAccess.get_files_at(folder):result.append(prefix + name)
	for sub in DirAccess.get_directories_at(folder):result.append_array(all_files(folder + "/" + sub, prefix + sub + "/"))
	return result
