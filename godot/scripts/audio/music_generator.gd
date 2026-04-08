extends Node

# Procedural ocean ambient music using AudioStreamGenerator.
# Layers: bass drone, wave rhythm, wind noise.
# Boss mode adds intensity.

const SAMPLE_RATE := 22050.0
const BUFFER_SIZE := 512

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase_bass := 0.0
var _phase_wave := 0.0
var _noise_state := 0.0

var boss_mode := false
var _boss_blend := 0.0  # 0.0 = calm, 1.0 = boss
const CROSSFADE_SPEED := 1.5

var volume_db := -18.0

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func _process(delta: float) -> void:
	# Crossfade toward target mode
	var target := 1.0 if boss_mode else 0.0
	_boss_blend = move_toward(_boss_blend, target, CROSSFADE_SPEED * delta)

	# Apply volume from settings
	if GameManager and GameManager.save_data.has("settings"):
		var music_vol: float = GameManager.save_data["settings"].get("sfx_volume", 0.5)
		volume_db = linear_to_db(clampf(music_vol * 0.3, 0.01, 1.0))
	_player.volume_db = volume_db

	_fill_buffer()

func _fill_buffer() -> void:
	if _playback == null:
		return

	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	var inv_rate := 1.0 / SAMPLE_RATE

	for i in frames:
		var sample := 0.0

		# --- Bass drone ---
		var bass_freq := lerpf(80.0, 60.0, _boss_blend)
		_phase_bass += bass_freq * inv_rate
		if _phase_bass > 1.0:
			_phase_bass -= 1.0
		var bass := sin(_phase_bass * TAU) * lerpf(0.08, 0.15, _boss_blend)
		sample += bass

		# --- Wave rhythm (amplitude modulation) ---
		var wave_freq := lerpf(0.5, 1.2, _boss_blend)
		_phase_wave += wave_freq * inv_rate
		if _phase_wave > 1.0:
			_phase_wave -= 1.0
		var wave_env := (sin(_phase_wave * TAU) + 1.0) * 0.5
		var wave_noise := _next_noise() * lerpf(0.04, 0.07, _boss_blend)
		sample += wave_noise * wave_env

		# --- Wind layer (filtered noise) ---
		var wind := _next_noise() * lerpf(0.025, 0.04, _boss_blend)
		# Simple low-pass: blend with previous
		_noise_state = _noise_state * 0.95 + wind * 0.05
		sample += _noise_state

		# --- Boss pulse (low sub-bass throb) ---
		if _boss_blend > 0.01:
			var pulse := sin(_phase_wave * TAU * 2.0) * 0.06 * _boss_blend
			sample += pulse

		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))


var _rng_state := 12345

func _next_noise() -> float:
	# Simple xorshift pseudo-random for deterministic noise
	_rng_state ^= _rng_state << 13
	_rng_state ^= _rng_state >> 17
	_rng_state ^= _rng_state << 5
	return float(_rng_state % 10000) / 5000.0 - 1.0

func set_boss_mode(enabled: bool) -> void:
	boss_mode = enabled

func set_volume(linear: float) -> void:
	volume_db = linear_to_db(clampf(linear, 0.01, 1.0))
