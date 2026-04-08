extends Node

# Global game state & save/load system

signal gold_changed(amount: int)
signal wave_changed(wave: int)
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://save_data.json"
const WORLD_SIZE := Vector2(3000, 3000)

# Persistent data
var save_data := {
	"gold": 0,
	"upgrades": {"max_hp": 0, "damage": 0, "speed": 0, "xp_bonus": 0},
	"high_scores": [],
	"achievements": [],
	"settings": {"sfx_volume": 0.7, "music_volume": 0.5, "fullscreen": false},
	"total_kills": 0,
	"total_runs": 0,
	"games_played": 0,
	"unlocked_skins": [],
}

# Runtime state
var current_wave := 0
var game_time := 0.0
var bosses_killed := 0
var combo_count := 0
var combo_timer := 0.0
var combo_multiplier := 1.0
const COMBO_DECAY_TIME := 2.0
const COMBO_TIER_THRESHOLDS := [5, 15, 30, 50]

# Character definitions
var characters := [
	{
		"name": "Tugboat",
		"color": Color(0.24, 0.47, 0.86),
		"desc": "Balanced fighter. Cannon weapon.",
		"hp_mod": 1.0, "spd_mod": 1.0, "dmg_mod": 1.0,
		"weapon": "cannon",
	},
	{
		"name": "Warship",
		"color": Color(0.63, 0.24, 0.86),
		"desc": "Slow tank. AoE blast weapon.",
		"hp_mod": 1.5, "spd_mod": 0.7, "dmg_mod": 1.3,
		"weapon": "aoe_blast",
	},
	{
		"name": "Speedboat",
		"color": Color(0.2, 0.78, 0.2),
		"desc": "Fast & fragile. Anchor boomerang.",
		"hp_mod": 0.7, "spd_mod": 1.4, "dmg_mod": 1.0,
		"weapon": "boomerang",
	},
	{
		"name": "Sailboat",
		"color": Color(0.0, 0.71, 0.71),
		"desc": "Chain lightning mast weapon.",
		"hp_mod": 0.8, "spd_mod": 1.0, "dmg_mod": 1.3,
		"weapon": "lightning",
	},
]

var selected_character := 0

func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			combo_multiplier = 1.0

func add_combo() -> void:
	combo_count += 1
	combo_timer = COMBO_DECAY_TIME
	# Calculate multiplier from combo tiers
	combo_multiplier = 1.0
	for threshold in COMBO_TIER_THRESHOLDS:
		if combo_count >= threshold:
			combo_multiplier += 0.5
		else:
			break

func get_character() -> Dictionary:
	return characters[selected_character]

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			for key in data:
				if save_data.has(key):
					save_data[key] = data[key]

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))

func add_high_score(kills: int, level: int, wave: int, time_str: String) -> void:
	var entry := {
		"kills": kills,
		"level": level,
		"wave": wave,
		"time": time_str,
		"character": characters[selected_character]["name"],
	}
	save_data["high_scores"].append(entry)
	save_data["high_scores"].sort_custom(func(a, b): return a["kills"] > b["kills"])
	if save_data["high_scores"].size() > 10:
		save_data["high_scores"].resize(10)

func can_unlock_skins() -> bool:
	return save_data["games_played"] >= 5

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in save_data["unlocked_skins"]

func unlock_skin(skin_id: String, cost: int) -> bool:
	if save_data["gold"] >= cost and skin_id not in save_data["unlocked_skins"]:
		save_data["gold"] -= cost
		save_data["unlocked_skins"].append(skin_id)
		save_game()
		return true
	return false
