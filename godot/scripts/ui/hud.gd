extends CanvasLayer

# In-game HUD – health, XP, gold, wave, time, kills, combo, minimap

@onready var hp_bar: ProgressBar = $MarginContainer/TopBar/HPBar
@onready var xp_bar: ProgressBar = $MarginContainer/TopBar/XPBar
@onready var gold_label: Label = $MarginContainer/TopBar/GoldLabel
@onready var wave_label: Label = $MarginContainer/TopBar/WaveLabel
@onready var time_label: Label = $MarginContainer/TopBar/TimeLabel
@onready var kills_label: Label = $MarginContainer/BottomBar/KillsLabel
@onready var weapon_label: Label = $MarginContainer/BottomBar/WeaponLabel
@onready var combo_label: Label = $MarginContainer/BottomBar/ComboLabel
@onready var dash_hint: Label = $MarginContainer/BottomBar/DashHint
@onready var minimap_container: SubViewportContainer = $MinimapContainer

var _combo_fade_timer := 0.0
var _player: CharacterBody2D = null

func _ready() -> void:
	# Defer player connection to let the scene tree settle
	call_deferred("_connect_player")
	GameManager.wave_changed.connect(_on_wave_changed)
	dash_hint.text = "SPACE to dash"

	if combo_label:
		combo_label.modulate.a = 0.0

	_update_wave(0)
	_update_time(0.0)

func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		# Fallback: look for Player node in scene tree
		var root := get_tree().current_scene
		if root and root.has_node("Player"):
			_player = root.get_node("Player")
	if _player:
		_player.hp_changed.connect(_on_hp_changed)
		_player.xp_changed.connect(_on_xp_changed)
		_player.leveled_up.connect(_on_leveled_up)
		# Initialize bars
		_on_hp_changed(_player.hp, _player.max_hp)
		_on_xp_changed(_player.xp, _player.xp_to_next)
		weapon_label.text = _player.weapon_type.capitalize()

func _process(delta: float) -> void:
	if _player:
		_update_time(GameManager.game_time)
		kills_label.text = "Kills: %d" % _player.kills
		gold_label.text = "Gold: %d" % _player.gold

		# Combo display
		if GameManager.combo_count > 1:
			combo_label.text = "COMBO x%d  (%.1fx)" % [GameManager.combo_count, GameManager.combo_multiplier]
			combo_label.modulate.a = 1.0
			_combo_fade_timer = 1.5
		elif _combo_fade_timer > 0:
			_combo_fade_timer -= delta
			combo_label.modulate.a = maxf(0.0, _combo_fade_timer / 1.5)

func _on_hp_changed(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

func _on_xp_changed(current: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(level: int) -> void:
	xp_bar.value = 0
	wave_label.text = "Wave %d  |  Lv %d" % [GameManager.current_wave + 1, level]

func _on_wave_changed(wave: int) -> void:
	_update_wave(wave)

func _update_wave(wave: int) -> void:
	var lvl := 1
	if _player:
		lvl = _player.level
	wave_label.text = "Wave %d  |  Lv %d" % [wave + 1, lvl]

func _update_time(elapsed: float) -> void:
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	time_label.text = "%02d:%02d" % [mins, secs]
