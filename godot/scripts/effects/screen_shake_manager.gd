extends Node

# Centralized screen shake — call shake() and read get_offset() from your camera.

const LIGHT := 3.0       # hit enemy
const MEDIUM := 6.0      # take damage, explosion
const HEAVY := 12.0      # boss death
const EARTHQUAKE := 20.0 # kraken tentacle slam

const DECAY_RATE := 0.85

var _intensity := 0.0
var _offset := Vector2.ZERO

func shake(intensity: float) -> void:
	_intensity = maxf(_intensity, intensity)

func get_offset() -> Vector2:
	return _offset

func _process(_delta: float) -> void:
	if _intensity > 0.3:
		_offset = Vector2(
			randf_range(-_intensity, _intensity),
			randf_range(-_intensity, _intensity)
		)
		_intensity *= DECAY_RATE
	else:
		_intensity = 0.0
		_offset = Vector2.ZERO
