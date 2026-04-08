extends CanvasLayer

# Storm weather effect - reduces visibility, shakes screen, spawns lightning

@export var duration := 15.0
var timer := 0.0
var flash_timer := 0.0
var is_active := false

@onready var overlay: ColorRect = ColorRect.new()

func _ready() -> void:
	overlay.color = Color(0.1, 0.1, 0.2, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func start_storm(dur: float = 15.0) -> void:
	duration = dur
	timer = duration
	is_active = true
	AudioManager.play("explosion")

func _process(delta: float) -> void:
	if not is_active:
		return
	
	timer -= delta
	flash_timer -= delta
	
	if timer <= 0:
		is_active = false
		overlay.color.a = 0.0
		return
	
	# Fog overlay (darker during storm)
	var intensity := clampf(timer / duration, 0.0, 1.0)
	var base_alpha := 0.3 * intensity
	
	# Random lightning flashes
	if flash_timer <= 0 and randf() < 0.02:
		flash_timer = 0.1
		overlay.color = Color(0.8, 0.85, 1.0, 0.4)
	elif flash_timer <= 0:
		overlay.color = Color(0.1, 0.1, 0.2, base_alpha)
