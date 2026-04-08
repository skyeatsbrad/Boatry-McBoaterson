extends CharacterBody2D

# Kraken Boss - King of the Sea
# Massive tentacled boss with 3 attack patterns:
#   Tentacle Slam, Ink Cloud, Summon Piranhas

signal killed(enemy)
signal boss_died(pos: Vector2, gold: int)

const BODY_RADIUS := 45.0
const TENTACLE_COUNT := 8
const TENTACLE_LENGTH := 60.0
const TENTACLE_SEGMENTS := 6

@export var is_boss := true

# Stats (set on activate)
var max_hp := 300
var hp := 300
var speed := 40.0
var damage := 25
var xp_value := 100
var gold_value := 50
var active := false
var wave_level := 1

# Animation
var anim_timer := 0.0
var hit_flash_timer := 0.0
var eye_glow_timer := 0.0
var death_timer := -1.0
var crown_bob := 0.0

# Attack timers
var tentacle_slam_cd := 6.0
var tentacle_slam_timer := 3.0
var ink_cloud_cd := 10.0
var ink_cloud_timer := 7.0
var summon_cd := 15.0
var summon_timer := 12.0

# Attack state
var is_slamming := false
var slam_anim_timer := 0.0

# Tentacle procedural animation data
var tentacle_angles: Array[float] = []
var tentacle_phase: Array[float] = []

func _ready() -> void:
	_init_tentacles()

func _init_tentacles() -> void:
	tentacle_angles.clear()
	tentacle_phase.clear()
	for i in range(TENTACLE_COUNT):
		tentacle_angles.append(float(i) / TENTACLE_COUNT * TAU)
		tentacle_phase.append(randf() * TAU)

func activate(pos: Vector2, wave: int, _type: String = "") -> void:
	position = pos
	wave_level = wave
	max_hp = 300 + wave * 100
	hp = max_hp
	speed = 35.0 + wave * 2.0
	damage = 25 + wave * 5
	xp_value = 100 + wave * 20
	gold_value = 50 + wave * 10
	active = true
	visible = true
	death_timer = -1.0
	hit_flash_timer = 0.0
	anim_timer = 0.0
	tentacle_slam_timer = 3.0
	ink_cloud_timer = 7.0
	summon_timer = 12.0
	is_slamming = false
	_init_tentacles()

	# Collision shape
	var shape_node := get_node_or_null("CollisionShape2D")
	if not shape_node:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = BODY_RADIUS
		shape_node.shape = circle
		add_child(shape_node)

func deactivate() -> void:
	active = false
	visible = false
	position = Vector2(-9999, -9999)

func _physics_process(delta: float) -> void:
	if not active:
		return

	anim_timer += delta * 2.0
	eye_glow_timer += delta * 3.0
	crown_bob += delta * 2.0

	if hit_flash_timer > 0:
		hit_flash_timer -= delta

	# Death explosion sequence
	if death_timer >= 0:
		death_timer -= delta
		if death_timer <= 0:
			_do_death()
			return
		queue_redraw()
		return

	# Move toward player
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var target: Vector2 = players[0].position
		var dir := (target - position).normalized()
		velocity = dir * speed
		move_and_slide()

	# Attack timers
	tentacle_slam_timer -= delta
	ink_cloud_timer -= delta
	summon_timer -= delta

	if tentacle_slam_timer <= 0:
		_attack_tentacle_slam()
		tentacle_slam_timer = tentacle_slam_cd
	if ink_cloud_timer <= 0:
		_attack_ink_cloud()
		ink_cloud_timer = ink_cloud_cd
	if summon_timer <= 0:
		_attack_summon()
		summon_timer = summon_cd

	# Slam animation
	if is_slamming:
		slam_anim_timer -= delta
		if slam_anim_timer <= 0:
			is_slamming = false

	queue_redraw()

func take_damage(amount: int) -> void:
	if not active or death_timer >= 0:
		return
	hp -= amount
	hit_flash_timer = 0.15
	if hp <= 0:
		hp = 0
		# Start death sequence
		death_timer = 0.8
		AudioManager.play("explosion")
		_shake_screen(15.0)

func _do_death() -> void:
	killed.emit(self)
	boss_died.emit(position, gold_value)
	GameManager.bosses_killed += 1
	GameManager.add_combo()

	# Spawn gold drops
	for i in range(gold_value / 5):
		var gem_script = load("res://scripts/items/gem.gd")
		var gem := Node2D.new()
		gem.set_script(gem_script)
		var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
		gem.position = position + offset
		gem.set("value", xp_value / 5)
		if get_parent().get_parent().has_node("Pickups"):
			get_parent().get_parent().get_node("Pickups").add_child(gem)

	AudioManager.play("explosion")
	_shake_screen(20.0)
	deactivate()

func _shake_screen(intensity: float) -> void:
	var world := get_tree().current_scene
	if world and world.has_method("shake_screen"):
		world.shake_screen(intensity)

# === ATTACK PATTERNS ===

