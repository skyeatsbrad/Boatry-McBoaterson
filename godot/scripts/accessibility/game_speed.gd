extends Node

## Game speed controller (autoload). Adjusts Engine.time_scale while keeping
## UI/menu animations unaffected via process_mode.

const SPEED_OPTIONS := [0.5, 0.75, 1.0, 1.25, 1.5]
const DEFAULT_SPEED := 1.0

var _current_speed := DEFAULT_SPEED

func _ready() -> void:
	# This node always processes so UI stays responsive at normal speed
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_setting()

## Get the current game speed multiplier.
func get_speed() -> float:
	return _current_speed

## Set game speed. Clamps to allowed options; defaults to 1.0 if invalid.
func set_speed(speed: float) -> void:
	if speed not in SPEED_OPTIONS:
		# Snap to nearest allowed value
		var best := DEFAULT_SPEED
		var best_dist := 999.0
		for opt in SPEED_OPTIONS:
			if absf(opt - speed) < best_dist:
				best_dist = absf(opt - speed)
				best = opt
		speed = best

	_current_speed = speed
	Engine.time_scale = _current_speed
	_save_setting()

## Cycle to the next speed option. Wraps around.
func cycle_speed() -> float:
	var idx := SPEED_OPTIONS.find(_current_speed)
	idx = (idx + 1) % SPEED_OPTIONS.size()
	set_speed(SPEED_OPTIONS[idx])
	return _current_speed

## Get index of current speed in SPEED_OPTIONS (useful for UI sliders).
func get_speed_index() -> int:
	return SPEED_OPTIONS.find(_current_speed)

func _load_setting() -> void:
	if GameManager.save_data["settings"].has("game_speed"):
		var saved: float = GameManager.save_data["settings"]["game_speed"]
		set_speed(saved)

func _save_setting() -> void:
	GameManager.save_data["settings"]["game_speed"] = _current_speed
	GameManager.save_game()
