extends Node2D

# GPU-free particle system using _draw() for all rendering.
# Uses a fixed pool to avoid allocations during gameplay.

const MAX_PARTICLES := 500
const VELOCITY_DAMPING := 0.96
const SCREEN_MARGIN := 100.0

var pool: Array[Dictionary] = []
var alive_count := 0
var _viewport_rect := Rect2()

func _ready() -> void:
	pool.resize(MAX_PARTICLES)
	for i in MAX_PARTICLES:
		pool[i] = {
			"alive": false,
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"color": Color.WHITE,
			"life": 0.0,
			"max_life": 0.0,
			"size": 3.0,
			"shrink": true,
			"glow": false,
		}
	z_index = 100

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var vp_size := get_viewport_rect().size / cam.zoom
		_viewport_rect = Rect2(cam.global_position - vp_size * 0.5, vp_size)
	else:
		_viewport_rect = get_viewport_rect()

	alive_count = 0
	for p in pool:
		if not p["alive"]:
			continue
		p["life"] -= delta
		if p["life"] <= 0.0:
			p["alive"] = false
			continue
		p["vel"] *= VELOCITY_DAMPING
		p["pos"] += p["vel"] * delta

		# Cull off-screen particles
		var expanded := _viewport_rect.grow(SCREEN_MARGIN)
		if not expanded.has_point(p["pos"]):
			p["alive"] = false
			continue

		alive_count += 1

	queue_redraw()

func _draw() -> void:
	for p in pool:
		if not p["alive"]:
			continue
		var t: float = p["life"] / p["max_life"]
		var alpha: float = clampf(t * 2.0, 0.0, 1.0)
		var sz: float = p["size"] * (t if p["shrink"] else 1.0)
		if sz < 0.5:
			continue

		var draw_pos: Vector2 = p["pos"] - global_position
		var col: Color = p["color"]
		col.a = alpha

		if p["glow"]:
			var glow_col := col
			glow_col.a *= 0.3
			draw_circle(draw_pos, sz * 2.0, glow_col)

		draw_circle(draw_pos, sz, col)


# --- Core emit ---

func emit(pos: Vector2, color: Color, count: int, speed: float, life: float, size: float = 3.0, glow: bool = false) -> void:
	for i in count:
		var p := _get_particle()
		if p == null:
			return
		var angle := randf() * TAU
		p["alive"] = true
		p["pos"] = pos
		p["vel"] = Vector2(cos(angle), sin(angle)) * speed * randf_range(0.5, 1.0)
		p["color"] = color
		p["life"] = life * randf_range(0.7, 1.0)
		p["max_life"] = p["life"]
		p["size"] = size * randf_range(0.7, 1.3)
		p["shrink"] = true
		p["glow"] = glow

func emit_ring(pos: Vector2, color: Color, radius: float, count: int) -> void:
	for i in count:
		var p := _get_particle()
		if p == null:
			return
		var angle := (float(i) / float(count)) * TAU
		var dir := Vector2(cos(angle), sin(angle))
		p["alive"] = true
		p["pos"] = pos + dir * radius * 0.3
		p["vel"] = dir * radius * 2.0
		p["color"] = color
		p["life"] = 0.5
		p["max_life"] = 0.5
		p["size"] = 3.0
		p["shrink"] = true
		p["glow"] = false

func emit_trail(pos: Vector2, color: Color, direction: Vector2) -> void:
	for i in 3:
		var p := _get_particle()
		if p == null:
			return
		var spread := direction.rotated(randf_range(-0.4, 0.4))
		p["alive"] = true
		p["pos"] = pos
		p["vel"] = spread * randf_range(30.0, 80.0)
		p["color"] = color
		p["life"] = randf_range(0.2, 0.4)
		p["max_life"] = p["life"]
		p["size"] = randf_range(1.5, 3.0)
		p["shrink"] = true
		p["glow"] = false


# --- Presets ---

func emit_kill(pos: Vector2, color: Color) -> void:
	emit(pos, color, 12, 120.0, 0.6, 4.0)

func emit_hit(pos: Vector2) -> void:
	emit(pos, Color(1.0, 0.95, 0.3), 4, 80.0, 0.3, 2.5)

func emit_gem(pos: Vector2) -> void:
	emit(pos, Color(0.2, 1.0, 0.4), 4, 60.0, 0.4, 2.0, true)

func emit_dash(pos: Vector2, color: Color) -> void:
	emit(pos, color, 8, 100.0, 0.4, 3.5)

func emit_explosion(pos: Vector2) -> void:
	emit(pos, Color(1.0, 0.6, 0.1), 14, 160.0, 0.7, 5.0, true)
	emit(pos, Color.WHITE, 6, 100.0, 0.4, 3.0)

func emit_boss_death(pos: Vector2) -> void:
	emit(pos, Color(1.0, 0.85, 0.2), 30, 200.0, 1.0, 6.0, true)
	emit_ring(pos, Color(1.0, 0.9, 0.5), 60.0, 16)

func emit_water_splash(pos: Vector2) -> void:
	emit(pos, Color(0.6, 0.85, 1.0), 5, 50.0, 0.35, 2.0)
	emit(pos, Color.WHITE, 3, 40.0, 0.25, 1.5)

func emit_combo_burst(pos: Vector2, tier_color: Color) -> void:
	emit(pos, tier_color, 10, 140.0, 0.5, 4.0, true)
	emit_ring(pos, tier_color, 40.0, 8)


# --- Pool management ---

func _get_particle() -> Variant:
	for p in pool:
		if not p["alive"]:
			return p
	# Pool full — steal the oldest (lowest life) particle
	var oldest: Dictionary = pool[0]
	for p in pool:
		if p["life"] < oldest["life"]:
			oldest = p
	return oldest

func get_alive_count() -> int:
	return alive_count
