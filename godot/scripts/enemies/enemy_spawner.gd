extends Node2D

# Enemy spawner with object pooling for performance
# Pre-allocates enemies and reuses them instead of instantiate/queue_free

const POOL_SIZE := 200

var pool: Array[CharacterBody2D] = []
var active_count := 0

@export var enemy_scene: PackedScene

func _ready() -> void:
	# Pre-allocate enemy pool
	for i in range(POOL_SIZE):
		var enemy: CharacterBody2D
		if enemy_scene:
			enemy = enemy_scene.instantiate()
		else:
			enemy = CharacterBody2D.new()
			var script = load("res://scripts/enemies/base_enemy.gd")
			enemy.set_script(script)
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 14.0
			shape.shape = circle
			enemy.add_child(shape)
		
		enemy.visible = false
		enemy.set("active", false)
		enemy.position = Vector2(-9999, -9999)
		add_child(enemy)
		pool.append(enemy)
		
		if enemy.has_signal("killed"):
			enemy.killed.connect(_on_enemy_killed)

func spawn(pos: Vector2, wave: int, fish_type: String = "") -> CharacterBody2D:
	# Find inactive enemy in pool
	for enemy in pool:
		if not enemy.get("active"):
			if enemy.has_method("activate"):
				enemy.activate(pos, wave, fish_type)
			active_count += 1
			return enemy
	
	# Pool exhausted - skip spawn (performance cap)
	return null

func get_active_enemies() -> Array:
	var result: Array = []
	for enemy in pool:
		if enemy.get("active"):
			result.append(enemy)
	return result

func get_nearest_to(pos: Vector2) -> CharacterBody2D:
	var nearest: CharacterBody2D = null
	var nearest_dist := INF
	for enemy in pool:
		if enemy.get("active"):
			var d := enemy.position.distance_squared_to(pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
	return nearest

func _on_enemy_killed(enemy: CharacterBody2D) -> void:
	active_count -= 1
	# Spawn gem at enemy position
	var gem_script = load("res://scripts/items/gem.gd")
	var gem := Node2D.new()
	gem.set_script(gem_script)
	gem.position = enemy.position
	if "xp_value" in enemy:
		gem.set("value", enemy.xp_value)
	get_parent().get_node("Pickups").add_child(gem)
	
	# Chance to drop health
	if "drop_chance" in enemy and randf() < enemy.drop_chance:
		var hp_script = load("res://scripts/items/health_pickup.gd")
		var hp_pickup := Node2D.new()
		hp_pickup.set_script(hp_script)
		hp_pickup.position = enemy.position
		get_parent().get_node("Pickups").add_child(hp_pickup)
	
	# Gold
	if "gold_value" in enemy:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and "gold" in players[0]:
			players[0].gold += enemy.gold_value
	
	# Kill count
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and "kills" in players[0]:
		players[0].kills += 1
	
	GameManager.add_combo()
