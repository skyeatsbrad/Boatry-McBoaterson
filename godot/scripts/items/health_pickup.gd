extends Node2D

# Health pickup - red cross that bobs on the water

@export var heal_amount := 20

var anim_timer := 0.0

func _ready() -> void:
	add_to_group("pickups")

func _process(delta: float) -> void:
	anim_timer += delta * 4.0
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node2D = players[0]
		if position.distance_to(player.position) < 25.0:
			if player.has_method("heal"):
				player.heal(heal_amount)
			queue_free()
	
	queue_redraw()

func _draw() -> void:
	var bob := sin(anim_timer) * 3.0
	draw_rect(Rect2(Vector2(-6, -2 + bob), Vector2(12, 4)), Color.RED)
	draw_rect(Rect2(Vector2(-2, -6 + bob), Vector2(4, 12)), Color.RED)
	draw_rect(Rect2(Vector2(-7, -7 + bob), Vector2(14, 14)), Color.WHITE, false, 1.0)
