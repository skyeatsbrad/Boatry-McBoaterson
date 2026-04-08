extends Node2D

## Visual effect that draws jagged lightning bolts between chain_points,
## or an AoE blast ring when is_aoe_ring is true.
## Fades out over FADE_TIME seconds and then frees itself.

const FADE_TIME := 0.2
const JITTER_AMOUNT := 12.0
const SEGMENTS_PER_CHAIN := 6

var chain_points: Array[Vector2] = []
var is_aoe_ring := false
var aoe_center := Vector2.ZERO
var aoe_radius := 100.0

var _elapsed := 0.0
var _jitter_cache: Array[Array] = []


func _ready() -> void:
	_build_jitter_cache()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= FADE_TIME:
		queue_free()
		return
	queue_redraw()


func _build_jitter_cache() -> void:
	# Pre-generate random midpoint offsets for each segment of each chain link
	_jitter_cache.clear()
	if chain_points.size() < 2:
		return
	for i in range(chain_points.size() - 1):
		var offsets: Array = []
		for _s in range(SEGMENTS_PER_CHAIN - 1):
			offsets.append(randf_range(-JITTER_AMOUNT, JITTER_AMOUNT))
		_jitter_cache.append(offsets)


func _draw() -> void:
	var alpha: float = clampf(1.0 - _elapsed / FADE_TIME, 0.0, 1.0)
	var color := Color(0.0, 1.0, 1.0, alpha)  # cyan
	var thin_color := Color(0.7, 1.0, 1.0, alpha * 0.5)

	if is_aoe_ring:
		_draw_aoe_ring(color, thin_color, alpha)
		return

	if chain_points.size() < 2:
		return

	for i in range(chain_points.size() - 1):
		var start: Vector2 = chain_points[i]
		var end: Vector2 = chain_points[i + 1]
		_draw_jagged_line(start, end, i, color, thin_color)

	# Draw impact circles at each target (skip index 0 which is the player)
	for i in range(1, chain_points.size()):
		draw_circle(chain_points[i], 6.0 * alpha, thin_color)


func _draw_jagged_line(start: Vector2, end: Vector2, chain_idx: int,
					   color: Color, thin_color: Color) -> void:
	var dir := (end - start)
	var length := dir.length()
	var norm := dir.normalized()
	var perp := Vector2(-norm.y, norm.x)

	var points: PackedVector2Array = [start]

	var offsets: Array = _jitter_cache[chain_idx] if chain_idx < _jitter_cache.size() else []

	for s in range(1, SEGMENTS_PER_CHAIN):
		var t := float(s) / SEGMENTS_PER_CHAIN
		var base_pos: Vector2 = start + dir * t
		var jitter := 0.0
		if s - 1 < offsets.size():
			jitter = offsets[s - 1]
		points.append(base_pos + perp * jitter)

	points.append(end)

	# Thick glow line then thin bright core
	draw_polyline(points, thin_color, 4.0)
	draw_polyline(points, color, 1.5)


func _draw_aoe_ring(color: Color, thin_color: Color, alpha: float) -> void:
	var expand := 1.0 + _elapsed / FADE_TIME * 0.3  # slight expansion
	var r := aoe_radius * expand
	draw_arc(aoe_center, r, 0, TAU, 32, color, 3.0)
	draw_arc(aoe_center, r * 0.7, 0, TAU, 24, thin_color, 2.0)
	# Inner flash
	draw_circle(aoe_center, 8.0 * alpha, color)
