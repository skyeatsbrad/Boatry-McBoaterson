extends Node

# Co-op manager — handles Player 2 spawning, shared XP, and game-over logic.
# Add as autoload or child of game_world.

signal coop_started
signal coop_player_died(player_index: int)
signal coop_game_over

const Player2Script := preload("res://scripts/player/player_2.gd")

var coop_enabled := false
var player_1: CharacterBody2D = null
var player_2: CharacterBody2D = null
var player_1_alive := true
var player_2_alive := true

# Shared XP pool
var shared_xp := 0
var shared_xp_to_next := 20
var shared_level := 1


func _ready() -> void:
	set_process(false)


func enable_coop() -> void:
	coop_enabled = true


func disable_coop() -> void:
	coop_enabled = false


func start_coop(game_world: Node2D) -> void:
	if not coop_enabled:
		return

	player_1 = game_world.get_node_or_null("Player")
	if player_1 == null:
		# Try finding by group
		var players := game_world.get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_1 = players[0]

	if player_1 == null:
		push_warning("CoopManager: No Player 1 found in scene")
		return

	# Ensure P1 is in the player group
	if not player_1.is_in_group("player"):
		player_1.add_to_group("player")

	# Spawn Player 2
	player_2 = CharacterBody2D.new()
	player_2.set_script(Player2Script)
	player_2.name = "Player2"

	# Collision setup matching Player 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	player_2.add_child(shape)
	player_2.collision_layer = 1  # player layer
	player_2.collision_mask = 2   # enemies layer

	# Attach weapon system (same as Player 1)
	var ws_script := load("res://scripts/player/weapon_system.gd")
	var weapon_sys := Node.new()
	weapon_sys.set_script(ws_script)
	weapon_sys.name = "WeaponSystem"
	player_2.add_child(weapon_sys)

	game_world.add_child(player_2)

	# Wire signals
	player_1_alive = true
	player_2_alive = true

	if player_1.has_signal("died"):
		player_1.died.connect(_on_player_1_died)
	if player_2.has_signal("died"):
		player_2.died.connect(_on_player_2_died)

	# Shared XP: intercept leveled_up so both level together
	if player_1.has_signal("leveled_up"):
		player_1.leveled_up.connect(_on_shared_level_up)
	if player_2.has_signal("leveled_up"):
		player_2.leveled_up.connect(_on_shared_level_up)

	set_process(true)
	coop_started.emit()


func _process(_delta: float) -> void:
	if not coop_enabled:
		return
	_sync_shared_xp()


func _sync_shared_xp() -> void:
	# Pool XP: whichever player gains XP, both benefit.
	# Keep levels in sync by tracking a shared pool.
	if player_1 and player_1_alive and player_2 and player_2_alive:
		var total_xp := player_1.xp + player_2.xp
		var avg_xp := total_xp / 2
		player_1.xp = avg_xp
		player_2.xp = avg_xp

		# Sync level (use higher)
		var max_level := maxi(player_1.level, player_2.level)
		player_1.level = max_level
		player_2.level = max_level
		player_1.xp_to_next = player_2.xp_to_next


func _on_player_1_died() -> void:
	player_1_alive = false
	coop_player_died.emit(1)
	_check_game_over()


func _on_player_2_died() -> void:
	player_2_alive = false
	coop_player_died.emit(2)
	if player_2:
		player_2.visible = false
		player_2.set_physics_process(false)
	_check_game_over()


func _check_game_over() -> void:
	if not player_1_alive and not player_2_alive:
		coop_game_over.emit()


func _on_shared_level_up(_level: int) -> void:
	# When one player levels up, sync the other
	if player_1 and player_1_alive and player_2 and player_2_alive:
		var max_level := maxi(player_1.level, player_2.level)
		player_1.level = max_level
		player_2.level = max_level


func get_alive_players() -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	if player_1 and player_1_alive:
		result.append(player_1)
	if player_2 and player_2_alive:
		result.append(player_2)
	return result


func get_combined_kills() -> int:
	var total := 0
	if player_1:
		total += player_1.kills
	if player_2:
		total += player_2.kills
	return total


func get_combined_gold() -> int:
	var total := 0
	if player_1:
		total += player_1.gold
	if player_2:
		total += player_2.gold
	return total


func is_any_player_alive() -> bool:
	return player_1_alive or player_2_alive


func cleanup() -> void:
	if player_2 and is_instance_valid(player_2):
		player_2.queue_free()
	player_2 = null
	player_1 = null
	player_1_alive = true
	player_2_alive = true
	set_process(false)
