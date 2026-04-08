extends Control

# Game mode selection screen — pick Normal, Boss Rush, Speed Run, or Daily Challenge.

signal mode_selected(mode: int)
signal back_pressed

const GameModeManager := preload("res://scripts/game_modes/game_mode_manager.gd")

const CARD_SIZE := Vector2(180, 220)
const CARD_PADDING := 20.0

var selected_mode: int = 0  # GameModeManager.Mode.NORMAL
var _hovered_mode := -1

# Mode display data
var _modes := [
	{
		"mode": 0,  # NORMAL
		"name": "Normal",
		"desc": "Standard wave progression.\nSurvive as long as you can!",
		"icon_color": Color(0.2, 0.6, 1.0),
		"icon_symbol": "~",
	},
	{
		"mode": 1,  # BOSS_RUSH
		"name": "Boss Rush",
		"desc": "Only bosses spawn.\nEach one tougher than the last!",
		"icon_color": Color(0.9, 0.2, 0.2),
		"icon_symbol": "!",
	},
	{
		"mode": 2,  # SPEED_RUN
		"name": "Speed Run",
		"desc": "5-minute blitz! 2x spawn rate.\nBonus score for remaining time.",
		"icon_color": Color(0.2, 0.9, 0.3),
		"icon_symbol": ">",
	},
	{
		"mode": 3,  # DAILY_CHALLENGE
		"name": "Daily Challenge",
		"desc": "Fixed daily seed. Same run\nfor everyone today!",
		"icon_color": Color(1.0, 0.84, 0.0),
		"icon_symbol": "*",
	},
]

var _daily_seed := 0

@onready var back_btn: Button = $BackButton
@onready var play_btn: Button = $PlayButton


func _ready() -> void:
	_calculate_daily_seed()

	if back_btn:
		back_btn.pressed.connect(_on_back)
	else:
		back_btn = Button.new()
		back_btn.name = "BackButton"
		back_btn.text = "Back"
		back_btn.position = Vector2(20, 20)
		back_btn.custom_minimum_size = Vector2(100, 40)
		back_btn.pressed.connect(_on_back)
		add_child(back_btn)

	if play_btn:
		play_btn.pressed.connect(_on_play)
	else:
		play_btn = Button.new()
		play_btn.name = "PlayButton"
		play_btn.text = "Play"
		play_btn.position = Vector2(size.x / 2.0 - 60, size.y - 70)
		play_btn.custom_minimum_size = Vector2(120, 50)
		play_btn.pressed.connect(_on_play)
		add_child(play_btn)


func _calculate_daily_seed() -> void:
	var date := Time.get_date_dict_from_system()
	_daily_seed = date["year"] * 10000 + date["month"] * 100 + date["day"]


func _on_back() -> void:
	AudioManager.play("select")
	back_pressed.emit()
	visible = false


func _on_play() -> void:
	AudioManager.play("select")
	mode_selected.emit(selected_mode)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _get_card_at(event.position)
		if clicked >= 0:
			selected_mode = _modes[clicked]["mode"]
			AudioManager.play("select")
			queue_redraw()

	if event is InputEventMouseMotion:
		var hovered := _get_card_at(event.position)
		if hovered != _hovered_mode:
			_hovered_mode = hovered
			queue_redraw()


func _get_card_at(pos: Vector2) -> int:
	var total_width := _modes.size() * (CARD_SIZE.x + CARD_PADDING) - CARD_PADDING
	var start_x := (size.x - total_width) / 2.0
	var card_y := 120.0

	for i in range(_modes.size()):
		var card_x := start_x + i * (CARD_SIZE.x + CARD_PADDING)
		var rect := Rect2(Vector2(card_x, card_y), CARD_SIZE)
		if rect.has_point(pos):
			return i
	return -1


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.12, 0.95))

	# Title
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 80, 50),
				"SELECT GAME MODE", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)

	# Mode cards
	var total_width := _modes.size() * (CARD_SIZE.x + CARD_PADDING) - CARD_PADDING
	var start_x := (size.x - total_width) / 2.0
	var card_y := 120.0

	for i in range(_modes.size()):
		var mode_data: Dictionary = _modes[i]
		var card_x := start_x + i * (CARD_SIZE.x + CARD_PADDING)
		var pos := Vector2(card_x, card_y)
		var is_selected := mode_data["mode"] == selected_mode
		var is_hovered := i == _hovered_mode
		_draw_card(pos, mode_data, is_selected, is_hovered)

	# Daily seed display
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 60, size.y - 90),
				"Daily Seed: %d" % _daily_seed, HORIZONTAL_ALIGNMENT_CENTER,
				-1, 12, Color(0.6, 0.6, 0.7))


func _draw_card(pos: Vector2, data: Dictionary, is_selected: bool, is_hovered: bool) -> void:
	var icon_color: Color = data["icon_color"]

	# Card background
	var bg_color := Color(0.15, 0.18, 0.28) if not is_selected else Color(0.2, 0.25, 0.4)
	if is_hovered and not is_selected:
		bg_color = bg_color.lightened(0.1)
	draw_rect(Rect2(pos, CARD_SIZE), bg_color)

	# Border
	var border_color := icon_color if is_selected else Color(0.3, 0.3, 0.4)
	var border_width := 3.0 if is_selected else 1.0
	draw_rect(Rect2(pos, CARD_SIZE), border_color, false, border_width)

	# Selection indicator
	if is_selected:
		draw_string(ThemeDB.fallback_font, pos + Vector2(CARD_SIZE.x - 20, 18),
					"✓", HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, icon_color)

	# Icon circle
	var icon_center := pos + Vector2(CARD_SIZE.x / 2.0, 55)
	draw_circle(icon_center, 28.0, Color(icon_color.r, icon_color.g, icon_color.b, 0.2))
	draw_circle(icon_center, 28.0, icon_color, false, 2.0)
	draw_string(ThemeDB.fallback_font, icon_center + Vector2(-6, 8),
				data["icon_symbol"], HORIZONTAL_ALIGNMENT_CENTER, -1, 24, icon_color)

	# Name
	draw_string(ThemeDB.fallback_font, pos + Vector2(10, 110),
				data["name"], HORIZONTAL_ALIGNMENT_LEFT,
				int(CARD_SIZE.x - 20), 16, Color.WHITE)

	# Description
	var desc_lines: PackedStringArray = data["desc"].split("\n")
	for line_i in range(desc_lines.size()):
		draw_string(ThemeDB.fallback_font, pos + Vector2(10, 135 + line_i * 14),
					desc_lines[line_i], HORIZONTAL_ALIGNMENT_LEFT,
					int(CARD_SIZE.x - 20), 11, Color(0.7, 0.7, 0.75))

	# Daily seed on Daily Challenge card
	if data["mode"] == 3:  # DAILY_CHALLENGE
		draw_string(ThemeDB.fallback_font, pos + Vector2(10, CARD_SIZE.y - 15),
					"Seed: %d" % _daily_seed, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 10, Color(0.8, 0.7, 0.3))
