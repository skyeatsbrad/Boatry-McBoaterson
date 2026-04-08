extends Node

# Programmatic audio - generates sounds at runtime, no files needed

var sounds := {}
var sfx_volume := 0.7

func _ready() -> void:
	sfx_volume = GameManager.save_data["settings"]["sfx_volume"]
	_generate_sounds()

func _generate_sounds() -> void:
	sounds["shoot"] = _make_tone(600, 0.08, 0.2, "sine")
	sounds["hit"] = _make_tone(200, 0.1, 0.25, "square")
	sounds["kill"] = _make_tone(800, 0.12, 0.2, "sine")
	sounds["gem"] = _make_tone(1200, 0.06, 0.15, "sine")
	sounds["levelup"] = _make_tone(880, 0.3, 0.3, "sine")
	sounds["dash"] = _make_tone(400, 0.15, 0.2, "noise")
	sounds["hurt"] = _make_tone(150, 0.2, 0.3, "square")
	sounds["boss_roar"] = _make_tone(80, 0.5, 0.4, "square")
	sounds["explosion"] = _make_tone(100, 0.3, 0.35, "noise")
	sounds["lightning"] = _make_tone(1500, 0.1, 0.2, "square")
	sounds["heal"] = _make_tone(1000, 0.2, 0.2, "sine")
	sounds["chest"] = _make_tone(660, 0.15, 0.25, "sine")
	sounds["combo"] = _make_tone(1000, 0.05, 0.15, "sine")
	sounds["splash"] = _make_tone(300, 0.2, 0.2, "noise")
	sounds["whirlpool"] = _make_tone(120, 0.4, 0.25, "sine")
	sounds["select"] = _make_tone(500, 0.05, 0.15, "sine")

func _make_tone(freq: float, duration: float, vol: float, wave_type: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var n_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	
	for i in range(n_samples):
		var t := float(i) / sample_rate
		var env := maxf(0.0, 1.0 - float(i) / n_samples)
		var v := 0.0
		
		match wave_type:
			"sine":
				v = sin(2.0 * PI * freq * t)
			"square":
				v = 1.0 if sin(2.0 * PI * freq * t) > 0 else -1.0
			"noise":
				v = randf_range(-1.0, 1.0)
		
		var sample := int(v * vol * env * 32767.0)
		sample = clampi(sample, -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func play(sound_name: String) -> void:
	if sound_name not in sounds:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.volume_db = linear_to_db(sfx_volume)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
