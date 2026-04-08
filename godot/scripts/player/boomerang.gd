extends Area2D

## A boomerang projectile with two phases:
##   "out"    – flies forward in a direction, tracking distance traveled.
##   "return" – homes back toward the player's current position.
## Damages enemies on contact; tracks already-hit enemies per phase to avoid double hits.
## Rendered as a rotating teal diamond via _draw().

const MAX_TRAVEL_DISTANCE := 250.0
const RETURN_PROXIMITY := 30.0

var direction := Vector2.RIGHT
var speed := 400.0
var damage := 20
var player_ref: CharacterBody2D = null

var phase := "out"
var distance_traveled := 0.0
var rotation_angle := 0.0
var hit_enemies: Dictionary = {}  # acts as a Set (enemy -> true)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	rotation_angle += delta * 12.0  # fast spin

	match phase:
		"out":
			var step := direction * speed * delta
			position += step
			distance_traveled += step.length()
			if distance_traveled >= MAX_TRAVEL_DISTANCE:
				_switch_to_return()
		"return":
			if player_ref and is_instance_valid(player_ref):
				var to_player := (player_ref.position - position).normalized()
				position += to_player * speed * delta
				if position.distance_to(player_ref.position) < RETURN_PROXIMITY:
					queue_free()
					return
			else:
				queue_free()
				return

	queue_redraw()


func _switch_to_return() -> void:
	phase = "return"
	hit_enemies.clear()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	if hit_enemies.has(body):
		return
	hit_enemies[body] = true
	body.take_damage(damage)
	AudioManager.play("hit")


func _draw() -> void:
	# Diamond shape rotated by rotation_angle
	var color := Color(0.0, 0.8, 0.7)  # teal
	var size := 10.0
	var pts: PackedVector2Array = []
	for i in range(4):
		var a: float = rotation_angle + float(i) * TAU / 4.0
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
