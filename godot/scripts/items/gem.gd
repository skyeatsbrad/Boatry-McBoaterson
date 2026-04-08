extends Node2D

# XP Gem that attracts toward player when close

@export var value := 5
@export var attract_range := 100.0
@export var attract_speed := 300.0

var anim_timer := 0.0

func _ready() -> void:
	anim_timer = randf() * TAU
	add_to_group("gems")

func _process(delta: float) -> void:
	anim_timer += delta * 5.0
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node2D = players[0]
		var d := position.distance_to(player.position)
		if d < attract_range:
			var dir := (player.position - position).normalized()
			var spd := attract_speed * (1.0 - d / attract_range) + 60.0
			position += dir * spd * delta
		
		# Collect
		if d < 20.0:
			if player.has_method("gain_xp"):
				player.gain_xp(value)
			AudioManager.play("gem")
			queue_free()
	
	queue_redraw()

func _draw() -> void:
	var bob := sin(anim_timer) * 2.0
	var glow_surf_r := 10.0
	draw_circle(Vector2(0, bob), glow_surf_r, Color(0.2, 0.8, 0.2, 0.15))
	var pts: PackedVector2Array = [
		Vector2(0, bob - 6), Vector2(6, bob),
		Vector2(0, bob + 6), Vector2(-6, bob)]
	draw_colored_polygon(pts, Color(0.2, 0.78, 0.2))
	draw_polyline(pts, Color.WHITE, 1.0, true)
