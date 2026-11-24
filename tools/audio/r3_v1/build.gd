extends SceneTree
## Deterministic original synthesis. No recordings, external samples or voice acting.
const RATE := 22050
const OUT := "res://assets/audio/World/r3_v1/"
var entries: Array = []

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Call pure builders on an unattached legacy manager: no _ready, profiles or playback.
	var legacy = load("res://Scripts/Autoload/audio_manager.gd").new()
	for row in [["hover",[880.0],0.045],["click",[660.0,880.0],0.06],["interact",[330.0,440.0],0.09],["collect",[659.25,830.61,987.77],0.13],["ignite",[130.81,196.0,261.63],0.14],["rotate",[220.0,293.66],0.08],["page",[523.25,659.25],0.08],["waypoint",[392.0,523.25,783.99],0.18],["warning",[220.0,196.0],0.20],["fail",[392.0,293.66,196.0],0.26],["win",[523.25,659.25,783.99,1046.5],0.22],["step",[95.0],0.055]]:
		save_clip(row[0], legacy._sequence(row[1], row[2]), "legacy procedural UI/puzzle", false, "Scripts/Autoload/audio_manager.gd")
	for row in [["bell_low",261.63],["bell_middle",329.63],["bell_high",392.0]]:
		save_clip(row[0], legacy._bell(row[1]), "legacy puzzle bell", false, "Scripts/Autoload/audio_manager.gd")
	for id in ["thaw","melting","heater","vent","melt"]:
		save_clip(id, legacy._texture_sound("melt_finish" if id == "melt" else id), "legacy material cue", id in ["thaw","melting"], "Scripts/Autoload/audio_manager.gd")
	for surface in ["snow","cement"]:
		for n in range(3):
			save_clip("step_%s%d" % [surface,n], legacy._footstep_sound(surface,n), "legacy character footstep", false, "Scripts/Autoload/audio_manager.gd")
	legacy.free()
	for zone in range(3):
		save_clip("ambience_z%d" % (zone+1), ambience(zone), "zone ambience", true)
	for zone in [1,2]:
		save_clip("music_z%d" % (zone+1), score(zone), "zone music", true)
	for row in [["professor_z1",[220.0,330.0]], ["professor_z2",[392.0,493.88]], ["professor_z3",[293.66,440.0]], ["finn",[261.63,392.0]], ["jump",[196.0,261.63]], ["land",[110.0,82.41]], ["hurt",[164.81,130.81]], ["freeze_complete",[659.25,523.25,783.99]], ["condense_collect",[880.0,659.25]], ["sublimate_complete",[293.66,440.0,587.33]], ["deposit_complete",[587.33,440.0,293.66]], ["valve",[146.83,110.0]], ["mechanism_latch",[130.81,196.0]], ["craft_complete",[261.63,329.63,392.0,523.25]]]:
		save_clip(row[0], notes(row[1]), "optional nonverbal character/puzzle cue", false)
	for kind in ["evaporate","boil","pump"]:
		save_clip(kind, process_loop(kind), "contained puzzle process", true)
	var catalog := {"schema_version":1,"owner":"R3 012","clips":entries,"listening":"pending human audition","integration":"opt-in assets; world/menu/puzzle bindings remain 015/021/023 onward","license":"assets/licenses/phase-quest-audio-r3.txt","pivot":"not applicable","scale":"gain only; no spatial/world transform","reduced":"mute ambient/process beds and optional dialogue cues; retain text/state feedback; no essential audio-only information"}
	FileAccess.open(OUT+"catalog.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t")+"\n")
	print("R3 012 BUILD PASS / %d clips" % entries.size())
	quit()

func save_clip(id: String, wav: AudioStreamWAV, use: String, looped: bool, source := "tools/audio/r3_v1/build.gd") -> void:
	# Original procedural cue samples retained exactly; looping saved through import sidecars.
	var path := OUT+id+".wav"
	assert(wav.save_to_wav(path) == OK)
	entries.append({"id":id,"path":path,"source":source,"use":use,"loop":looped,"gain_db":-23 if "ambience" in id else (-20 if "music" in id else -17),"state":"loop" if looped else "one_shot","reduced":"off" if looped or id.begins_with("professor") or id == "finn" else "same cue; visual feedback authoritative"})

