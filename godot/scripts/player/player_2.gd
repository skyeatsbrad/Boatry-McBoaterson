extends CharacterBody2D

# Player 2 for local co-op — same muscular boat, different controls.
# Uses IJKL for movement, Right Shift for dash, or controller 2.

signal hp_changed(current: int, max_hp: int)
signal xp_changed(current: int, needed: int)
signal leveled_up(level: int)
signal died
signal dashed

const BASE_HP := 100
const BASE_SPEED := 200.0
const DASH_SPEED := 700.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 1.5
const INVULN_TIME := 0.3

@export var hull_color := Color(0.93, 0.55, 0.14)  # Orange default

var max_hp := BASE_HP
var hp := BASE_HP
var speed := BASE_SPEED
var level := 1
var xp := 0
var xp_to_next := 20
var xp_bonus := 1.0
var gold := 0
var kills := 0
var dashes_used := 0
var weapon_type := "cannon"
var proj_damage := 20
var proj_speed := 400.0
var proj_count := 1
var proj_cooldown := 0.5
var _cooldown_timer := 0.0
var _invuln_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := Vector2.ZERO
var facing := Vector2.RIGHT
var _bob_timer := 0.0

# Muscular arm animation
var _arm_flex_timer := 0.0
var _arm_flex_speed := 3.0

# Orbit weapon
var has_orbit := false
var orbit_count := 3
var orbit_radius := 70.0
var orbit_damage := 15
var orbit_angle := 0.0

# Aura
var has_aura := false
var aura_radius := 80.0
var aura_damage := 5

# Explosion
var has_explosion := false
var explosion_cooldown := 2.0
var explosion_timer := 0.0
var explosion_radius := 100.0
var explosion_damage := 30

# Player index for controller support (device 1 = second controller)
var device_index := 1


func _ready() -> void:
	add_to_group("player")
	var ch: Dictionary = GameManager.get_character()
	var ups: Dictionary = GameManager.save_data["upgrades"]
	# Keep orange hull unless co-op manager overrides
	max_hp = int((BASE_HP + ups["max_hp"] * 10) * ch["hp_mod"])
	hp = max_hp
	speed = (BASE_SPEED + ups["speed"] * 15.0) * ch["spd_mod"]
	proj_damage = int((20 + ups["damage"] * 5) * ch["dmg_mod"])
	xp_bonus = 1.0 + ups["xp_bonus"] * 0.1
	weapon_type = ch["weapon"]
	# Spawn slightly offset from center
	position = GameManager.WORLD_SIZE / 2 + Vector2(60, 0)


func _physics_process(delta: float) -> void:
	_bob_timer += delta * 3.0
	_arm_flex_timer += delta * _arm_flex_speed

	# Dash
	if _dash_timer > 0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		var input := _get_input()
		if input.length() > 0:
			input = input.normalized()
			facing = input
		velocity = input * speed

	move_and_slide()
	position = position.clamp(Vector2.ZERO, GameManager.WORLD_SIZE)

	# Timers
	if _invuln_timer > 0:
		_invuln_timer -= delta
	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
	if has_explosion and explosion_timer > 0:
		explosion_timer -= delta
	if has_orbit:
		orbit_angle += delta * 3.0

	queue_redraw()


