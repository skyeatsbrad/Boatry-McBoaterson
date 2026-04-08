extends Control
class_name VirtualJoystick

## Touch joystick that returns a normalized Vector2 direction.
## Draws itself as an outer ring with inner knob. Appears on touch devices only.

signal direction_changed(dir: Vector2)

const OUTER_RADIUS := 100.0
const INNER_RADIUS := 30.0
const DEADZONE := 10.0

## Normalized direction vector other scripts can read.
var direction := Vector2.ZERO

var _touch_index := -1
var _knob_position := Vector2.ZERO
var _center := Vector2.ZERO
var _is_touch_device := false

@export var base_opacity := 0.4
@export var active_opacity := 0.7

func _ready() -> void:
	_is_touch_device = _detect_touch_device()
	visible = _is_touch_device

	# Position in bottom-left corner with padding
	custom_minimum_size = Vector2(OUTER_RADIUS * 2, OUTER_RADIUS * 2)
	size = custom_minimum_size
	position = Vector2(40, get_viewport_rect().size.y - size.y - 40)
	_center = size / 2.0
	_knob_position = _center

	modulate.a = base_opacity
	mouse_filter = Control.MOUSE_FILTER_STOP

func _detect_touch_device() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and _is_in_joystick_area(touch.position):
				_touch_index = touch.index
				_update_knob(touch.position)
				modulate.a = active_opacity
		else:
			if touch.index == _touch_index:
				_reset()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)

func _is_in_joystick_area(screen_pos: Vector2) -> bool:
	var local := screen_pos - global_position
	return local.distance_to(_center) <= OUTER_RADIUS + 40.0

func _update_knob(screen_pos: Vector2) -> void:
	var local := screen_pos - global_position
	var offset := local - _center
	var dist := offset.length()

	if dist < DEADZONE:
		direction = Vector2.ZERO
		_knob_position = _center
	else:
		direction = offset.normalized()
		_knob_position = _center + direction * minf(dist, OUTER_RADIUS - INNER_RADIUS)

	direction_changed.emit(direction)
	queue_redraw()

func _reset() -> void:
	_touch_index = -1
	_knob_position = _center
	direction = Vector2.ZERO
	modulate.a = base_opacity
	direction_changed.emit(direction)
	queue_redraw()

func _draw() -> void:
	# Outer ring
	draw_arc(_center, OUTER_RADIUS, 0, TAU, 64, Color(0.5, 0.5, 0.5, 0.6), 3.0)
	draw_circle(_center, OUTER_RADIUS, Color(0.2, 0.2, 0.2, 0.2))

	# Inner knob
	draw_circle(_knob_position, INNER_RADIUS, Color(1.0, 1.0, 1.0, 0.7))
	draw_arc(_knob_position, INNER_RADIUS, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0)

## Call this to show/hide regardless of platform (e.g. settings toggle).
func set_touch_visible(show: bool) -> void:
	_is_touch_device = show
	visible = show
