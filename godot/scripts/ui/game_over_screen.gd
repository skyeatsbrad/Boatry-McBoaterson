extends Control

# Game over overlay – shows run stats and achievement unlocks

@onready var title_label: Label = $PanelContainer/VBox/TitleLabel
@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var achievements_label: Label = $PanelContainer/VBox/AchievementsLabel
@onready var play_again_btn: Button = $PanelContainer/VBox/PlayAgainButton
@onready var menu_btn: Button = $PanelContainer/VBox/MainMenuButton

var _new_achievements: Array[String] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	play_again_btn.pressed.connect(_on_play_again)
	menu_btn.pressed.connect(_on_main_menu)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

	# Connect to player death when available
	call_deferred("_connect_player")

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		var root := get_tree().current_scene
		if root and root.has_node("Player"):
			player = root.get_node("Player")
	if player and player.has_signal("died"):
		player.died.connect(_on_player_died)

func _on_achievement_unlocked(id: String, ach_name: String) -> void:
	_new_achievements.append(ach_name)

func _on_player_died() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		var root := get_tree().current_scene
		if root and root.has_node("Player"):
			player = root.get_node("Player")

	title_label.text = "GAME OVER"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	var mins := int(GameManager.game_time) / 60
	var secs := int(GameManager.game_time) % 60
	var time_str := "%02d:%02d" % [mins, secs]

	var kills := 0
	var level := 1
	var gold := 0
	if player:
		kills = player.kills
		level = player.level
		gold = player.gold

	stats_label.text = (
		"Time Survived: %s\n" % time_str +
		"Kills: %d\n" % kills +
		"Level: %d\n" % level +
		"Wave: %d\n" % (GameManager.current_wave + 1) +
		"Gold Earned: %d" % gold
	)

	if _new_achievements.size() > 0:
		achievements_label.text = "New Achievements:\n" + "\n".join(_new_achievements)
	else:
		achievements_label.text = ""

	visible = true
	get_tree().paused = true

func _on_play_again() -> void:
	_new_achievements.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _on_main_menu() -> void:
	_new_achievements.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
