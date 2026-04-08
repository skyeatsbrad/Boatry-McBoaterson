extends Node
class_name SkinSystem

# Manages boat skins - cosmetic visual effects drawn on top of the hull
# Skins are unlocked with gold after playing 5+ games

const SKIN_COST := 100

var current_skin_id := "default"

# Skin definitions with visual parameters
var skins := {
	"default": {
		"name": "Default",
		"base_color": Color(0.24, 0.47, 0.86),
		"glow_color": Color.TRANSPARENT,
		"particle_color": Color.TRANSPARENT,
		"animation_speed": 0.0,
	},
	"flame": {
		"name": "Inferno",
		"base_color": Color(0.9, 0.3, 0.05),
		"glow_color": Color(1.0, 0.5, 0.0, 0.3),
		"particle_color": Color(1.0, 0.6, 0.1),
		"animation_speed": 5.0,
	},
	"electric": {
		"name": "Voltaic",
		"base_color": Color(0.1, 0.7, 0.9),
		"glow_color": Color(0.2, 0.9, 1.0, 0.25),
		"particle_color": Color(0.4, 0.95, 1.0),
		"animation_speed": 8.0,
	},
	"golden": {
		"name": "Gilded",
		"base_color": Color(1.0, 0.84, 0.0),
		"glow_color": Color(1.0, 0.9, 0.3, 0.2),
		"particle_color": Color(1.0, 0.95, 0.6),
		"animation_speed": 3.0,
	},
	"ghost": {
		"name": "Phantom",
		"base_color": Color(0.3, 0.9, 0.4, 0.5),
		"glow_color": Color(0.2, 0.95, 0.3, 0.2),
		"particle_color": Color(0.5, 1.0, 0.6, 0.6),
		"animation_speed": 2.0,
	},
	"ice": {
		"name": "Frostbite",
		"base_color": Color(0.7, 0.85, 1.0),
		"glow_color": Color(0.5, 0.8, 1.0, 0.25),
		"particle_color": Color(0.85, 0.95, 1.0),
		"animation_speed": 2.5,
	},
}

var _anim_time := 0.0

func _process(delta: float) -> void:
	var skin_data: Dictionary = skins.get(current_skin_id, skins["default"])
	if skin_data["animation_speed"] > 0:
		_anim_time += delta * skin_data["animation_speed"]

func get_skin_data(skin_id: String = "") -> Dictionary:
	var id := skin_id if skin_id != "" else current_skin_id
	return skins.get(id, skins["default"])

func get_hull_color() -> Color:
	return skins[current_skin_id]["base_color"]

func set_skin(skin_id: String) -> void:
	if skin_id in skins:
		current_skin_id = skin_id

func can_purchase() -> bool:
	return GameManager.can_unlock_skins()

func purchase_skin(skin_id: String) -> bool:
	if not can_purchase():
		return false
	if skin_id not in skins or skin_id == "default":
		return false
	if GameManager.is_skin_unlocked(skin_id):
		return false
	return GameManager.unlock_skin(skin_id, SKIN_COST)

