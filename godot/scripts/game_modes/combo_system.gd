extends Node

# Enhanced combo system with tiers, multipliers, and visual feedback.
# Add as child of game_world or as autoload.

signal combo_changed(count: int, tier: int, multiplier: float)
signal tier_up(tier: int, tier_name: String)
signal combo_reset

enum Tier { NONE, BRONZE, SILVER, GOLD, DIAMOND }

const TIER_THRESHOLDS := {
	Tier.BRONZE: 5,
	Tier.SILVER: 15,
	Tier.GOLD: 30,
	Tier.DIAMOND: 50,
}

const TIER_NAMES := {
	Tier.NONE: "",
	Tier.BRONZE: "Bronze",
	Tier.SILVER: "Silver",
	Tier.GOLD: "Gold",
	Tier.DIAMOND: "Diamond",
}

const TIER_COLORS := {
	Tier.NONE: Color.WHITE,
	Tier.BRONZE: Color(0.80, 0.50, 0.20),
	Tier.SILVER: Color(0.75, 0.75, 0.78),
	Tier.GOLD: Color(1.0, 0.84, 0.0),
	Tier.DIAMOND: Color(0.6, 0.85, 1.0),
}

const TIER_XP_MULTIPLIERS := {
	Tier.NONE: 1.0,
	Tier.BRONZE: 1.5,
	Tier.SILVER: 2.0,
	Tier.GOLD: 3.0,
	Tier.DIAMOND: 5.0,
}

const TIER_GOLD_MULTIPLIERS := {
	Tier.NONE: 1.0,
	Tier.BRONZE: 1.25,
	Tier.SILVER: 1.5,
	Tier.GOLD: 2.0,
	Tier.DIAMOND: 3.0,
}

const DECAY_TIME := 2.0

var combo_count := 0
var combo_timer := 0.0
var current_tier: int = Tier.NONE
var xp_multiplier := 1.0
var gold_multiplier := 1.0

# Visual state
var shake_timer := 0.0
var shake_intensity := 0.0


func _process(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset_combo()

	if shake_timer > 0:
		shake_timer -= delta


func add_kill() -> void:
	combo_count += 1
	combo_timer = DECAY_TIME

	var old_tier := current_tier
	_update_tier()

	# Sync with GameManager
	GameManager.combo_count = combo_count
	GameManager.combo_multiplier = xp_multiplier

	if current_tier > old_tier:
		shake_timer = 0.4
		shake_intensity = 8.0 + current_tier * 4.0
		tier_up.emit(current_tier, TIER_NAMES[current_tier])
		AudioManager.play("combo")

	combo_changed.emit(combo_count, current_tier, xp_multiplier)


func _update_tier() -> void:
	if combo_count >= TIER_THRESHOLDS[Tier.DIAMOND]:
		current_tier = Tier.DIAMOND
	elif combo_count >= TIER_THRESHOLDS[Tier.GOLD]:
		current_tier = Tier.GOLD
	elif combo_count >= TIER_THRESHOLDS[Tier.SILVER]:
		current_tier = Tier.SILVER
	elif combo_count >= TIER_THRESHOLDS[Tier.BRONZE]:
		current_tier = Tier.BRONZE
	else:
		current_tier = Tier.NONE

	xp_multiplier = TIER_XP_MULTIPLIERS[current_tier]
	gold_multiplier = TIER_GOLD_MULTIPLIERS[current_tier]


func _reset_combo() -> void:
	combo_count = 0
	current_tier = Tier.NONE
	xp_multiplier = 1.0
	gold_multiplier = 1.0
	GameManager.combo_count = 0
	GameManager.combo_multiplier = 1.0
	combo_reset.emit()


func get_tier_color() -> Color:
	return TIER_COLORS[current_tier]


func get_tier_name() -> String:
	return TIER_NAMES[current_tier]


func get_display_text() -> String:
	if combo_count < TIER_THRESHOLDS[Tier.BRONZE]:
		return "%dx" % combo_count if combo_count > 0 else ""
	return "%dx %s" % [combo_count, TIER_NAMES[current_tier]]


func get_shake_offset() -> Vector2:
	if shake_timer <= 0:
		return Vector2.ZERO
	var intensity := shake_intensity * (shake_timer / 0.4)
	return Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))


func get_decay_ratio() -> float:
	if combo_count == 0:
		return 0.0
	return combo_timer / DECAY_TIME
