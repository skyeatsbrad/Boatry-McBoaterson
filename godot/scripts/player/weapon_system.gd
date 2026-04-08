extends Node

## Auto-firing weapon system that attaches to the player CharacterBody2D.
## Reads weapon_type and projectile stats from the parent player node,
## finds the nearest enemy in the "enemies" group, and fires the appropriate weapon.

const Projectile := preload("res://scripts/player/projectile.gd")
const Boomerang := preload("res://scripts/player/boomerang.gd")
const Lightning := preload("res://scripts/player/lightning.gd")

const SPREAD_ARC := deg_to_rad(15.0)
const LIGHTNING_CHAIN_COUNT := 4
const LIGHTNING_CHAIN_RANGE := 200.0

var player: CharacterBody2D


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	assert(player != null, "WeaponSystem must be a child of the player CharacterBody2D")


func _physics_process(_delta: float) -> void:
	if player._cooldown_timer > 0:
		return

	match player.weapon_type:
		"cannon":
			_fire_cannon()
		"lightning":
			_fire_lightning()
		"boomerang":
			_fire_boomerang()
		"aoe_blast":
			_fire_aoe_blast()

	# Handle explosion ability (independent of weapon_type)
	if player.has_explosion and player.explosion_timer <= 0:
		_fire_explosion()


# ---------------------------------------------------------------------------
# Target helpers
# ---------------------------------------------------------------------------

func _get_enemies() -> Array[Node]:
	var enemies: Array[Node] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CharacterBody2D and e.has_method("take_damage") and e.get("active") != false:
			enemies.append(e)
	return enemies


func _find_nearest_enemy(from: Vector2, exclude: Array[Node] = []) -> Node:
	var best: Node = null
	var best_dist := INF
	for e in _get_enemies():
		if e in exclude:
			continue
		var d: float = from.distance_squared_to(e.position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _get_projectiles_parent() -> Node:
	# Prefer the dedicated Projectiles node in GameWorld; fall back to scene root
	var proj_node := player.get_parent().get_node_or_null("Projectiles")
	if proj_node:
		return proj_node
	return player.get_parent()


# ---------------------------------------------------------------------------
# Cannon
# ---------------------------------------------------------------------------

func _fire_cannon() -> void:
	var target := _find_nearest_enemy(player.position)
	if target == null:
		return

	var base_dir: Vector2 = (target.position - player.position).normalized()
	var parent_node := _get_projectiles_parent()

	for i in range(player.proj_count):
		var angle_offset := 0.0
		if player.proj_count > 1:
			angle_offset = lerp(-SPREAD_ARC, SPREAD_ARC, float(i) / (player.proj_count - 1))
		var dir := base_dir.rotated(angle_offset)
		_spawn_projectile(parent_node, player.position, dir)

	player._cooldown_timer = player.proj_cooldown
	AudioManager.play("shoot")


func _spawn_projectile(parent_node: Node, pos: Vector2, dir: Vector2) -> void:
	var proj := Area2D.new()
	proj.set_script(Projectile)
	proj.position = pos
	proj.direction = dir
	proj.speed = player.proj_speed
	proj.damage = player.proj_damage
	proj.collision_layer = 0
	proj.collision_mask = 2  # enemy layer

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	proj.add_child(shape)

	parent_node.add_child(proj)


# ---------------------------------------------------------------------------
# Lightning
# ---------------------------------------------------------------------------

func _fire_lightning() -> void:
	var first_target := _find_nearest_enemy(player.position)
	if first_target == null:
		return

	var chain_points: Array[Vector2] = [player.position]
	var hit_enemies: Array[Node] = []
	var current_target: Node = first_target

	for i in range(LIGHTNING_CHAIN_COUNT):
		if current_target == null:
			break
		chain_points.append(current_target.position)
		hit_enemies.append(current_target)
		current_target.take_damage(player.proj_damage)
		# Find next nearest enemy within chain range
		var next := _find_nearest_in_range(
			current_target.position, LIGHTNING_CHAIN_RANGE, hit_enemies)
		current_target = next

	# Spawn lightning visual
	var vfx := Node2D.new()
	vfx.set_script(Lightning)
	vfx.chain_points = chain_points
	_get_projectiles_parent().add_child(vfx)

	player._cooldown_timer = player.proj_cooldown
	AudioManager.play("lightning")


func _find_nearest_in_range(from: Vector2, max_range: float, exclude: Array[Node]) -> Node:
	var best: Node = null
	var best_dist := max_range * max_range
	for e in _get_enemies():
		if e in exclude:
			continue
		var d: float = from.distance_squared_to(e.position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


# ---------------------------------------------------------------------------
# Boomerang
# ---------------------------------------------------------------------------

func _fire_boomerang() -> void:
	var target := _find_nearest_enemy(player.position)
	if target == null:
		return

	var dir: Vector2 = (target.position - player.position).normalized()
	var parent_node := _get_projectiles_parent()

	for i in range(player.proj_count):
		var angle_offset := 0.0
		if player.proj_count > 1:
			angle_offset = lerp(-SPREAD_ARC, SPREAD_ARC, float(i) / (player.proj_count - 1))
		var boom := Area2D.new()
		boom.set_script(Boomerang)
		boom.position = player.position
		boom.direction = dir.rotated(angle_offset)
		boom.speed = player.proj_speed
		boom.damage = player.proj_damage
		boom.player_ref = player
		boom.collision_layer = 0
		boom.collision_mask = 2

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		boom.add_child(shape)

		parent_node.add_child(boom)

	player._cooldown_timer = player.proj_cooldown
	AudioManager.play("shoot")


# ---------------------------------------------------------------------------
# AoE Blast
# ---------------------------------------------------------------------------

func _fire_aoe_blast() -> void:
	if player._cooldown_timer > 0:
		return

	var hit_count := 0
	var radius_sq := player.explosion_radius * player.explosion_radius
	for e in _get_enemies():
		if player.position.distance_squared_to(e.position) <= radius_sq:
			e.take_damage(player.proj_damage)
			hit_count += 1

	if hit_count > 0:
		AudioManager.play("explosion")

	# Spawn a brief visual ring
	var vfx := Node2D.new()
	vfx.set_script(Lightning)  # reuse lightning for fade logic
	vfx.chain_points = []  # empty = AoE ring mode
	vfx.aoe_center = player.position
	vfx.aoe_radius = player.explosion_radius
	vfx.is_aoe_ring = true
	_get_projectiles_parent().add_child(vfx)

	player._cooldown_timer = player.proj_cooldown


# ---------------------------------------------------------------------------
# Explosion ability (separate from weapon)
# ---------------------------------------------------------------------------

func _fire_explosion() -> void:
	var radius_sq := player.explosion_radius * player.explosion_radius
	var hit_any := false
	for e in _get_enemies():
		if player.position.distance_squared_to(e.position) <= radius_sq:
			e.take_damage(player.explosion_damage)
			hit_any = true

	if hit_any:
		AudioManager.play("explosion")

	player.explosion_timer = player.explosion_cooldown
