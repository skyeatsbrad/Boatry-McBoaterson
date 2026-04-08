extends Node

## Haptic/vibration manager (autoload). Wraps Input.vibrate_handheld() with
## preset intensities. No-op on desktop platforms.

var enabled := true:
	set(value):
		enabled = value
		_save_setting()

var _is_mobile := false

func _ready() -> void:
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_load_setting()

# --- Public API ---

## Light vibration (20 ms) — gem pickup, menu select
func vibrate_light() -> void:
	_vibrate(20)

## Medium vibration (50 ms) — hit enemy, dash
func vibrate_medium() -> void:
	_vibrate(50)

## Heavy vibration (100 ms) — take damage, boss kill, explosion
func vibrate_heavy() -> void:
	_vibrate(100)

## Custom vibration pattern. Each entry is a duration in ms.
## Alternates between vibration and pause starting with vibration.
func vibrate_pattern(pattern: Array) -> void:
	if not _can_vibrate():
		return
	# Run the pattern on a coroutine so we don't block
	_run_pattern(pattern)

# --- Internals ---

func _can_vibrate() -> bool:
	return enabled and _is_mobile

func _vibrate(duration_ms: int) -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(duration_ms)

func _run_pattern(pattern: Array) -> void:
	for i in range(pattern.size()):
		var duration_ms: int = int(pattern[i])
		if i % 2 == 0:
			Input.vibrate_handheld(duration_ms)
		# Wait for the duration before next step
		await get_tree().create_timer(duration_ms / 1000.0).timeout

func _load_setting() -> void:
	if GameManager.save_data["settings"].has("haptic_enabled"):
		enabled = GameManager.save_data["settings"]["haptic_enabled"]

func _save_setting() -> void:
	GameManager.save_data["settings"]["haptic_enabled"] = enabled
	GameManager.save_game()
