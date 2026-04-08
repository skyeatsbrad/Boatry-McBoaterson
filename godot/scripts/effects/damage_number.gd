extends Node2D

# Floating damage number that rises and fades out

const FLOAT_SPEED := 60.0
const DURATION := 0.5

var timer := 0.0

func _ready() -> void:
	timer = 0.0

func setup(amount: int, pos: Vector2, color: Color = Color.WHITE) -> void:
	global_position = pos
	$Label.text = str(amount)
	$Label.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	timer += delta
	var t := timer / DURATION
	position.y -= FLOAT_SPEED * delta
	modulate.a = 1.0 - t
	if timer >= DURATION:
		queue_free()
