extends CanvasLayer

# Debug performance overlay — toggle with F3.
# Shows FPS, enemy count, particle count, draw calls, memory.

const ENEMY_POOL_WARNING := 200
const UPDATE_INTERVAL := 0.25

var _visible := false
var _label: Label
var _update_timer := 0.0

func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -220
	_label.offset_right = -8
	_label.offset_top = 8
	_label.offset_bottom = 120
	_label.add_theme_font_size_override("font_size", 12)
	_label.visible = false
	add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_visible = not _visible
		_label.visible = _visible

func _process(delta: float) -> void:
	if not _visible:
		return

	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL

	var fps := Engine.get_frames_per_second()

	# Count enemies
	var enemy_count := 0
	var enemies_node := get_tree().get_first_node_in_group("enemies")
	if enemies_node == null:
		# Try to find Enemies container by name
		var root := get_tree().current_scene
		if root:
			var e := root.find_child("Enemies", true, false)
			if e:
				enemy_count = e.get_child_count()
	else:
		enemy_count = enemies_node.get_child_count()

	# Count particles
	var particle_count := 0
	var ps := get_tree().get_first_node_in_group("particles")
	if ps == null:
		var root := get_tree().current_scene
		if root:
			var p := root.find_child("ParticleSystem", true, false)
			if p and p.has_method("get_alive_count"):
				particle_count = p.get_alive_count()
	elif ps.has_method("get_alive_count"):
		particle_count = ps.get_alive_count()

	# Draw calls estimate (objects in viewport)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) if Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) > 0 else 0

	# Memory
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	# FPS color
	var fps_color := "green"
	if fps < 40:
		fps_color = "red"
	elif fps < 55:
		fps_color = "yellow"

	# Enemy warning
	var enemy_warn := ""
	if enemy_count > ENEMY_POOL_WARNING:
		enemy_warn = " [color=red]POOL![/color]"

	_label.text = "FPS: " + str(fps) \
		+ "\nEnemies: " + str(enemy_count) + (" POOL!" if enemy_count > ENEMY_POOL_WARNING else "") \
		+ "\nParticles: " + str(particle_count) \
		+ "\nDraw: " + str(draw_calls) \
		+ "\nMem: " + "%.1f" % mem_mb + " MB"

	# Color the label based on FPS
	if fps < 40:
		_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif fps < 55:
		_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	else:
		_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
