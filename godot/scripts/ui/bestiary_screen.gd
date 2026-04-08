extends Control

# Bestiary UI — displays all enemy entries from the Bestiary node.
# Undiscovered enemies show as "???" silhouettes.

signal closed

const ENTRY_SIZE := Vector2(200, 240)
const COLUMNS := 3
const PADDING := 16.0

var bestiary: Node = null  # Reference to bestiary.gd node
var _entries_data := {}
var _scroll_offset := 0.0

@onready var back_btn: Button = $BackButton


func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back)
	else:
		# Create back button if not in scene tree
		back_btn = Button.new()
		back_btn.name = "BackButton"
		back_btn.text = "Back"
		back_btn.position = Vector2(20, 20)
		back_btn.custom_minimum_size = Vector2(100, 40)
		back_btn.pressed.connect(_on_back)
		add_child(back_btn)


func setup(bestiary_node: Node) -> void:
	bestiary = bestiary_node
	if bestiary and bestiary.has_method("get_all_entries"):
		_entries_data = bestiary.get_all_entries()
	queue_redraw()


func _on_back() -> void:
	AudioManager.play("select")
	closed.emit()
	visible = false


func _gui_input(event: InputEvent) -> void:
	# Scroll support
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = maxf(_scroll_offset - 40.0, 0.0)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset += 40.0
			queue_redraw()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.15, 0.95))

	# Title
	var title_pos := Vector2(size.x / 2.0 - 60.0, 50.0 - _scroll_offset)
	draw_string(ThemeDB.fallback_font, title_pos, "SHIP LOG",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1.0, 0.84, 0.0))

	# Discovered count
	var discovered := 0
	var total := _entries_data.size()
	for key in _entries_data:
		if _entries_data[key].get("seen", false):
			discovered += 1
	var count_text := "Discovered: %d / %d" % [discovered, total]
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 50.0, 75.0 - _scroll_offset),
				count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

	# Entries grid
	var start_y := 100.0 - _scroll_offset
	var keys := _entries_data.keys()
	for i in range(keys.size()):
		var key: String = keys[i]
		var entry: Dictionary = _entries_data[key]
		var col := i % COLUMNS
		var row := i / COLUMNS
		var x := PADDING + col * (ENTRY_SIZE.x + PADDING) + (size.x - COLUMNS * (ENTRY_SIZE.x + PADDING)) / 2.0
		var y := start_y + row * (ENTRY_SIZE.y + PADDING)
		_draw_entry(Vector2(x, y), key, entry)


func _draw_entry(pos: Vector2, key: String, entry: Dictionary) -> void:
	var seen: bool = entry.get("seen", false)
	var killed: int = entry.get("killed", 0)
	var entry_name: String = entry.get("name", key) if seen else "???"
	var desc: String = entry.get("desc", "") if seen else "Not yet discovered..."
	var color: Color = entry.get("color", Color.GRAY) if seen else Color(0.2, 0.2, 0.3)
	var is_boss: bool = entry.get("is_boss", false)

	# Card background
	var card_color := Color(0.12, 0.15, 0.25) if seen else Color(0.08, 0.08, 0.12)
	draw_rect(Rect2(pos, ENTRY_SIZE), card_color)
	var border_color := color if seen else Color(0.3, 0.3, 0.35)
	draw_rect(Rect2(pos, ENTRY_SIZE), border_color, false, 2.0)

	# Boss badge
	if is_boss and seen:
		draw_string(ThemeDB.fallback_font, pos + Vector2(ENTRY_SIZE.x - 46, 18),
					"BOSS", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(1.0, 0.3, 0.3))

	# Enemy preview (procedural circle silhouette)
	var preview_center := pos + Vector2(ENTRY_SIZE.x / 2.0, 70.0)
	if seen:
		_draw_enemy_preview(preview_center, key, color)
	else:
		# Silhouette
		draw_circle(preview_center, 25.0, Color(0.15, 0.15, 0.2))
		draw_string(ThemeDB.fallback_font, preview_center + Vector2(-6, 5),
					"?", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.4, 0.4, 0.5))

	# Name
	var name_pos := pos + Vector2(10, 120)
	var name_color := Color.WHITE if seen else Color(0.5, 0.5, 0.5)
	draw_string(ThemeDB.fallback_font, name_pos, entry_name,
				HORIZONTAL_ALIGNMENT_LEFT, int(ENTRY_SIZE.x - 20), 16, name_color)

	# Kill count
	if seen:
		var kills_text := "Kills: %d" % killed
		draw_string(ThemeDB.fallback_font, pos + Vector2(10, 142),
					kills_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.6))

	# Description (word-wrapped manually)
	var desc_y := 158.0 if seen else 140.0
	var max_chars_per_line := int(ENTRY_SIZE.x - 20) / 7  # approximate char width
	var lines := _wrap_text(desc, max_chars_per_line)
	for line_i in range(mini(lines.size(), 4)):
		draw_string(ThemeDB.fallback_font, pos + Vector2(10, desc_y + line_i * 14),
					lines[line_i], HORIZONTAL_ALIGNMENT_LEFT, int(ENTRY_SIZE.x - 20),
					11, Color(0.65, 0.65, 0.7))


