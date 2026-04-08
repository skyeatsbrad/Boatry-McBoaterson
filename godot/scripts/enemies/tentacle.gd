extends Area2D

# Tentacle Slam hitbox - spawned by Kraken boss
# Shows warning circle for 0.5s, then slams down dealing damage for 0.5s

const WARNING_DURATION := 0.5
const IMPACT_DURATION := 0.5
const TOTAL_DURATION := 1.0
const RADIUS := 30.0

var damage := 25
var timer := 0.0
var phase := "warning"  # "warning" -> "impact" -> done
var has_hit_player := false

func _ready() -> void:
	# Set up collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	shape.disabled = true
	add_child(shape)

	# Monitoring for player contact
	collision_layer = 0
	collision_mask = 1  # Player layer
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	timer += delta

	if phase == "warning" and timer >= WARNING_DURATION:
		phase = "impact"
		# Enable collision during impact
		var shape_node := get_child(0) as CollisionShape2D
		if shape_node:
			shape_node.disabled = false
		AudioManager.play("hit")

	if timer >= TOTAL_DURATION:
		queue_free()
		return

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if phase != "impact" or has_hit_player:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		has_hit_player = true

func _draw() -> void:
	if phase == "warning":
		_draw_warning()
	elif phase == "impact":
		_draw_impact()

func _draw_warning() -> void:
	var progress := timer / WARNING_DURATION
	var pulse := sin(progress * TAU * 3.0) * 0.15 + 0.85

	# Pulsing red warning circle
	var alpha := 0.2 + progress * 0.3
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(1.0, 0.1, 0.1, alpha))
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(1.0, 0.2, 0.2, alpha + 0.2), false, 2.0)

	# Crosshair lines
	var line_alpha := alpha + 0.1
	var r := RADIUS * 0.8 * pulse
	draw_line(Vector2(-r, 0), Vector2(r, 0), Color(1, 0.2, 0.2, line_alpha), 1.5)
	draw_line(Vector2(0, -r), Vector2(0, r), Color(1, 0.2, 0.2, line_alpha), 1.5)

	# Growing inner ring
	draw_circle(Vector2.ZERO, RADIUS * progress * 0.5, Color(1.0, 0.3, 0.1, alpha * 0.5))

func _draw_impact() -> void:
	var impact_time := timer - WARNING_DURATION
	var progress := impact_time / IMPACT_DURATION
	var fade := 1.0 - progress

	# Solid slam circle
	draw_circle(Vector2.ZERO, RADIUS, Color(0.6, 0.1, 0.15, 0.7 * fade))

	# Impact ring expanding outward
	var ring_r := RADIUS + progress * 15.0
	draw_circle(Vector2.ZERO, ring_r, Color(1.0, 0.4, 0.2, 0.5 * fade), false, 3.0)

	# Inner damage zone
	var inner_r := RADIUS * (1.0 - progress * 0.3)
	draw_circle(Vector2.ZERO, inner_r, Color(0.8, 0.15, 0.1, 0.5 * fade))

	# Tentacle mark (darker center)
	draw_circle(Vector2.ZERO, 8.0, Color(0.3, 0.05, 0.08, 0.8 * fade))

	# Crack lines radiating from center
	for i in range(6):
		var angle := float(i) / 6.0 * TAU
		var end := Vector2(cos(angle), sin(angle)) * RADIUS * 0.9 * fade
		draw_line(Vector2.ZERO, end, Color(0.9, 0.3, 0.1, 0.4 * fade), 1.5)
