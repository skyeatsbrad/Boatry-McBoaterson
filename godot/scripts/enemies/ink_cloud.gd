extends Area2D

# Ink Cloud debuff zone - spawned by Kraken boss
# Dark cloud that slows player movement by 50% for 5 seconds

const LIFETIME := 5.0
const RADIUS := 60.0
const SLOW_FACTOR := 0.5
const FADE_START := 3.5  # Start fading at this time

var timer := 0.0
var swirl_angle := 0.0
var players_inside: Array[Node2D] = []
var original_speeds: Dictionary = {}

func _ready() -> void:
	# Set up collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	collision_layer = 0
	collision_mask = 1  # Player layer
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	timer += delta
	swirl_angle += delta * 2.0

	if timer >= LIFETIME:
		_restore_all_speeds()
		queue_free()
		return

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body not in players_inside:
		players_inside.append(body)
		if "speed" in body:
			original_speeds[body] = body.speed
			body.speed *= SLOW_FACTOR

func _on_body_exited(body: Node2D) -> void:
	if body in players_inside:
		players_inside.erase(body)
		_restore_speed(body)

func _restore_speed(body: Node2D) -> void:
	if body in original_speeds:
		if "speed" in body:
			body.speed = original_speeds[body]
		original_speeds.erase(body)

func _restore_all_speeds() -> void:
	for body in players_inside:
		_restore_speed(body)
	players_inside.clear()

func _draw() -> void:
	var alpha_mult := 1.0
	if timer > FADE_START:
		alpha_mult = 1.0 - (timer - FADE_START) / (LIFETIME - FADE_START)

	# Outer dark cloud
	draw_circle(Vector2.ZERO, RADIUS, Color(0.08, 0.02, 0.12, 0.45 * alpha_mult))

	# Layered cloud blobs for depth
	for i in range(5):
		var a := float(i) / 5.0 * TAU + swirl_angle * (0.3 + i * 0.1)
		var r := RADIUS * 0.4
		var blob_pos := Vector2(cos(a), sin(a)) * r
		var blob_r := RADIUS * 0.45 + sin(swirl_angle + i) * 5.0
		draw_circle(blob_pos, blob_r, Color(0.05, 0.01, 0.1, 0.3 * alpha_mult))

	# Swirling tendrils
	for i in range(4):
		var base_angle := float(i) / 4.0 * TAU + swirl_angle
		var pts: PackedVector2Array = []
		for seg in range(8):
			var t := float(seg) / 7.0
			var spiral_r := t * RADIUS * 0.85
			var spiral_a := base_angle + t * 2.5 + sin(timer * 1.5 + i) * 0.3
			pts.append(Vector2(cos(spiral_a), sin(spiral_a)) * spiral_r)
		for seg in range(pts.size() - 1):
			var t := float(seg) / (pts.size() - 1)
			var thickness := lerpf(3.0, 1.0, t)
			draw_line(pts[seg], pts[seg + 1],
					  Color(0.15, 0.0, 0.2, (0.4 - t * 0.2) * alpha_mult), thickness)

	# Inner dark core
	var core_pulse := sin(timer * 3.0) * 3.0
	draw_circle(Vector2.ZERO, 15.0 + core_pulse, Color(0.02, 0.0, 0.05, 0.6 * alpha_mult))

	# Purple particle sparkles in the cloud
	for i in range(8):
		var seed_val := float(i) * 1.618
		var pa := fmod(seed_val * TAU + timer * (0.5 + i * 0.15), TAU)
		var pr := fmod(seed_val * 30.0 + timer * 10.0, RADIUS * 0.8)
		var sparkle_pos := Vector2(cos(pa), sin(pa)) * pr
		var sparkle_alpha := (sin(timer * 4.0 + i * 1.3) + 1.0) * 0.25 * alpha_mult
		draw_circle(sparkle_pos, 1.5, Color(0.5, 0.1, 0.7, sparkle_alpha))

	# Edge glow ring
	draw_circle(Vector2.ZERO, RADIUS, Color(0.2, 0.05, 0.3, 0.2 * alpha_mult), false, 2.0)
