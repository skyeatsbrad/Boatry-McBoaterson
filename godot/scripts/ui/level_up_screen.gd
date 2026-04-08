extends Control

# Power-up selection overlay shown on level up

signal power_up_selected(power_up: Dictionary)

const POWER_UPS: Array[Dictionary] = [
	{"id": "damage_up",     "name": "Damage Up",      "desc": "+30% projectile damage",   "color": Color(0.9, 0.3, 0.3)},
	{"id": "speed_up",      "name": "Speed Up",        "desc": "+15% move speed",          "color": Color(0.3, 0.9, 0.5)},
	{"id": "multi_shot",    "name": "Multi-Shot",      "desc": "+1 projectile per volley", "color": Color(0.9, 0.9, 0.2)},
	{"id": "fire_rate",     "name": "Fire Rate",       "desc": "25% faster fire rate",     "color": Color(0.9, 0.6, 0.2)},
	{"id": "max_hp_up",     "name": "Max HP Up",       "desc": "+30 max HP & full heal",   "color": Color(0.3, 0.9, 0.3)},
	{"id": "orbital",       "name": "Orbital Blades",  "desc": "Spinning blades orbit you","color": Color(0.6, 0.8, 1.0)},
	{"id": "orbital_plus",  "name": "Orbit+",          "desc": "+2 orbitals & +20 radius", "color": Color(0.5, 0.7, 1.0)},
	{"id": "aura",          "name": "Damage Aura",     "desc": "Constant AoE around you",  "color": Color(0.8, 0.3, 0.8)},
	{"id": "aura_plus",     "name": "Aura+",           "desc": "+30 aura radius & damage", "color": Color(0.7, 0.2, 0.7)},
	{"id": "lightning",     "name": "Lightning",       "desc": "Chain lightning weapon",    "color": Color(1.0, 1.0, 0.4)},
	{"id": "boomerang",     "name": "Boomerang",       "desc": "Returning anchor weapon",  "color": Color(0.6, 0.4, 0.2)},
	{"id": "explosion",     "name": "Explosion",       "desc": "Timed AoE blasts",         "color": Color(1.0, 0.4, 0.1)},
	{"id": "explosion_plus","name": "Explosion+",      "desc": "+50 radius & damage",      "color": Color(1.0, 0.3, 0.0)},
	{"id": "xp_magnet",     "name": "XP Magnet",       "desc": "Double pickup radius",     "color": Color(0.4, 0.9, 0.9)},
]

@onready var title_label: Label = $PanelContainer/VBox/TitleLabel
@onready var choices_container: HBoxContainer = $PanelContainer/VBox/ChoicesContainer
@onready var hint_label: Label = $PanelContainer/VBox/HintLabel

var _current_choices: Array[Dictionary] = []
var _choice_panels: Array[PanelContainer] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hint_label.text = "Press 1, 2, or 3 — or click to choose"

func show_choices(level: int) -> void:
	title_label.text = "LEVEL UP!  (Level %d)" % level

	# Pick 3 unique random power-ups
	var pool := POWER_UPS.duplicate()
	pool.shuffle()
	_current_choices.clear()
	for i in range(mini(3, pool.size())):
		_current_choices.append(pool[i])

	_build_panels()

	visible = true
	get_tree().paused = true

func _build_panels() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	_choice_panels.clear()

	for i in range(_current_choices.size()):
		var pu: Dictionary = _current_choices[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 160)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color(0.12, 0.14, 0.22)
		stylebox.border_color = pu["color"]
		stylebox.border_width_top = 4
		stylebox.border_width_bottom = 4
		stylebox.border_width_left = 4
		stylebox.border_width_right = 4
		stylebox.corner_radius_top_left = 8
		stylebox.corner_radius_top_right = 8
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", stylebox)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)

		var num_label := Label.new()
		num_label.text = "[%d]" % (i + 1)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_color_override("font_color", pu["color"])
		vbox.add_child(num_label)

		var name_label := Label.new()
		name_label.text = pu["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 20)
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = pu["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

		panel.add_child(vbox)
		panel.gui_input.connect(_on_panel_input.bind(i))
		choices_container.add_child(panel)
		_choice_panels.append(panel)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select(0)
			KEY_2:
				_select(1)
			KEY_3:
				_select(2)

func _on_panel_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(index)

func _select(index: int) -> void:
	if index < 0 or index >= _current_choices.size():
		return
	var pu: Dictionary = _current_choices[index]
	AudioManager.play("levelup")
	_apply_power_up(pu)
	power_up_selected.emit(pu)
	visible = false
	get_tree().paused = false

func _apply_power_up(pu: Dictionary) -> void:
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	if not player:
		var root := get_tree().current_scene
		if root and root.has_node("Player"):
			player = root.get_node("Player")
	if not player:
		return

	match pu["id"]:
		"damage_up":
			player.proj_damage = int(player.proj_damage * 1.3)
		"speed_up":
			player.speed *= 1.15
		"multi_shot":
			player.proj_count += 1
		"fire_rate":
			player.proj_cooldown *= 0.75
		"max_hp_up":
			player.max_hp += 30
			player.hp = player.max_hp
			player.hp_changed.emit(player.hp, player.max_hp)
		"orbital":
			player.has_orbit = true
		"orbital_plus":
			player.orbit_count += 2
			player.orbit_radius += 20.0
		"aura":
			player.has_aura = true
		"aura_plus":
			player.aura_radius += 30.0
			player.aura_damage += 5
		"lightning":
			player.weapon_type = "lightning"
		"boomerang":
			player.weapon_type = "boomerang"
		"explosion":
			player.has_explosion = true
		"explosion_plus":
			player.explosion_radius += 50.0
			player.explosion_damage += 30
		"xp_magnet":
			player.xp_bonus *= 2.0
