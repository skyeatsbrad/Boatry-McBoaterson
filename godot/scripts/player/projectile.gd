extends Area2D

## A simple projectile that moves in a straight line and damages the first enemy it hits.
## Rendered as a yellow circle with a white outline via _draw().

var direction := Vector2.RIGHT
var speed := 400.0
var damage := 20
var lifetime := 2.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		AudioManager.play("hit")
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color.YELLOW)
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 16, Color.WHITE, 1.5)
