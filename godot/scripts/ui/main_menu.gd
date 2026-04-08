extends Control

# Main menu for Boatry McBoaterson

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var characters_btn: Button = $VBoxContainer/CharactersButton
@onready var upgrades_btn: Button = $VBoxContainer/UpgradesButton
@onready var achievements_btn: Button = $VBoxContainer/AchievementsButton
@onready var high_scores_btn: Button = $VBoxContainer/HighScoresButton
@onready var settings_btn: Button = $VBoxContainer/SettingsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

@onready var characters_panel: Control = $CharactersPanel
@onready var upgrades_panel: Control = $UpgradesPanel
@onready var achievements_panel: Control = $AchievementsPanel
@onready var high_scores_panel: Control = $HighScoresPanel
@onready var settings_panel: Control = $SettingsPanel

var _panels: Array[Control] = []

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	characters_btn.pressed.connect(_on_characters)
	upgrades_btn.pressed.connect(_on_upgrades)
	achievements_btn.pressed.connect(_on_achievements)
	high_scores_btn.pressed.connect(_on_high_scores)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	_panels = [characters_panel, upgrades_panel, achievements_panel,
			   high_scores_panel, settings_panel]
	_hide_all_panels()

func _hide_all_panels() -> void:
	for panel in _panels:
		if panel:
			panel.visible = false

func _show_panel(panel: Control) -> void:
	_hide_all_panels()
	if panel:
		panel.visible = true
	AudioManager.play("select")

func _on_play() -> void:
	AudioManager.play("select")
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _on_characters() -> void:
	_show_panel(characters_panel)

func _on_upgrades() -> void:
	_show_panel(upgrades_panel)

func _on_achievements() -> void:
	_show_panel(achievements_panel)

func _on_high_scores() -> void:
	_show_panel(high_scores_panel)

func _on_settings() -> void:
	_show_panel(settings_panel)

func _on_quit() -> void:
	get_tree().quit()