func _get_input() -> Vector2:
	var input := Vector2.ZERO
	# Keyboard: IJKL
	if Input.is_key_pressed(KEY_J):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_L):
		input.x += 1.0
	if Input.is_key_pressed(KEY_I):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_K):
		input.y += 1.0

	# Controller 2 left stick
	var joy_x := Input.get_joy_axis(device_index, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(device_index, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.2:
		input.x += joy_x
	if abs(joy_y) > 0.2:
		input.y += joy_y

	return input


func _unhandled_input(event: InputEvent) -> void:
	# Right Shift for dash
	if event is InputEventKey and event.pressed and event.keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
		start_dash()
		return
	# Controller 2 shoulder button for dash
	if event is InputEventJoypadButton and event.device == device_index and event.pressed:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			start_dash()


func start_dash() -> bool:
	if _dash_cooldown_timer > 0 or _dash_timer > 0:
		return false
	_dash_dir = facing if facing.length() > 0 else Vector2.RIGHT
	_dash_timer = DASH_DURATION
	_dash_cooldown_timer = DASH_COOLDOWN
	_invuln_timer = DASH_DURATION + 0.05
	dashes_used += 1
	dashed.emit()
	AudioManager.play("dash")
	return true


func take_damage(amount: int) -> void:
	if _invuln_timer > 0:
		return
	hp -= amount
	_invuln_timer = INVULN_TIME
	hp_changed.emit(hp, max_hp)
	AudioManager.play("hurt")
	if hp <= 0:
		died.emit()


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
	AudioManager.play("heal")


func gain_xp(amount: int) -> bool:
	xp += int(amount * xp_bonus * GameManager.combo_multiplier)
	xp_changed.emit(xp, xp_to_next)
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.4)
		leveled_up.emit(level)
		AudioManager.play("levelup")
		return true
	return false


# === DRAWING (identical to player.gd but uses this node's hull_color) ===

func _draw() -> void:
	var bob := sin(_bob_timer) * 2.0
	var center := Vector2(0, bob)

	if _invuln_timer > 0 and int(_invuln_timer * 10) % 2 == 1:
		return

	# Hull
	var hull_pts: PackedVector2Array = []
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		hull_pts.append(center + Vector2(cos(a) * 18.0, sin(a) * 12.0))
	draw_colored_polygon(hull_pts, hull_color)
	draw_polyline(hull_pts, Color.WHITE, 2.0, true)

	# Bow
	var bow := center + facing.normalized() * 20.0
	draw_line(center + facing.normalized() * 18.0, bow, hull_color.lightened(0.2), 4.0)

	# Cabin
	draw_rect(Rect2(center + Vector2(-6, -8 + bob), Vector2(12, 8)), hull_color.lightened(0.15))
	draw_rect(Rect2(center + Vector2(-6, -8 + bob), Vector2(12, 8)), Color.WHITE, false, 1.0)

	# "P2" indicator above the boat
	draw_string(ThemeDB.fallback_font, center + Vector2(-6, -22 + bob), "P2",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# Muscular arms
	var flex := sin(_arm_flex_timer) * 0.15 + 1.0
	var arm_color := Color(0.85, 0.65, 0.45)

	var l_shoulder := center + Vector2(-16, -2 + bob)
	var l_elbow := l_shoulder + Vector2(-12, -10 * flex)
	var l_hand := l_elbow + Vector2(-4, -8 * flex)
	_draw_muscular_arm(l_shoulder, l_elbow, l_hand, arm_color, flex)

	var r_shoulder := center + Vector2(16, -2 + bob)
	var r_elbow := r_shoulder + Vector2(12, -10 * flex)
	var r_hand := r_elbow + Vector2(4, -8 * flex)
	_draw_muscular_arm(r_shoulder, r_elbow, r_hand, arm_color, flex)

	# Eyes
	var eye_y := center.y - 2 + bob
	draw_circle(Vector2(-5, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(5, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4, eye_y), 1.5, Color.BLACK)
	draw_circle(Vector2(6, eye_y), 1.5, Color.BLACK)

	# Dash cooldown bar
	if _dash_cooldown_timer > 0:
		var ratio := 1.0 - _dash_cooldown_timer / DASH_COOLDOWN
		draw_rect(Rect2(Vector2(-15, 20 + bob), Vector2(30, 3)), Color(0.2, 0.2, 0.3))
		draw_rect(Rect2(Vector2(-15, 20 + bob), Vector2(30 * ratio, 3)), Color(0.93, 0.55, 0.14))


func _draw_muscular_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2,
						color: Color, flex: float) -> void:
	var bicep_thickness := 5.0 * flex
	draw_line(shoulder, elbow, color, bicep_thickness)
	draw_line(shoulder, elbow, color.darkened(0.2), bicep_thickness + 1.0)
	var mid := (shoulder + elbow) / 2.0
	draw_circle(mid, bicep_thickness * 0.7, color)
	draw_line(elbow, hand, color, 4.0)
	draw_line(elbow, hand, color.darkened(0.2), 5.0)
	draw_circle(hand, 4.0, color)
	draw_circle(hand, 4.0, color.darkened(0.15))