func _draw_enemy_preview(center: Vector2, fish_type: String, color: Color) -> void:
	match fish_type:
		"piranha":
			draw_circle(center, 15.0, color)
			draw_line(center + Vector2(-15, 0), center + Vector2(-22, -5), color, 2.0)
			draw_line(center + Vector2(-15, 0), center + Vector2(-22, 5), color, 2.0)
			draw_circle(center + Vector2(5, -3), 2.0, Color.YELLOW)
		"pufferfish":
			draw_circle(center, 18.0, color)
			for i in range(8):
				var a := float(i) / 8.0 * TAU
				var tip := center + Vector2(cos(a), sin(a)) * 23.0
				draw_line(center + Vector2(cos(a), sin(a)) * 18.0, tip, color.darkened(0.3), 2.0)
		"swordfish":
			draw_circle(center, 14.0, color)
			draw_line(center + Vector2(14, 0), center + Vector2(30, 0), color.lightened(0.3), 3.0)
		"jellyfish":
			draw_arc(center, 14.0, PI, TAU, 12, color, 3.0)
			for i in range(5):
				var x := -8.0 + i * 4.0
				draw_line(center + Vector2(x, 5), center + Vector2(x, 20),
						  Color(color.r, color.g, color.b, 0.6), 1.5)
		"eel":
			for i in range(6):
				var t := float(i) / 5.0
				var x := lerpf(-15.0, 15.0, t)
				var y := sin(t * 4.0) * 5.0
				if i < 5:
					var x2 := lerpf(-15.0, 15.0, float(i + 1) / 5.0)
					var y2 := sin(float(i + 1) / 5.0 * 4.0) * 5.0
					draw_line(center + Vector2(x, y), center + Vector2(x2, y2), color, 4.0)
		"anglerfish":
			draw_circle(center, 18.0, color)
			draw_line(center + Vector2(0, -18), center + Vector2(5, -30), color.lightened(0.3), 1.5)
			draw_circle(center + Vector2(5, -30), 4.0, Color(0.2, 1.0, 0.2, 0.8))
		"shark":
			draw_circle(center, 20.0, color)
			var fin: PackedVector2Array = [
				center + Vector2(0, -20), center + Vector2(-8, -34), center + Vector2(6, -20)]
			draw_colored_polygon(fin, color.darkened(0.2))
		"kraken":
			draw_circle(center, 22.0, color)
			for i in range(6):
				var a := float(i) / 6.0 * TAU
				var base_pt := center + Vector2(cos(a), sin(a)) * 22.0
				var tip := center + Vector2(cos(a), sin(a)) * 34.0
				draw_line(base_pt, tip, color.lightened(0.2), 2.5)
			# Crown
			draw_circle(center + Vector2(0, -20), 5.0, Color(1.0, 0.84, 0.0))
		_:
			draw_circle(center, 15.0, color)


func _wrap_text(text: String, max_chars: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var words := text.split(" ")
	var current_line := ""
	for word in words:
		if current_line.length() + word.length() + 1 > max_chars and current_line.length() > 0:
			lines.append(current_line)
			current_line = word
		else:
			if current_line.length() > 0:
				current_line += " "
			current_line += word
	if current_line.length() > 0:
		lines.append(current_line)
	return lines