func wav(samples: PackedFloat64Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*2)
	var mean := 0.0
	for x in samples: mean += x
	mean /= samples.size()
	for i in range(samples.size()): bytes.encode_s16(i*2,roundi(clampf(samples[i]-mean,-0.95,0.95)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream

func ambience(zone: int) -> AudioStreamWAV:
	# Periodic Fourier wind/water/ventilation beds: integer cycles ensure wrap continuity.
	var duration := 12.0
	var data := PackedFloat64Array()
	data.resize(int(duration*RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12026+zone
	var bands: Array = []
	for k in range(44): bands.append([rng.randi_range(90,3400),rng.randf()*TAU,rng.randf_range(0.003,0.009)])
	for i in range(data.size()):
		var t := float(i)/RATE
		var value := 0.0
		for b in bands: value += sin(TAU*b[0]*t/duration+b[1])*b[2]
		value *= 0.6+0.25*sin(TAU*(zone+1)*t/duration)
		if zone == 1: value += 0.016*sin(TAU*420*t/duration)*pow(0.5+0.5*sin(TAU*7*t/duration),8)
		if zone == 2: value += 0.014*sin(TAU*720*t/duration)+0.009*sin(TAU*1440*t/duration)
		data[i] = value
	return wav(data,true)

func score(zone: int) -> AudioStreamWAV:
	# 8-bar original sparse motifs at 80 BPM. Circular note tails overlap the loop seam.
	var beat := 0.75
	var duration := beat*32
	var data := PackedFloat64Array()
	data.resize(int(duration*RATE))
	var chords := [[261.63,329.63,392.0],[220.0,261.63,329.63],[174.61,220.0,261.63],[196.0,246.94,293.66]] if zone == 1 else [[146.83,174.61,220.0],[130.81,164.81,196.0],[116.54,146.83,174.61],[130.81,164.81,196.0]]
	for n in range(32):
		var chord: Array = chords[(n/8) as int]
		var f: float = chord[(n*2+n/4) as int % 3] * (2.0 if zone == 1 else 1.0)
		for j in range(int(beat*3*RATE)):
			var t := float(j)/RATE
			var env := minf(t/0.012,1.0)*exp(-t*3.2)*minf((beat*3-t)/0.08,1.0)
			data[(int(n*beat*RATE)+j)%data.size()] += (sin(TAU*f*t)+0.2*sin(TAU*f*2*t))*env*0.10
	return wav(data,true)

func notes(frequencies: Array) -> AudioStreamWAV:
	var beat := 0.12
	var data := PackedFloat64Array()
	data.resize(int((frequencies.size()*beat+0.22)*RATE))
	for n in range(frequencies.size()):
		for j in range(int(0.30*RATE)):
			var t := float(j)/RATE
			var env := minf(t/0.008,1.0)*exp(-t*16)*minf((0.30-t)/0.03,1.0)
			data[int(n*beat*RATE)+j] += sin(TAU*frequencies[n]*t)*env*0.34
	return wav(data,false)

func process_loop(kind: String) -> AudioStreamWAV:
	var data := PackedFloat64Array()
	data.resize(RATE*4)
	for i in range(data.size()):
		var t := float(i)/RATE
		var value := 0.0
		match kind:
			"evaporate": value = (sin(TAU*713*t)+sin(TAU*997*t))*0.025*(0.7+0.3*sin(TAU*t/4))
			"boil": value = sin(TAU*180*t+2*sin(TAU*3*t))*pow(0.5+0.5*sin(TAU*9*t),3)*0.15
			"pump": value = (sin(TAU*80*t)+0.3*sin(TAU*160*t))*0.12*(0.75+0.25*sin(TAU*2*t))
		data[i] = value
	return wav(data,true)
