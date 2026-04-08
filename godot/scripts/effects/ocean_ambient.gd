extends Node2D

# Ambient ocean effects — foam, seagulls, distant ships, bubble trails.
# All drawn with _draw(), low performance impact.

const MAX_OBJECTS := 20
const FOAM_COUNT := 10
const SEAGULL_COUNT := 3
const SHIP_COUNT := 2
const BUBBLE_COUNT := 5

const SPAWN_RADIUS := 600.0
const DESPAWN_RADIUS := 800.0

var foam_patches: Array[Dictionary] = []
var seagulls: Array[Dictionary] = []
var ships: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var _cam_pos := Vector2.ZERO

func _ready() -> void:
	z_index = -1
	_spawn_initial()

func _spawn_initial() -> void:
	for i in FOAM_COUNT:
		foam_patches.append(_make_foam(true))
	for i in SEAGULL_COUNT:
		seagulls.append(_make_seagull(true))
	for i in SHIP_COUNT:
		ships.append(_make_ship(true))


# --- Factories ---

func _make_foam(random_pos: bool) -> Dictionary:
	var offset := Vector2(randf_range(-SPAWN_RADIUS, SPAWN_RADIUS), randf_range(-SPAWN_RADIUS, SPAWN_RADIUS))
	return {
		"pos": (_cam_pos + offset) if random_pos else _random_edge_pos(),
		"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0)),
		"radius": randf_range(6.0, 18.0),
		"alpha": randf_range(0.06, 0.15),
		"life": randf_range(3.0, 8.0),
		"max_life": 8.0,
	}

func _make_seagull(random_pos: bool) -> Dictionary:
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)).normalized()
	var offset := Vector2(randf_range(-SPAWN_RADIUS, SPAWN_RADIUS), randf_range(-SPAWN_RADIUS * 0.3, -SPAWN_RADIUS * 0.6))
	return {
		"pos": (_cam_pos + offset) if random_pos else _random_edge_pos(),
		"vel": dir * randf_range(40.0, 70.0),
		"wing_phase": randf() * TAU,
		"size": randf_range(8.0, 14.0),
	}

func _make_ship(random_pos: bool) -> Dictionary:
	var side := -1.0 if randf() < 0.5 else 1.0
	var offset := Vector2(side * SPAWN_RADIUS, randf_range(-SPAWN_RADIUS * 0.8, -SPAWN_RADIUS * 0.4))
	return {
		"pos": (_cam_pos + offset) if random_pos else (_cam_pos + Vector2(side * SPAWN_RADIUS, randf_range(-300.0, -150.0))),
		"vel": Vector2(-side * randf_range(10.0, 20.0), 0.0),
		"size": randf_range(12.0, 20.0),
		"alpha": randf_range(0.08, 0.15),
	}


func _random_edge_pos() -> Vector2:
	var angle := randf() * TAU
	return _cam_pos + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS


# --- Bubble trail behind player ---

func emit_bubble(pos: Vector2) -> void:
	if bubbles.size() >= BUBBLE_COUNT:
		bubbles.pop_front()
	bubbles.append({
		"pos": pos + Vector2(randf_range(-6.0, 6.0), randf_range(4.0, 10.0)),
		"vel": Vector2(randf_range(-5.0, 5.0), randf_range(-15.0, -30.0)),
		"life": randf_range(0.4, 0.8),
		"max_life": 0.8,
		"radius": randf_range(1.5, 3.5),
	})


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		_cam_pos = cam.global_position

	# Update foam
	var i := foam_patches.size() - 1
	while i >= 0:
		var f := foam_patches[i]
		f["pos"] += f["vel"] * delta
		f["life"] -= delta
		if f["life"] <= 0.0 or f["pos"].distance_to(_cam_pos) > DESPAWN_RADIUS:
			foam_patches[i] = _make_foam(false)
		i -= 1

	# Update seagulls
	i = seagulls.size() - 1
	while i >= 0:
		var s := seagulls[i]
		s["pos"] += s["vel"] * delta
		s["wing_phase"] += delta * 4.0
		if s["pos"].distance_to(_cam_pos) > DESPAWN_RADIUS:
			seagulls[i] = _make_seagull(false)
		i -= 1

	# Update ships
	i = ships.size() - 1
	while i >= 0:
		var sh := ships[i]
		sh["pos"] += sh["vel"] * delta
		if sh["pos"].distance_to(_cam_pos) > DESPAWN_RADIUS:
			ships[i] = _make_ship(false)
		i -= 1

	# Update bubbles
	i = bubbles.size() - 1
	while i >= 0:
		var b := bubbles[i]
		b["pos"] += b["vel"] * delta
		b["life"] -= delta
		if b["life"] <= 0.0:
			bubbles.remove_at(i)
		i -= 1

	queue_redraw()


func _draw() -> void:
	var offset := -global_position

	# Foam patches
	for f in foam_patches:
		var t: float = f["life"] / f["max_life"]
		var col := Color(1.0, 1.0, 1.0, f["alpha"] * clampf(t * 2.0, 0.0, 1.0))
		draw_circle(f["pos"] + offset, f["radius"], col)

	# Distant ships (simple silhouette)
	for sh in ships:
		var p: Vector2 = sh["pos"] + offset
		var sz: float = sh["size"]
		var col := Color(0.15, 0.2, 0.25, sh["alpha"])
		# Hull
		var hull := PackedVector2Array([
			p + Vector2(-sz, 0),
			p + Vector2(-sz * 0.7, sz * 0.3),
			p + Vector2(sz * 0.7, sz * 0.3),
			p + Vector2(sz, 0),
		])
		draw_colored_polygon(hull, col)
		# Mast
		draw_line(p + Vector2(0, 0), p + Vector2(0, -sz * 0.8), col, 1.0)

	# Seagulls (V shape)
	for s in seagulls:
		var p: Vector2 = s["pos"] + offset
		var sz: float = s["size"]
		var wing := sin(s["wing_phase"]) * sz * 0.3
		var col := Color(0.2, 0.2, 0.25, 0.35)
		draw_line(p + Vector2(-sz, wing), p, col, 1.5)
		draw_line(p, p + Vector2(sz, wing), col, 1.5)

	# Bubbles
	for b in bubbles:
		var t: float = b["life"] / b["max_life"]
		var col := Color(0.7, 0.9, 1.0, 0.4 * t)
		draw_circle(b["pos"] + offset, b["radius"] * t, col)
		# Highlight
		var hi := Color(1.0, 1.0, 1.0, 0.2 * t)
		draw_circle(b["pos"] + offset + Vector2(-0.5, -0.5), b["radius"] * t * 0.3, hi)