func _attack_tentacle_slam() -> void:
	is_slamming = true
	slam_anim_timer = 1.0
	AudioManager.play("splash")
	_shake_screen(5.0)

	var count := randi_range(4, 6)
	var tentacle_script = load("res://scripts/enemies/tentacle.gd")
	for i in range(count):
		var angle := float(i) / count * TAU + randf() * 0.3
		var dist := randf_range(80.0, 140.0)
		var slam_pos := position + Vector2(cos(angle), sin(angle)) * dist

		var tentacle := Area2D.new()
		tentacle.set_script(tentacle_script)
		tentacle.position = slam_pos
		tentacle.set("damage", damage)
		get_parent().add_child(tentacle)

func _attack_ink_cloud() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var target_pos: Vector2 = players[0].position

	var cloud_script = load("res://scripts/enemies/ink_cloud.gd")
	var cloud := Area2D.new()
	cloud.set_script(cloud_script)
	cloud.position = target_pos
	get_parent().add_child(cloud)
	AudioManager.play("splash")

func _attack_summon() -> void:
	AudioManager.play("boss_roar")
	_shake_screen(3.0)

	for i in range(3):
		var angle := float(i) / 3.0 * TAU + randf() * 0.5
		var dist := randf_range(100.0, 180.0)
		var spawn_pos := position + Vector2(cos(angle), sin(angle)) * dist

		# Use enemy spawner if available, otherwise spawn directly
		var spawner := get_parent().get_node_or_null("EnemySpawner")
		if spawner and spawner.has_method("spawn"):
			spawner.spawn(spawn_pos, wave_level, "piranha")
		else:
			# Fallback: spawn via base_enemy script
			var enemy := CharacterBody2D.new()
			var script = load("res://scripts/enemies/base_enemy.gd")
			enemy.set_script(script)
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 14.0
			shape.shape = circle
			enemy.add_child(shape)
			get_parent().add_child(enemy)
			if enemy.has_method("activate"):
				enemy.activate(spawn_pos, wave_level, "piranha")

# === DRAWING ===

func _draw() -> void:
	if not active:
		return

	var flash := hit_flash_timer > 0

	# Death explosion effect
	if death_timer >= 0:
		_draw_death_explosion()
		return

	# Tentacles (drawn behind body)
	_draw_tentacles(flash)

	# Main body
	_draw_body(flash)

	# Crown
	_draw_crown()

	# Eyes
	_draw_eyes(flash)

	# HP bar
	_draw_hp_bar()

func _draw_tentacles(flash: bool) -> void:
	var base_color := Color(0.55, 0.15, 0.35) if not flash else Color.WHITE
	var tip_color := Color(0.7, 0.2, 0.5) if not flash else Color.WHITE

	for i in range(TENTACLE_COUNT):
		var pts: PackedVector2Array = []
		var base_angle: float = tentacle_angles[i] + sin(anim_timer * 0.5) * 0.1
		var phase: float = tentacle_phase[i]

		# Slam animation: tentacles thrash more during slam
		var thrash := 1.0
		if is_slamming:
			thrash = 2.5

		for seg in range(TENTACLE_SEGMENTS + 1):
			var t := float(seg) / TENTACLE_SEGMENTS
			var seg_len := BODY_RADIUS + t * TENTACLE_LENGTH
			# Sine wave along tentacle for organic motion
			var wave_offset := sin(anim_timer * 1.5 + phase + t * 4.0) * 12.0 * t * thrash
			var perp_angle := base_angle + PI * 0.5
			var pt := Vector2(cos(base_angle), sin(base_angle)) * seg_len
			pt += Vector2(cos(perp_angle), sin(perp_angle)) * wave_offset
			pts.append(pt)

		# Draw tentacle segments with decreasing thickness
		for seg in range(pts.size() - 1):
			var t := float(seg) / (pts.size() - 1)
			var thickness := lerpf(8.0, 2.0, t)
			var c: Color = base_color.lerp(tip_color, t)
			draw_line(pts[seg], pts[seg + 1], c, thickness)

		# Suction cups
		for seg in range(1, pts.size() - 1, 2):
			var t := float(seg) / (pts.size() - 1)
			var cup_r := lerpf(3.0, 1.5, t)
			draw_circle(pts[seg], cup_r, Color(0.75, 0.3, 0.55, 0.6))

func _draw_body(flash: bool) -> void:
	var body_color := Color(0.5, 0.1, 0.3) if not flash else Color.WHITE
	var outline_color := Color(0.35, 0.05, 0.2) if not flash else Color(0.9, 0.9, 0.9)

	# Outer glow
	draw_circle(Vector2.ZERO, BODY_RADIUS + 8, Color(0.6, 0.1, 0.4, 0.15))
	draw_circle(Vector2.ZERO, BODY_RADIUS + 4, Color(0.6, 0.1, 0.4, 0.25))

	# Main body
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_circle(Vector2.ZERO, BODY_RADIUS, outline_color, false, 3.0)

	# Body texture: darker patches
	for i in range(5):
		var a := float(i) / 5.0 * TAU + anim_timer * 0.1
		var r := BODY_RADIUS * 0.5
		var patch_pos := Vector2(cos(a), sin(a)) * r
		draw_circle(patch_pos, 8.0, Color(0.4, 0.08, 0.22, 0.4))

