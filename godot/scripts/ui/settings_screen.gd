extends Control

# Settings screen – SFX volume, fullscreen, FPS counter

@onready var sfx_slider: HSlider = $VBoxContainer/SFXRow/SFXSlider
@onready var sfx_value_label: Label = $VBoxContainer/SFXRow/SFXValueLabel
@onready var fullscreen_check: CheckButton = $VBoxContainer/FullscreenCheck
@onready var fps_check: CheckButton = $VBoxContainer/FPSCheck
@onready var back_btn: Button = $VBoxContainer/BackButton

func _ready() -> void:
	var settings: Dictionary = GameManager.save_data["settings"]

	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = settings.get("sfx_volume", 0.7) * 100.0
	sfx_slider.value_changed.connect(_on_sfx_changed)
	_update_sfx_label(sfx_slider.value)

	fullscreen_check.button_pressed = settings.get("fullscreen", false)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	fps_check.button_pressed = settings.get("show_fps", false)
	fps_check.toggled.connect(_on_fps_toggled)

	back_btn.pressed.connect(_on_back)

func _on_sfx_changed(value: float) -> void:
	var vol := value / 100.0
	GameManager.save_data["settings"]["sfx_volume"] = vol
	AudioManager.set_volume(vol)
	_update_sfx_label(value)

func _update_sfx_label(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(value)

func _on_fullscreen_toggled(on: bool) -> void:
	GameManager.save_data["settings"]["fullscreen"] = on
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_fps_toggled(on: bool) -> void:
	GameManager.save_data["settings"]["show_fps"] = on

func _on_back() -> void:
	GameManager.save_game()
	AudioManager.play("select")
	visible = false
