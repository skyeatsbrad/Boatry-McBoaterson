extends CanvasLayer
class_name TouchControls

## Touch control manager. Adds virtual joystick and dash button on mobile.
## Supports one-hand mode with auto-dash when surrounded.

signal dash_pressed

const DASH_BUTTON_RADIUS := 50.0
const AUTO_DASH_ENEMY_THRESHOLD := 5
const AUTO_DASH_RANGE := 200.0
const AUTO_DASH_COOLDOWN := 2.0

var joystick: VirtualJoystick
var one_hand_mode := false
var is_touch_device := false

var _dash_touch_index := -1
var _dash_cooldown := 0.0
var _auto_dash_timer := 0.0

# Dash button position (bottom-right) — set in _ready based on viewport
var _dash_center := Vector2.ZERO
# Control node to draw the dash button
var _dash_button: Control

func _ready() -> void:
	is_touch_device = _detect_touch()
	if not is_touch_device:
		return

	layer = 10  # render above gameplay

	# Add joystick
	joystick = VirtualJoystick.new()
	add_child(joystick)

	# Add dash button draw surface
	_dash_button = Control.new()
	_dash_button.name = "DashButton"
	_dash_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dash_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dash_button)
	_dash_button.draw.connect(_draw_dash_button)

	_update_layout()

func _detect_touch() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)

func _update_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_dash_center = Vector2(vp_size.x - DASH_BUTTON_RADIUS - 50, vp_size.y - DASH_BUTTON_RADIUS - 50)
	if _dash_button:
		_dash_button.queue_redraw()

func _process(delta: float) -> void:
	if not is_touch_device:
		return

	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta
		if _dash_button:
			_dash_button.queue_redraw()

	# One-hand mode: auto-dash when surrounded
	if one_hand_mode:
		_auto_dash_timer -= delta
		if _auto_dash_timer <= 0.0:
			_auto_dash_timer = 0.5  # check twice per second
			if _count_nearby_enemies() >= AUTO_DASH_ENEMY_THRESHOLD:
				_trigger_dash()

func _input(event: InputEvent) -> void:
	if not is_touch_device or one_hand_mode:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_in_dash_area(touch.position) and _dash_cooldown <= 0.0:
				_dash_touch_index = touch.index
				_trigger_dash()
		else:
			if touch.index == _dash_touch_index:
				_dash_touch_index = -1

func _is_in_dash_area(screen_pos: Vector2) -> bool:
	return screen_pos.distance_to(_dash_center) <= DASH_BUTTON_RADIUS + 20.0

func _trigger_dash() -> void:
	dash_pressed.emit()
	# Also fire the input action so the player script picks it up
	var ev := InputEventAction.new()
	ev.action = "dash"
	ev.pressed = true
	Input.parse_input_event(ev)
	_dash_cooldown = 1.5
	if _dash_button:
		_dash_button.queue_redraw()

func _count_nearby_enemies() -> int:
	var player_node := _find_player()
	if not player_node:
		return 0
	var count := 0
	var enemies := player_node.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			if player_node.global_position.distance_to(enemy.global_position) <= AUTO_DASH_RANGE:
				count += 1
	return count

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _draw_dash_button() -> void:
	if not is_touch_device or one_hand_mode:
		return

	var opacity := 0.7 if _dash_cooldown <= 0.0 else 0.35

	# Circle background
	_dash_button.draw_circle(_dash_center, DASH_BUTTON_RADIUS, Color(0.2, 0.2, 0.3, opacity))
	_dash_button.draw_arc(_dash_center, DASH_BUTTON_RADIUS, 0, TAU, 48, Color(0.8, 0.8, 0.9, opacity), 3.0)

	# Cooldown arc overlay
	if _dash_cooldown > 0.0:
		var ratio := _dash_cooldown / 1.5
		var sweep := TAU * ratio
		_dash_button.draw_arc(_dash_center, DASH_BUTTON_RADIUS - 5.0, -PI / 2.0, -PI / 2.0 + sweep, 32,
			Color(0.9, 0.2, 0.2, 0.5), 6.0)

	# Label
	_dash_button.draw_string(
		ThemeDB.fallback_font, _dash_center + Vector2(-22, 7),
		"DASH", HORIZONTAL_ALIGNMENT_CENTER, -1, 18,
		Color(1.0, 1.0, 1.0, opacity))

## Get movement direction from the joystick.
func get_movement() -> Vector2:
	if joystick:
		return joystick.direction
	return Vector2.ZERO

## Toggle one-hand mode. In this mode the dash button hides and auto-dash activates.
func set_one_hand_mode(enabled: bool) -> void:
	one_hand_mode = enabled
	if _dash_button:
		_dash_button.queue_redraw()
