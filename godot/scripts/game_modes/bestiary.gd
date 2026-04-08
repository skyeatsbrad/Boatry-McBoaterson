extends Node

# Ship log / bestiary — tracks all enemy types encountered.
# Saves discovery and kill data to GameManager.save_data.

signal entry_updated(enemy_type: String)
signal new_discovery(enemy_type: String)

const SAVE_KEY := "bestiary"

# All known enemy types with metadata
var entries := {
	"piranha": {
		"name": "Piranha",
		"desc": "Small but vicious. Attacks in swarms with razor-sharp teeth.",
		"seen": false,
		"killed": 0,
		"color": Color(0.86, 0.16, 0.16),
	},
	"pufferfish": {
		"name": "Pufferfish",
		"desc": "Inflates with spikes when threatened. Explodes on death!",
		"seen": false,
		"killed": 0,
		"color": Color(1.0, 0.75, 0.3),
	},
	"swordfish": {
		"name": "Swordfish",
		"desc": "Lightning-fast charges that pierce through defenses.",
		"seen": false,
		"killed": 0,
		"color": Color(0.4, 0.6, 0.9),
	},
	"jellyfish": {
		"name": "Jellyfish",
		"desc": "Drifts slowly but paralyzes on contact with venomous tentacles.",
		"seen": false,
		"killed": 0,
		"color": Color(0.7, 0.3, 0.9),
	},
	"eel": {
		"name": "Electric Eel",
		"desc": "Slithers through the waves, zapping nearby boats with chain lightning.",
		"seen": false,
		"killed": 0,
		"color": Color(0.2, 0.8, 0.8),
	},
	"anglerfish": {
		"name": "Anglerfish",
		"desc": "Lurks in the deep, luring sailors with its glowing decoy light.",
		"seen": false,
		"killed": 0,
		"color": Color(0.3, 0.3, 0.5),
	},
	"shark": {
		"name": "Great White Shark",
		"desc": "The ocean's apex predator. Massive HP, massive damage.",
		"seen": false,
		"killed": 0,
		"color": Color(0.5, 0.5, 0.6),
	},
	"kraken": {
		"name": "Kraken",
		"desc": "King of the Sea. Crowned terror with eight thrashing tentacles.",
		"seen": true if false else false,  # boss — discovered on encounter
		"killed": 0,
		"color": Color(0.55, 0.15, 0.35),
		"is_boss": true,
	},
}


func _ready() -> void:
	_load_from_save()


func record_seen(enemy_type: String) -> void:
	if enemy_type not in entries:
		return
	if not entries[enemy_type]["seen"]:
		entries[enemy_type]["seen"] = true
		new_discovery.emit(enemy_type)
	entry_updated.emit(enemy_type)
	_save()


func record_kill(enemy_type: String) -> void:
	if enemy_type not in entries:
		return
	if not entries[enemy_type]["seen"]:
		entries[enemy_type]["seen"] = true
		new_discovery.emit(enemy_type)
	entries[enemy_type]["killed"] += 1
	entry_updated.emit(enemy_type)
	_save()


func get_entry(enemy_type: String) -> Dictionary:
	if enemy_type in entries:
		return entries[enemy_type]
	return {}


func get_all_entries() -> Dictionary:
	return entries


func get_discovered_count() -> int:
	var count := 0
	for key in entries:
		if entries[key]["seen"]:
			count += 1
	return count


func get_total_count() -> int:
	return entries.size()


func get_total_kills() -> int:
	var total := 0
	for key in entries:
		total += entries[key]["killed"]
	return total


func is_discovered(enemy_type: String) -> bool:
	if enemy_type in entries:
		return entries[enemy_type]["seen"]
	return false


func _save() -> void:
	var save_dict := {}
	for key in entries:
		save_dict[key] = {
			"seen": entries[key]["seen"],
			"killed": entries[key]["killed"],
		}
	GameManager.save_data[SAVE_KEY] = save_dict
	GameManager.save_game()


func _load_from_save() -> void:
	if SAVE_KEY not in GameManager.save_data:
		return
	var data: Dictionary = GameManager.save_data[SAVE_KEY]
	for key in data:
		if key in entries:
			entries[key]["seen"] = data[key].get("seen", false)
			entries[key]["killed"] = data[key].get("killed", 0)
