extends Node2D

# Main game scene - manages ocean world, spawning, camera, and game state

const WAVE_DURATION := 30.0
const BOSS_WAVE_INTERVAL := 5
const INITIAL_SPAWN_RATE := 1.5  # seconds between spawns
const MIN_SPAWN_RATE := 0.25
const SPAWN_DIST_MIN := 400.0
const SPAWN_DIST_MAX := 600.0
const CHEST_SPAWN_INTERVAL := 45.0
const FLOATING_ITEM_INTERVAL := 10.0
const STORM_CHANCE_PER_WAVE := 0.15
const WHIRLPOOL_CHANCE_PER_WAVE := 0.2

# Object pool sizes for performance
const POOL_ENEMY := 200
const POOL_PROJECTILE := 100
const POOL_GEM := 300

var wave := 0
var wave_timer := 0.0
var spawn_timer := 0.0
var spawn_rate := INITIAL_SPAWN_RATE
var chest_timer := 0.0
var float_item_timer := 0.0
var game_time := 0.0
var boss_spawned_this_wave := false
var screen_shake_amount := 0.0
var is_storm := false
var storm_timer := 0.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var ocean_bg: ColorRect = $OceanBackground
@onready var enemies_node: Node2D = $Enemies
@onready var projectiles_node: Node2D = $Projectiles
@onready var pickups_node: Node2D = $Pickups
@onready var effects_node: Node2D = $Effects

func _ready() -> void:
	GameManager.current_wave = 0
	GameManager.game_time = 0.0
	GameManager.bosses_killed = 0
	GameManager.combo_count = 0
	
	# Set up ocean background shader scroll
	if ocean_bg and ocean_bg.material is ShaderMaterial:
		ocean_bg.material.set_shader_parameter("scroll_offset", Vector2.ZERO)
	
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)

func _process(delta: float) -> void:
	game_time += delta
	GameManager.game_time = game_time
	
	# Camera follow player with shake
	if camera and player:
		var target := player.position
		if screen_shake_amount > 0.5:
			target += Vector2(
				randf_range(-screen_shake_amount, screen_shake_amount),
				randf_range(-screen_shake_amount, screen_shake_amount))
			screen_shake_amount *= 0.85
		else:
			screen_shake_amount = 0
		camera.position = target
	
	# Scroll ocean shader
	if ocean_bg and ocean_bg.material is ShaderMaterial:
		ocean_bg.material.set_shader_parameter("scroll_offset", player.position)
	
	# Wave progression
	wave_timer += delta
	if wave_timer >= WAVE_DURATION:
		wave_timer = 0.0
		wave += 1
		GameManager.current_wave = wave
		spawn_rate = maxf(MIN_SPAWN_RATE, INITIAL_SPAWN_RATE * pow(0.85, wave))
		boss_spawned_this_wave = false
		GameManager.wave_changed.emit(wave)
		
		# Random events
		if randf() < STORM_CHANCE_PER_WAVE and wave >= 3:
			_start_storm()
		if randf() < WHIRLPOOL_CHANCE_PER_WAVE and wave >= 2:
			_spawn_whirlpool()
	
	# Boss spawn
	if wave > 0 and wave % BOSS_WAVE_INTERVAL == 0 and not boss_spawned_this_wave:
		_spawn_boss()
		boss_spawned_this_wave = true
	
	# Enemy spawning
	spawn_timer += delta
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		var batch := 1 + wave / 2
		for i in range(batch):
			_spawn_enemy()
	
	# Floating item spawning
	float_item_timer += delta
	if float_item_timer >= FLOATING_ITEM_INTERVAL:
		float_item_timer = 0.0
		_spawn_floating_item()
	
	# Chest spawning
	chest_timer += delta
	if chest_timer >= CHEST_SPAWN_INTERVAL:
		chest_timer = 0.0
		_spawn_chest()
	
	# Storm timer
	if is_storm:
		storm_timer -= delta
		if storm_timer <= 0:
			is_storm = false
	
	# Achievement check
	AchievementManager.check(
		player.kills, player.level, player.dashes_used,
		wave, game_time, GameManager.combo_count,
		GameManager.bosses_killed, 0, 0)

func shake_screen(intensity: float) -> void:
	screen_shake_amount = maxf(screen_shake_amount, intensity)

func _spawn_enemy() -> void:
	var angle := randf() * TAU
	var d := randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
	var pos := player.position + Vector2(cos(angle), sin(angle)) * d
	pos = pos.clamp(Vector2.ZERO, GameManager.WORLD_SIZE)
	# Enemy scene would be instantiated here
	# For now, emit signal for enemy spawner to handle

func _spawn_boss() -> void:
	var angle := randf() * TAU
	var pos := player.position + Vector2(cos(angle), sin(angle)) * 500.0
	pos = pos.clamp(Vector2(50, 50), GameManager.WORLD_SIZE - Vector2(50, 50))
	AudioManager.play("boss_roar")
	shake_screen(10.0)

func _spawn_chest() -> void:
	var angle := randf() * TAU
	var d := randf_range(100.0, 300.0)
	var pos := player.position + Vector2(cos(angle), sin(angle)) * d
	pos = pos.clamp(Vector2(50, 50), GameManager.WORLD_SIZE - Vector2(50, 50))

func _spawn_floating_item() -> void:
	var angle := randf() * TAU
	var d := randf_range(200.0, 500.0)
	var pos := player.position + Vector2(cos(angle), sin(angle)) * d
	pos = pos.clamp(Vector2(50, 50), GameManager.WORLD_SIZE - Vector2(50, 50))

func _spawn_whirlpool() -> void:
	var angle := randf() * TAU
	var d := randf_range(200.0, 400.0)
	var pos := player.position + Vector2(cos(angle), sin(angle)) * d
	AudioManager.play("whirlpool")

func _start_storm() -> void:
	is_storm = true
	storm_timer = 15.0  # storm lasts 15 seconds
	shake_screen(3.0)

func _on_player_died() -> void:
	# Save run data
	GameManager.save_data["gold"] += player.gold
	GameManager.save_data["total_kills"] += player.kills
	GameManager.save_data["total_runs"] += 1
	GameManager.save_data["games_played"] += 1
	var mins := int(game_time) / 60
	var secs := int(game_time) % 60
	GameManager.add_high_score(player.kills, player.level, wave + 1, 
							   "%02d:%02d" % [mins, secs])
	GameManager.save_game()

func _on_player_leveled_up(_level: int) -> void:
	# Trigger power-up selection UI
	pass
