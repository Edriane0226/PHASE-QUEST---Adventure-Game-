extends SceneTree

func _initialize() -> void:
	var stream := AudioStreamMP3.load_from_file("res://Assets/Audio/Footsteps/wet_walk_source.mp3")
	var playback := stream.instantiate_playback()
	playback.start()
	var rate := int(AudioServer.get_mix_rate())
	var samples := playback.mix_audio(1.0,int(stream.get_length()*rate))
	var pcm := PackedByteArray()
	pcm.resize(samples.size()*2)
	for i in range(samples.size()):
		pcm.encode_s16(i*2,int(clampf((samples[i].x+samples[i].y)*0.5,-1.0,1.0)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = pcm
	wav.save_to_wav("res://tests/wet-walk-decoded.wav")
	print("Decoded source at ",rate," Hz")
	quit()
