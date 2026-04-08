extends Area2D

# Whirlpool hazard - pulls player and enemies toward center

@export var pull_strength := 150.0
@export var radius := 120.0
@export var lifetime := 12.0

var timer := 0.0
var anim_timer := 0.0
var _bodies_in: Array = []

func _ready() -> void:
	timer = lifetime
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b): _bodies_in.append(b))
	body_exited.connect(func(b): _bodies_in.erase(b))

func _process(delta: float) -> void:
	timer -= delta
	anim_timer += delta * 2.0
	if timer <= 0:
		queue_free()
		return
	for body in _bodies_in:
		if is_instance_valid(body):
			var dir := (position - body.position).normalized()
			var dist := maxf(position.distance_to(body.position), 1.0)
			var strength := pull_strength * (1.0 - dist / radius)
			if body is CharacterBody2D:
				body.velocity += dir * strength * delta * 60.0
	queue_redraw()

func _draw() -> void:
	var alpha := clampf(timer / 2.0, 0.0, 1.0)
	for i in range(4):
		var r := radius * (0.3 + i * 0.2)
		var c := Color(0.2, 0.5, 0.8, alpha * 0.3 * (1.0 - float(i) / 4.0))
		draw_arc(Vector2.ZERO, r, anim_timer + i * 0.5,
				 anim_timer + i * 0.5 + TAU * 0.7, 24, c, 2.0 + i)
	draw_circle(Vector2.ZERO, radius * 0.15, Color(0.05, 0.1, 0.2, alpha * 0.8))
