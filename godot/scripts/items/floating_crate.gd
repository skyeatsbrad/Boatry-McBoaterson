extends StaticBody2D

# Destroyable floating crate that drops pickups when broken

signal destroyed(pos: Vector2)

@export var max_hp := 20
@export var drop_type := "random"

var hp := 20
var bob_timer := 0.0

func _ready() -> void:
	hp = max_hp
	bob_timer = randf() * TAU

func _process(delta: float) -> void:
	bob_timer += delta * 2.0
	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		destroyed.emit(global_position)
		_drop_loot()
		queue_free()

func _drop_loot() -> void:
	# Spawn pickup at position — handled by game_world listener
	pass

func _draw() -> void:
	var bob := sin(bob_timer) * 2.0
	var c := Color(0.55, 0.35, 0.15)
	# Crate body
	draw_rect(Rect2(Vector2(-8, -8 + bob), Vector2(16, 16)), c)
	draw_rect(Rect2(Vector2(-8, -8 + bob), Vector2(16, 16)), Color(0.35, 0.2, 0.08), false, 1.5)
	# Cross planks
	draw_line(Vector2(-8, bob), Vector2(8, bob), Color(0.35, 0.2, 0.08), 1.0)
	draw_line(Vector2(0, -8 + bob), Vector2(0, 8 + bob), Color(0.35, 0.2, 0.08), 1.0)
	# HP bar when damaged
	if hp < max_hp:
		var bw := 16.0
		draw_rect(Rect2(Vector2(-bw / 2, -14 + bob), Vector2(bw, 3)), Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(Vector2(-bw / 2, -14 + bob), Vector2(bw * float(hp) / max_hp, 3)), Color.ORANGE)
