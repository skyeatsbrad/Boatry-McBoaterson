extends Node

# Game mode system — configures spawn rates, boss logic, timers, and scoring.

signal mode_changed(mode: int)
signal speed_run_timer_tick(time_left: float)
signal speed_run_ended(final_score: int)

enum Mode {
	NORMAL,
	BOSS_RUSH,
	SPEED_RUN,
	DAILY_CHALLENGE,
}

const MODE_NAMES := {
	Mode.NORMAL: "Normal",
	Mode.BOSS_RUSH: "Boss Rush",
	Mode.SPEED_RUN: "Speed Run",
	Mode.DAILY_CHALLENGE: "Daily Challenge",
}

const MODE_DESCRIPTIONS := {
	Mode.NORMAL: "Standard wave progression. Survive as long as you can!",
	Mode.BOSS_RUSH: "Only bosses. One after another, each more powerful than the last.",
	Mode.SPEED_RUN: "5-minute blitz! Maximize kills with 2x spawn rate. Bonus score for time left.",
	Mode.DAILY_CHALLENGE: "Fixed daily seed — same run for everyone. Compete on the leaderboard!",
}

var current_mode: int = Mode.NORMAL
var speed_run_time_left := 300.0  # 5 minutes
var speed_run_kills := 0
var daily_seed := 0


func _ready() -> void:
	_calculate_daily_seed()


func set_mode(mode: int) -> void:
	current_mode = mode
	mode_changed.emit(mode)


func get_mode_name() -> String:
	return MODE_NAMES.get(current_mode, "Unknown")


func get_mode_description() -> String:
	return MODE_DESCRIPTIONS.get(current_mode, "")


func _calculate_daily_seed() -> void:
	var date := Time.get_date_dict_from_system()
	daily_seed = date["year"] * 10000 + date["month"] * 100 + date["day"]


func get_daily_seed() -> int:
	_calculate_daily_seed()
	return daily_seed


func get_mode_config() -> Dictionary:
	match current_mode:
		Mode.NORMAL:
			return {
				"spawn_rate": 1.5,
				"boss_interval": 5,
				"time_limit": 0,  # unlimited
				"enemy_types": ["piranha", "pufferfish", "swordfish", "jellyfish",
								"eel", "anglerfish", "shark"],
				"score_multiplier": 1.0,
				"spawn_bosses_only": false,
				"boss_hp_multiplier": 1.0,
			}
		Mode.BOSS_RUSH:
			return {
				"spawn_rate": 0.0,  # no regular enemy spawns
				"boss_interval": 1,  # boss every wave
				"time_limit": 0,
				"enemy_types": [],  # no regular enemies
				"score_multiplier": 2.0,
				"spawn_bosses_only": true,
				"boss_hp_multiplier": 1.0,  # increases per boss in apply_boss_rush_scaling
			}
		Mode.SPEED_RUN:
			return {
				"spawn_rate": 0.75,  # 2x faster (half the delay)
				"boss_interval": 5,
				"time_limit": 300,  # 5 minutes
				"enemy_types": ["piranha", "pufferfish", "swordfish", "jellyfish",
								"eel", "anglerfish", "shark"],
				"score_multiplier": 1.5,
				"spawn_bosses_only": false,
				"boss_hp_multiplier": 1.0,
			}
		Mode.DAILY_CHALLENGE:
			return {
				"spawn_rate": 1.5,
				"boss_interval": 5,
				"time_limit": 0,
				"enemy_types": ["piranha", "pufferfish", "swordfish", "jellyfish",
								"eel", "anglerfish", "shark"],
				"score_multiplier": 1.0,
				"spawn_bosses_only": false,
				"boss_hp_multiplier": 1.0,
				"seed": daily_seed,
			}
	# Fallback
	return {"spawn_rate": 1.5, "boss_interval": 5, "time_limit": 0,
			"enemy_types": [], "score_multiplier": 1.0,
			"spawn_bosses_only": false, "boss_hp_multiplier": 1.0}


# Called once when game_world starts — applies mode config to world settings.
func apply_to_world(game_world: Node2D) -> void:
	var config := get_mode_config()

	if current_mode == Mode.DAILY_CHALLENGE:
		seed(daily_seed)

	if "spawn_rate" in game_world and config["spawn_rate"] > 0:
		game_world.spawn_rate = config["spawn_rate"]

	if current_mode == Mode.SPEED_RUN:
		speed_run_time_left = config["time_limit"]
		speed_run_kills = 0

	if current_mode == Mode.BOSS_RUSH:
		# Disable regular enemy spawns in boss rush
		if "spawn_rate" in game_world:
			game_world.spawn_rate = 99999.0  # effectively never


func process_mode(delta: float, game_world: Node2D) -> void:
	if current_mode == Mode.SPEED_RUN:
		_process_speed_run(delta, game_world)


func _process_speed_run(delta: float, game_world: Node2D) -> void:
	speed_run_time_left -= delta
	speed_run_timer_tick.emit(speed_run_time_left)

	if speed_run_time_left <= 0:
		speed_run_time_left = 0.0
		var bonus := int(speed_run_time_left * 10)  # 0 if ran out
		var config := get_mode_config()
		var final_score := int((speed_run_kills + bonus) * config["score_multiplier"])
		speed_run_ended.emit(final_score)


func register_kill() -> void:
	if current_mode == Mode.SPEED_RUN:
		speed_run_kills += 1


func get_boss_rush_scaling(boss_number: int) -> float:
	# Each successive boss gets 20% more HP
	return 1.0 + boss_number * 0.2


func calculate_final_score(kills: int, wave: int, time_seconds: float) -> int:
	var config := get_mode_config()
	var base := kills * 10 + wave * 50
	if current_mode == Mode.SPEED_RUN and speed_run_time_left > 0:
		base += int(speed_run_time_left * 10)
	return int(base * config["score_multiplier"])


# Placeholder for daily challenge online leaderboard.
func submit_daily_score(player_name: String, score: int) -> void:
	# TODO: implement HTTP request to leaderboard server
	print("Daily Challenge score submitted: %s - %d (seed: %d)" % [player_name, score, daily_seed])


func get_daily_leaderboard() -> Array:
	# TODO: fetch from server
	return []
