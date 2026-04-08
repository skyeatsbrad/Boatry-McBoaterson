extends Control

# Persistent upgrade shop – spend gold on permanent stat upgrades

const UPGRADES := [
	{"key": "max_hp",   "name": "Vitality", "desc": "+10 HP per level",     "base_cost": 30, "per_level": 20},
	{"key": "damage",   "name": "Power",    "desc": "+5 damage per level",  "base_cost": 40, "per_level": 20},
	{"key": "speed",    "name": "Agility",  "desc": "+0.2 speed per level", "base_cost": 35, "per_level": 20},
	{"key": "xp_bonus", "name": "Wisdom",   "desc": "+10% XP per level",   "base_cost": 50, "per_level": 20},
]

@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var upgrades_container: VBoxContainer = $VBoxContainer/UpgradesContainer
@onready var back_btn: Button = $VBoxContainer/BackButton

var _buy_buttons: Array[Button] = []

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_build_upgrade_rows()
	_refresh()

func _build_upgrade_rows() -> void:
	for child in upgrades_container.get_children():
		child.queue_free()
	_buy_buttons.clear()

	for i in range(UPGRADES.size()):
		var upg: Dictionary = UPGRADES[i]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel_%d" % i
		name_lbl.custom_minimum_size.x = 120
		hbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.name = "DescLabel_%d" % i
		desc_lbl.custom_minimum_size.x = 200
		hbox.add_child(desc_lbl)

		var level_lbl := Label.new()
		level_lbl.name = "LevelLabel_%d" % i
		level_lbl.custom_minimum_size.x = 80
		hbox.add_child(level_lbl)

		var cost_lbl := Label.new()
		cost_lbl.name = "CostLabel_%d" % i
		cost_lbl.custom_minimum_size.x = 100
		hbox.add_child(cost_lbl)

		var buy_btn := Button.new()
		buy_btn.name = "BuyButton_%d" % i
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(70, 30)
		buy_btn.pressed.connect(_on_buy.bind(i))
		hbox.add_child(buy_btn)
		_buy_buttons.append(buy_btn)

		upgrades_container.add_child(hbox)

func _refresh() -> void:
	var gold: int = GameManager.save_data["gold"]
	gold_label.text = "Gold: %d" % gold

	for i in range(UPGRADES.size()):
		var upg: Dictionary = UPGRADES[i]
		var lvl: int = GameManager.save_data["upgrades"][upg["key"]]
		var cost: int = upg["base_cost"] + lvl * upg["per_level"]

		var row: HBoxContainer = upgrades_container.get_child(i)
		(row.get_node("NameLabel_%d" % i) as Label).text = upg["name"]
		(row.get_node("DescLabel_%d" % i) as Label).text = upg["desc"]
		(row.get_node("LevelLabel_%d" % i) as Label).text = "Lv %d" % lvl
		(row.get_node("CostLabel_%d" % i) as Label).text = "%d gold" % cost

		var can_buy := gold >= cost
		_buy_buttons[i].disabled = not can_buy
		if not can_buy:
			_buy_buttons[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			_buy_buttons[i].modulate = Color.WHITE

func _on_buy(index: int) -> void:
	var upg: Dictionary = UPGRADES[index]
	var lvl: int = GameManager.save_data["upgrades"][upg["key"]]
	var cost: int = upg["base_cost"] + lvl * upg["per_level"]

	if GameManager.save_data["gold"] >= cost:
		GameManager.save_data["gold"] -= cost
		GameManager.save_data["upgrades"][upg["key"]] += 1
		GameManager.save_game()
		AudioManager.play("gem")
		_refresh()

func _on_back() -> void:
	AudioManager.play("select")
	visible = false
