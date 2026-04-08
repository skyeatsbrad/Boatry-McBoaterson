extends Control

# Character selection screen – pick your boat and customize hull color

signal character_confirmed

const HULL_PRESETS: Array[Color] = [
	Color(0.24, 0.47, 0.86),  # Blue
	Color(0.86, 0.24, 0.24),  # Red
	Color(0.2, 0.78, 0.2),    # Green
	Color(0.86, 0.78, 0.15),  # Yellow
	Color(0.63, 0.24, 0.86),  # Purple
	Color(0.0, 0.71, 0.71),   # Teal
	Color(0.93, 0.46, 0.13),  # Orange
	Color(0.85, 0.44, 0.62),  # Pink
]

@onready var char_container: HBoxContainer = $VBoxContainer/CharacterContainer
@onready var stats_panel: PanelContainer = $VBoxContainer/StatsPanel
@onready var name_label: Label = $VBoxContainer/StatsPanel/VBox/NameLabel
@onready var desc_label: Label = $VBoxContainer/StatsPanel/VBox/DescLabel
@onready var hp_bar: ProgressBar = $VBoxContainer/StatsPanel/VBox/HPBar
@onready var spd_bar: ProgressBar = $VBoxContainer/StatsPanel/VBox/SpeedBar
@onready var dmg_bar: ProgressBar = $VBoxContainer/StatsPanel/VBox/DamageBar
@onready var weapon_label: Label = $VBoxContainer/StatsPanel/VBox/WeaponLabel
@onready var boat_preview: Control = $VBoxContainer/StatsPanel/VBox/BoatPreview
@onready var color_left_btn: Button = $VBoxContainer/StatsPanel/VBox/ColorRow/LeftArrow
@onready var color_right_btn: Button = $VBoxContainer/StatsPanel/VBox/ColorRow/RightArrow
@onready var color_label: Label = $VBoxContainer/StatsPanel/VBox/ColorRow/ColorLabel
@onready var confirm_btn: Button = $VBoxContainer/ConfirmButton
@onready var back_btn: Button = $VBoxContainer/BackButton

var _selected_index := 0
var _color_index := 0
var _char_buttons: Array[Button] = []

func _ready() -> void:
	_selected_index = GameManager.selected_character
	_build_character_buttons()
	color_left_btn.pressed.connect(_on_color_left)
	color_right_btn.pressed.connect(_on_color_right)
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(_on_back)
	_select_character(_selected_index)

func _build_character_buttons() -> void:
	for child in char_container.get_children():
		child.queue_free()
	_char_buttons.clear()

	for i in range(GameManager.characters.size()):
		var ch: Dictionary = GameManager.characters[i]
		var btn := Button.new()
		btn.text = ch["name"]
		btn.custom_minimum_size = Vector2(120, 50)
		btn.pressed.connect(_on_char_button.bind(i))
		char_container.add_child(btn)
		_char_buttons.append(btn)

func _on_char_button(index: int) -> void:
	AudioManager.play("select")
	_select_character(index)

func _select_character(index: int) -> void:
	_selected_index = index
	var ch: Dictionary = GameManager.characters[index]

	name_label.text = ch["name"]
	desc_label.text = ch["desc"]
	hp_bar.value = ch["hp_mod"] * 100.0
	spd_bar.value = ch["spd_mod"] * 100.0
	dmg_bar.value = ch["dmg_mod"] * 100.0
	weapon_label.text = "Weapon: %s" % ch["weapon"].capitalize()

	# Reset color index to match character default
	_color_index = 0
	for ci in range(HULL_PRESETS.size()):
		if HULL_PRESETS[ci].is_equal_approx(ch["color"]):
			_color_index = ci
			break
	_update_color_label()

	# Highlight selected button
	for i in range(_char_buttons.size()):
		_char_buttons[i].disabled = (i == index)

	if boat_preview:
		boat_preview.queue_redraw()

func _on_color_left() -> void:
	_color_index = (_color_index - 1) % HULL_PRESETS.size()
	if _color_index < 0:
		_color_index += HULL_PRESETS.size()
	_update_color_label()
	AudioManager.play("select")

func _on_color_right() -> void:
	_color_index = (_color_index + 1) % HULL_PRESETS.size()
	_update_color_label()
	AudioManager.play("select")

func _update_color_label() -> void:
	var names := ["Blue", "Red", "Green", "Yellow", "Purple", "Teal", "Orange", "Pink"]
	if _color_index < names.size():
		color_label.text = names[_color_index]
	else:
		color_label.text = "Custom"
	if boat_preview:
		boat_preview.queue_redraw()

func get_selected_color() -> Color:
	return HULL_PRESETS[_color_index]

func _on_confirm() -> void:
	GameManager.selected_character = _selected_index
	GameManager.characters[_selected_index]["color"] = get_selected_color()
	GameManager.save_game()
	AudioManager.play("select")
	character_confirmed.emit()

func _on_back() -> void:
	AudioManager.play("select")
	visible = false
