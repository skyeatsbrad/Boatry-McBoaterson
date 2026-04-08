extends Camera2D

# Camera that follows both players in co-op.
# Sits at midpoint, zooms out when players are far apart, smooth transitions.

const MIN_ZOOM := 0.6
const MAX_ZOOM := 1.2
const ZOOM_MARGIN := 150.0  # Extra pixels around the bounding box
const SMOOTH_SPEED := 5.0
const ZOOM_SMOOTH_SPEED := 3.0

# Distance thresholds for zoom interpolation
const CLOSE_DIST := 200.0
const FAR_DIST := 800.0

var player_1: CharacterBody2D = null
var player_2: CharacterBody2D = null
var player_1_alive := true
var player_2_alive := true

var _target_position := Vector2.ZERO
var _target_zoom := Vector2(MAX_ZOOM, MAX_ZOOM)


func _ready() -> void:
	make_current()


func setup(p1: CharacterBody2D, p2: CharacterBody2D) -> void:
	player_1 = p1
	player_2 = p2
	player_1_alive = true
	player_2_alive = true
	if player_1:
		_target_position = player_1.position
		position = _target_position


func set_player_alive(index: int, alive: bool) -> void:
	if index == 1:
		player_1_alive = alive
	elif index == 2:
		player_2_alive = alive


func _process(delta: float) -> void:
	var p1_valid := player_1 != null and is_instance_valid(player_1) and player_1_alive
	var p2_valid := player_2 != null and is_instance_valid(player_2) and player_2_alive

	if p1_valid and p2_valid:
		_follow_both(delta)
	elif p1_valid:
		_follow_single(player_1, delta)
	elif p2_valid:
		_follow_single(player_2, delta)

	# Smooth position
	position = position.lerp(_target_position, SMOOTH_SPEED * delta)
	# Smooth zoom
	zoom = zoom.lerp(_target_zoom, ZOOM_SMOOTH_SPEED * delta)


func _follow_both(delta: float) -> void:
	# Midpoint
	_target_position = (player_1.position + player_2.position) * 0.5

	# Zoom based on distance between players
	var dist := player_1.position.distance_to(player_2.position)
	var t := clampf((dist - CLOSE_DIST) / (FAR_DIST - CLOSE_DIST), 0.0, 1.0)
	var zoom_level := lerpf(MAX_ZOOM, MIN_ZOOM, t)
	_target_zoom = Vector2(zoom_level, zoom_level)


func _follow_single(player: CharacterBody2D, _delta: float) -> void:
	_target_position = player.position
	_target_zoom = Vector2(MAX_ZOOM, MAX_ZOOM)