func _draw_crown() -> void:
	var bob := sin(crown_bob) * 2.0
	var crown_y := -BODY_RADIUS - 5 + bob
	var crown_color := Color(1.0, 0.84, 0.0)
	var jewel_color := Color(0.9, 0.1, 0.1)

	# Crown base
	var crown_pts: PackedVector2Array = [
		Vector2(-18, crown_y),
		Vector2(-18, crown_y - 12),
		Vector2(-12, crown_y - 6),
		Vector2(-6, crown_y - 18),
		Vector2(0, crown_y - 8),
		Vector2(6, crown_y - 18),
		Vector2(12, crown_y - 6),
		Vector2(18, crown_y - 12),
		Vector2(18, crown_y),
	]
	draw_colored_polygon(crown_pts, crown_color)
	draw_polyline(crown_pts, crown_color.darkened(0.3), 2.0)

	# Jewels on crown tips
	draw_circle(Vector2(-6, crown_y - 16), 3.0, jewel_color)
	draw_circle(Vector2(6, crown_y - 16), 3.0, jewel_color)
	draw_circle(Vector2(0, crown_y - 6), 2.5, Color(0.1, 0.4, 0.9))

func _draw_eyes(flash: bool) -> void:
	if flash:
		draw_circle(Vector2(-14, -8), 8.0, Color.WHITE)
		draw_circle(Vector2(14, -8), 8.0, Color.WHITE)
		return

	var glow := (sin(eye_glow_timer) + 1.0) * 0.5
	var eye_color := Color(1.0, 0.3, 0.1).lerp(Color(1.0, 0.9, 0.2), glow)

	# Eye sockets
	draw_circle(Vector2(-14, -8), 10.0, Color(0.2, 0.02, 0.1))
	draw_circle(Vector2(14, -8), 10.0, Color(0.2, 0.02, 0.1))

	# Glowing irises
	draw_circle(Vector2(-14, -8), 7.0, eye_color)
	draw_circle(Vector2(14, -8), 7.0, eye_color)

	# Glow effect
	draw_circle(Vector2(-14, -8), 9.0, Color(eye_color.r, eye_color.g, eye_color.b, 0.2 + glow * 0.15))
	draw_circle(Vector2(14, -8), 9.0, Color(eye_color.r, eye_color.g, eye_color.b, 0.2 + glow * 0.15))

	# Pupils
	draw_circle(Vector2(-14, -8), 3.0, Color.BLACK)
	draw_circle(Vector2(14, -8), 3.0, Color.BLACK)

	# Eye shine
	draw_circle(Vector2(-12, -10), 2.0, Color(1, 1, 1, 0.7))
	draw_circle(Vector2(16, -10), 2.0, Color(1, 1, 1, 0.7))

func _draw_hp_bar() -> void:
	var bar_w := 80.0
	var bar_h := 6.0
	var bar_y := -BODY_RADIUS - 30
	var bg_rect := Rect2(Vector2(-bar_w / 2, bar_y), Vector2(bar_w, bar_h))
	var fill_w := bar_w * float(hp) / max_hp
	var fill_rect := Rect2(Vector2(-bar_w / 2, bar_y), Vector2(fill_w, bar_h))

	# Background
	draw_rect(bg_rect, Color(0.15, 0.15, 0.15))
	# Fill with color gradient based on HP
	var hp_ratio := float(hp) / max_hp
	var bar_color := Color.RED if hp_ratio < 0.3 else (Color.ORANGE if hp_ratio < 0.6 else Color(0.8, 0.1, 0.3))
	draw_rect(fill_rect, bar_color)
	# Border
	draw_rect(bg_rect, Color.WHITE, false, 1.5)

	# "KRAKEN" label
	draw_string(ThemeDB.fallback_font, Vector2(-bar_w / 2, bar_y - 4), "KRAKEN",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_death_explosion() -> void:
	var progress := 1.0 - death_timer / 0.8
	# Multiple expanding explosion rings
	for i in range(5):
		var ring_progress := clampf(progress - i * 0.1, 0.0, 1.0)
		var r := ring_progress * 120.0
		var alpha := 1.0 - ring_progress
		var c := Color(1.0, 0.5 - i * 0.08, 0.1, alpha * 0.8)
		draw_circle(Vector2.ZERO, r, c)
		draw_circle(Vector2.ZERO, r, Color(1, 1, 0.5, alpha * 0.4), false, 3.0)

	# Flash
	if progress < 0.3:
		draw_circle(Vector2.ZERO, BODY_RADIUS * 2, Color(1, 1, 1, 1.0 - progress / 0.3))

	# Body fading out
	var fade := 1.0 - progress
	draw_circle(Vector2.ZERO, BODY_RADIUS * fade, Color(0.5, 0.1, 0.3, fade))