## Draws the active skin effect on top of the base hull.
## Call this from _draw() after drawing the hull polygon.
func draw_skin(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	if current_skin_id == "default":
		return

	match current_skin_id:
		"flame":
			_draw_flame(canvas, center, hull_pts)
		"electric":
			_draw_electric(canvas, center, hull_pts)
		"golden":
			_draw_golden(canvas, center, hull_pts)
		"ghost":
			_draw_ghost(canvas, center, hull_pts)
		"ice":
			_draw_ice(canvas, center, hull_pts)

## Draws a preview of the given skin (used by skin shop).
func draw_skin_preview(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array, skin_id: String, time: float) -> void:
	if skin_id == "default":
		return
	# Temporarily override anim time for preview
	var saved := _anim_time
	_anim_time = time
	match skin_id:
		"flame":
			_draw_flame(canvas, center, hull_pts)
		"electric":
			_draw_electric(canvas, center, hull_pts)
		"golden":
			_draw_golden(canvas, center, hull_pts)
		"ghost":
			_draw_ghost(canvas, center, hull_pts)
		"ice":
			_draw_ice(canvas, center, hull_pts)
	_anim_time = saved

# === SKIN EFFECTS ===

func _draw_flame(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	var skin_data: Dictionary = skins["flame"]

	# Glow aura
	canvas.draw_circle(center, 22.0, skin_data["glow_color"])

	# Fire particles along hull edge
	for i in range(hull_pts.size()):
		var pt: Vector2 = hull_pts[i]
		var outward := (pt - center).normalized()
		# Flickering flame tongues
		var flame_h := (sin(_anim_time * 2.0 + i * 0.8) + 1.0) * 6.0 + 3.0
		var tip := pt + outward * flame_h
		var flame_alpha := 0.4 + sin(_anim_time * 3.0 + i) * 0.2
		# Flame gradient: yellow core -> orange -> red tip
		canvas.draw_line(pt, tip, Color(1.0, 0.8, 0.2, flame_alpha), 2.5)
		var mid_pt := pt + outward * flame_h * 0.5
		canvas.draw_circle(mid_pt, 2.0, Color(1.0, 0.5, 0.0, flame_alpha * 0.7))

	# Floating ember particles
	for i in range(6):
		var seed_val := float(i) * 2.39996
		var angle := fmod(seed_val + _anim_time * 0.7, TAU)
		var dist := 20.0 + sin(_anim_time * 1.5 + i * 1.1) * 8.0
		var ember_y_off := -fmod(_anim_time * 15.0 + i * 7.0, 20.0)
		var ember_pos := center + Vector2(cos(angle) * dist, sin(angle) * dist + ember_y_off)
		var ember_alpha := 0.7 - fmod(_anim_time + i * 0.5, 1.0) * 0.5
		if ember_alpha > 0:
			canvas.draw_circle(ember_pos, 1.5, Color(1.0, 0.6, 0.1, clampf(ember_alpha, 0, 1)))

func _draw_electric(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	var skin_data: Dictionary = skins["electric"]

	# Cyan pulse glow
	var pulse := (sin(_anim_time * 1.5) + 1.0) * 0.5
	canvas.draw_circle(center, 24.0 + pulse * 4.0,
		Color(skin_data["glow_color"].r, skin_data["glow_color"].g, skin_data["glow_color"].b, 0.15 + pulse * 0.1))

	# Lightning arcs along hull
	var arc_count := 3
	for arc in range(arc_count):
		# Pick two random-ish hull points for the arc
		var idx_a := int(fmod(_anim_time * 4.0 + arc * 7.3, hull_pts.size()))
		var idx_b := int(fmod(_anim_time * 4.0 + arc * 7.3 + hull_pts.size() * 0.4, hull_pts.size()))
		var pt_a: Vector2 = hull_pts[idx_a]
		var pt_b: Vector2 = hull_pts[idx_b]

		# Only draw arcs intermittently for crackling effect
		if int(_anim_time * 8.0 + arc * 2.5) % 3 == 0:
			_draw_lightning_arc(canvas, pt_a, pt_b, skin_data["particle_color"])

	# Spark particles on hull edge
	for i in range(hull_pts.size()):
		if int(_anim_time * 10.0 + i * 3.7) % 5 == 0:
			var pt: Vector2 = hull_pts[i]
			var outward := (pt - center).normalized()
			var spark_end := pt + outward * randf_range(4.0, 10.0)
			canvas.draw_line(pt, spark_end, Color(0.4, 0.95, 1.0, 0.8), 1.5)

func _draw_lightning_arc(canvas: Node2D, from: Vector2, to: Vector2, color: Color) -> void:
	var segments := 5
	var prev := from
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var pt := from.lerp(to, t)
		if i < segments:
			var perp := (to - from).normalized().rotated(PI * 0.5)
			pt += perp * sin(_anim_time * 12.0 + i * 2.0) * 6.0
		canvas.draw_line(prev, pt, Color(color.r, color.g, color.b, 0.7), 1.5)
		prev = pt

func _draw_golden(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	var skin_data: Dictionary = skins["golden"]

	# Shimmer: cycle brightness across the hull
	var shimmer_offset := _anim_time * 2.0
	for i in range(hull_pts.size() - 1):
		var t := float(i) / hull_pts.size()
		var shimmer := (sin(shimmer_offset + t * TAU * 2.0) + 1.0) * 0.5
		var c := skin_data["base_color"].lerp(Color(1, 1, 0.85), shimmer * 0.4)
		canvas.draw_line(hull_pts[i], hull_pts[(i + 1) % hull_pts.size()],
			Color(c.r, c.g, c.b, 0.6), 3.0)

	# Gold glow
	canvas.draw_circle(center, 20.0, skin_data["glow_color"])

	# Sparkle particles
	for i in range(8):
		var seed_val := float(i) * 1.618
		var angle := fmod(seed_val * TAU + _anim_time * 0.5, TAU)
		var dist := 10.0 + fmod(seed_val * 15.0 + _anim_time * 8.0, 18.0)
		var sparkle_pos := center + Vector2(cos(angle), sin(angle)) * dist
		var sparkle_phase := sin(_anim_time * 4.0 + i * 0.9)
		if sparkle_phase > 0.5:
			var alpha := (sparkle_phase - 0.5) * 2.0
			canvas.draw_circle(sparkle_pos, 1.5, Color(1, 1, 0.8, alpha * 0.8))
			# Star shape: 4 tiny lines
			for j in range(4):
				var sa := float(j) / 4.0 * TAU
				var tip := sparkle_pos + Vector2(cos(sa), sin(sa)) * 3.0
				canvas.draw_line(sparkle_pos, tip, Color(1, 1, 0.7, alpha * 0.5), 1.0)

func _draw_ghost(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	var skin_data: Dictionary = skins["ghost"]

	# Eerie green glow pulsing
	var pulse := (sin(_anim_time * 1.0) + 1.0) * 0.5
	canvas.draw_circle(center, 26.0 + pulse * 3.0,
		Color(0.2, 0.95, 0.3, 0.1 + pulse * 0.08))

	# Semi-transparent overlay on hull edge to look ghostly
	for i in range(hull_pts.size() - 1):
		var alpha := 0.2 + sin(_anim_time + float(i) * 0.5) * 0.1
		canvas.draw_line(hull_pts[i], hull_pts[(i + 1) % hull_pts.size()],
			Color(0.3, 1.0, 0.4, alpha), 2.0)

	# Wispy trail particles drifting upward
	for i in range(6):
		var seed_val := float(i) * 2.39996
		var x_off := sin(seed_val * 3.0 + _anim_time * 0.8) * 15.0
		var y_drift := -fmod(_anim_time * 12.0 + i * 8.0, 30.0)
		var wisp_pos := center + Vector2(x_off, y_drift + 10.0)
		var wisp_alpha := 0.5 - fmod(_anim_time * 0.8 + i * 0.3, 1.0) * 0.4
		if wisp_alpha > 0:
			canvas.draw_circle(wisp_pos, 2.0 + sin(_anim_time + i) * 0.5,
				Color(0.4, 1.0, 0.5, clampf(wisp_alpha, 0, 0.6)))

	# Ghostly face flicker
	if int(_anim_time * 2.0) % 4 == 0:
		canvas.draw_circle(center + Vector2(-5, -2), 2.0, Color(0.3, 1.0, 0.4, 0.3))
		canvas.draw_circle(center + Vector2(5, -2), 2.0, Color(0.3, 1.0, 0.4, 0.3))

func _draw_ice(canvas: Node2D, center: Vector2, hull_pts: PackedVector2Array) -> void:
	var skin_data: Dictionary = skins["ice"]

	# Frost glow
	canvas.draw_circle(center, 22.0, skin_data["glow_color"])

	# Ice crystals on hull edges
	for i in range(0, hull_pts.size(), 3):
		var pt: Vector2 = hull_pts[i]
		var outward := (pt - center).normalized()
		var crystal_len := 4.0 + sin(_anim_time * 1.5 + i * 0.7) * 2.0
		var tip := pt + outward * crystal_len
		# Main crystal line
		canvas.draw_line(pt, tip, Color(0.7, 0.9, 1.0, 0.7), 2.0)
		# Crystal branches
		var branch_a := tip + outward.rotated(0.6) * crystal_len * 0.5
		var branch_b := tip + outward.rotated(-0.6) * crystal_len * 0.5
		canvas.draw_line(tip, branch_a, Color(0.8, 0.95, 1.0, 0.5), 1.0)
		canvas.draw_line(tip, branch_b, Color(0.8, 0.95, 1.0, 0.5), 1.0)

	# Snowflake particles floating around
	for i in range(7):
		var seed_val := float(i) * 1.618
		var angle := fmod(seed_val * TAU + _anim_time * 0.3, TAU)
		var dist := 8.0 + fmod(seed_val * 20.0 + _anim_time * 5.0, 20.0)
		var sf_pos := center + Vector2(cos(angle), sin(angle)) * dist
		var sf_alpha := (sin(_anim_time * 2.0 + i * 1.5) + 1.0) * 0.3

		# Simple snowflake: 3 crossed lines
		var sf_size := 2.5
		for j in range(3):
			var sa := float(j) / 3.0 * PI
			var arm_a := sf_pos + Vector2(cos(sa), sin(sa)) * sf_size
			var arm_b := sf_pos - Vector2(cos(sa), sin(sa)) * sf_size
			canvas.draw_line(arm_a, arm_b, Color(0.9, 0.95, 1.0, sf_alpha), 1.0)

	# Frost rim glow on hull outline
	var rim_pulse := (sin(_anim_time * 2.0) + 1.0) * 0.15 + 0.15
	for i in range(hull_pts.size() - 1):
		canvas.draw_line(hull_pts[i], hull_pts[(i + 1) % hull_pts.size()],
			Color(0.6, 0.85, 1.0, rim_pulse), 2.0)
