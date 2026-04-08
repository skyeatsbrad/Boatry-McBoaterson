extends Node2D

# Treasure chest floating on the ocean, gives random rewards

var anim_timer := 0.0

func _ready() -> void:
	add_to_group("chests")

func _process(delta: float) -> void:
	anim_timer += delta * 3.0
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node2D = players[0]
		if position.distance_to(player.position) < 28.0:
			_open(player)
	
	queue_redraw()

func _open(player: Node2D) -> void:
	AudioManager.play("chest")
	var reward := randi() % 3
	match reward:
		0:  # Heal
			if player.has_method("heal"):
				player.heal(50)
		1:  # Gold
			var bonus := 20 + GameManager.current_wave * 5
			if "gold" in player:
				player.gold += bonus
		2:  # Bonus XP
			if player.has_method("gain_xp"):
				player.gain_xp(30)
	queue_free()

func _draw() -> void:
	var bob := sin(anim_timer * 0.7) * 2.0
	var glow := int(20 + 15 * sin(anim_timer))
	draw_circle(Vector2(0, bob), 20.0, Color(1.0, 0.8, 0.2, glow / 255.0))
	# Box
	draw_rect(Rect2(Vector2(-10, -6 + bob), Vector2(20, 14)), Color(0.55, 0.35, 0.17))
	# Lid
	draw_rect(Rect2(Vector2(-10, -10 + bob), Vector2(20, 6)), Color(0.7, 0.47, 0.24))
	# Lock
	draw_rect(Rect2(Vector2(-2, -4 + bob), Vector2(4, 4)), Color(1.0, 0.8, 0.2))
	# Outline
	draw_rect(Rect2(Vector2(-11, -11 + bob), Vector2(22, 20)), Color.WHITE, false, 1.0)
