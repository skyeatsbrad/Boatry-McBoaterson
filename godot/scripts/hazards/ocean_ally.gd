extends Node2D

# Whale/dolphin ally that swims by and attacks enemies

enum AllyType { WHALE, DOLPHIN }

@export var ally_type := AllyType.DOLPHIN
@export var damage := 30
@export var swim_speed := 250.0

var direction := Vector2.RIGHT
var lifetime := 5.0
var anim_timer := 0.0

func _ready() -> void:
	# Pick random direction across screen
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	add_to_group("allies")

func _process(delta: float) -> void:
	lifetime -= delta
	anim_timer += delta * 4.0
	position += direction * swim_speed * delta
	
	if lifetime <= 0:
		queue_free()
		return
	
	# Damage enemies we pass through
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get("active"):
			if position.distance_to(enemy.position) < 30.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
	
	queue_redraw()

func _draw() -> void:
	var bob := sin(anim_timer) * 3.0
	match ally_type:
		AllyType.DOLPHIN:
			# Sleek dolphin shape
			var c := Color(0.4, 0.5, 0.7)
			draw_circle(Vector2(0, bob), 12.0, c)
			draw_circle(Vector2(12, bob - 2), 8.0, c)
			# Tail
			draw_line(Vector2(-12, bob), Vector2(-20, bob - 6), c, 3.0)
			draw_line(Vector2(-12, bob), Vector2(-20, bob + 6), c, 3.0)
			# Fin
			draw_line(Vector2(0, bob - 12), Vector2(-5, bob - 20), c.darkened(0.2), 2.5)
			# Eye
			draw_circle(Vector2(14, bob - 4), 2.0, Color.WHITE)
			draw_circle(Vector2(14, bob - 4), 1.0, Color.BLACK)
		
		AllyType.WHALE:
			# Large whale
			var c := Color(0.3, 0.4, 0.6)
			draw_circle(Vector2(0, bob), 20.0, c)
			draw_circle(Vector2(18, bob), 14.0, c)
			# Tail
			draw_line(Vector2(-20, bob), Vector2(-30, bob - 10), c, 4.0)
			draw_line(Vector2(-20, bob), Vector2(-30, bob + 10), c, 4.0)
			# Eye
			draw_circle(Vector2(24, bob - 5), 3.0, Color.WHITE)
			draw_circle(Vector2(24, bob - 5), 1.5, Color.BLACK)
			# Water spout
			if int(anim_timer) % 3 == 0:
				draw_line(Vector2(5, bob - 20), Vector2(3, bob - 35), 
						  Color(0.7, 0.85, 1.0, 0.6), 2.0)
				draw_line(Vector2(5, bob - 20), Vector2(8, bob - 33), 
						  Color(0.7, 0.85, 1.0, 0.5), 1.5)
