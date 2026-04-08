extends Node2D

# Enhanced floating text for damage, heals, gold, combos, crits.
# Uses _draw() with default font — no Label node needed.

enum Style { DAMAGE, HEAL, GOLD, COMBO, CRITICAL }

const DURATION := 0.8
const FLOAT_SPEED := 70.0
const BOUNCE_HEIGHT := 12.0
const COMBO_SCALE_PEAK := 1.6

var text := ""
var style: Style = Style.DAMAGE
var color := Color.WHITE
var timer := 0.0
var font: Font
var font_size := 16
var _start_pos := Vector2.ZERO

func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 200

func setup(value, pos: Vector2, p_style: Style = Style.DAMAGE) -> void:
	style = p_style
	_start_pos = pos
	global_position = pos

	match style:
		Style.DAMAGE:
			text = str(value)
			color = Color(1.0, 0.25, 0.2)
			font_size = 16
		Style.HEAL:
			text = "+" + str(value)
			color = Color(0.2, 1.0, 0.4)
			font_size = 16
		Style.GOLD:
			text = "+" + str(value) + "g"
			color = Color(1.0, 0.85, 0.2)
			font_size = 14
		Style.COMBO:
			text = "COMBO x" + str(value) + "!"
			color = Color(1.0, 0.5, 0.0) if not (value is Color) else value
			font_size = 20
		Style.CRITICAL:
			text = str(value) + "!"
			color = Color.WHITE
			font_size = 22

func setup_combo(combo_count: int, tier_color: Color, pos: Vector2) -> void:
	style = Style.COMBO
	text = "COMBO x" + str(combo_count) + "!"
	color = tier_color
	font_size = 20
	_start_pos = pos
	global_position = pos

func _process(delta: float) -> void:
	timer += delta
	var t := timer / DURATION

	match style:
		Style.DAMAGE:
			# Rise with a small bounce arc
			var bounce := sin(t * PI) * BOUNCE_HEIGHT
			position.y = _start_pos.y - global_position.y - FLOAT_SPEED * timer - bounce
			position.x = sin(timer * 6.0) * 3.0
		Style.HEAL, Style.GOLD:
			position.y -= FLOAT_SPEED * delta
		Style.COMBO:
			position.y -= FLOAT_SPEED * 0.6 * delta
		Style.CRITICAL:
			position.y -= FLOAT_SPEED * 1.2 * delta
			position.x = sin(timer * 8.0) * 2.0

	if timer >= DURATION:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t := clampf(timer / DURATION, 0.0, 1.0)
	var alpha := 1.0 - t * t  # Ease-out fade

	var scale_factor := 1.0
	if style == Style.COMBO:
		# Scale up then shrink
		if t < 0.3:
			scale_factor = lerpf(1.0, COMBO_SCALE_PEAK, t / 0.3)
		else:
			scale_factor = lerpf(COMBO_SCALE_PEAK, 0.8, (t - 0.3) / 0.7)
	elif style == Style.CRITICAL:
		scale_factor = lerpf(1.4, 1.0, t)

	var sz := int(font_size * scale_factor)
	var col := color
	col.a = alpha

	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, sz)
	var draw_pos := Vector2(-text_size.x * 0.5, 0.0)

	# Shadow
	var shadow_col := Color(0, 0, 0, alpha * 0.5)
	draw_string(font, draw_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, shadow_col)

	# Main text
	draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
