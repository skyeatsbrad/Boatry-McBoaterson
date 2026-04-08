extends Control

# Skin Shop UI - grid of skin cards with animated previews
# Requires GameManager autoload and SkinSystem instance

const CARD_WIDTH := 160.0
const CARD_HEIGHT := 200.0
const CARD_GAP := 16.0
const COLUMNS := 3
const PREVIEW_SIZE := 60.0
const HEADER_HEIGHT := 60.0

var skin_system: SkinSystem = null
var _anim_time := 0.0
var _selected_skin := ""
var _hovered_card := ""
var _message_timer := 0.0
var _message_text := ""

# Skin order for display
var skin_order := ["default", "flame", "electric", "golden", "ghost", "ice"]

signal skin_equipped(skin_id: String)
signal shop_closed

func _ready() -> void:
	# Try to find or create SkinSystem
	if not skin_system:
		skin_system = SkinSystem.new()
		add_child(skin_system)
	_selected_skin = skin_system.current_skin_id

func _process(delta: float) -> void:
	_anim_time += delta
	if _message_timer > 0:
		_message_timer -= delta
	queue_redraw()

func _draw() -> void:
	# Full-screen semi-transparent background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.92))

	# Header
	_draw_header()

	# Check if skins are locked behind play count
	if not GameManager.can_unlock_skins():
		_draw_locked_message()

	# Skin cards grid
	_draw_skin_grid()

	# Back button
	_draw_back_button()

	# Toast message
	if _message_timer > 0:
		_draw_toast()

func _draw_header() -> void:
	# Title
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), "SKIN SHOP",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

	# Gold balance
	var gold: int = GameManager.save_data["gold"]
	var gold_text := "Gold: %d" % gold
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 180, 30), gold_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.84, 0.0))

	# Gold coin icon
	draw_circle(Vector2(size.x - 195, 26), 8.0, Color(1.0, 0.84, 0.0))
	draw_circle(Vector2(size.x - 195, 26), 8.0, Color(0.8, 0.65, 0.0), false, 1.5)

	# Separator line
	draw_line(Vector2(10, HEADER_HEIGHT), Vector2(size.x - 10, HEADER_HEIGHT),
			  Color(0.3, 0.4, 0.6, 0.5), 1.0)

func _draw_locked_message() -> void:
	var games: int = GameManager.save_data["games_played"]
	var msg := "Play %d more game(s) to unlock skins!" % (5 - games)
	var msg_y := HEADER_HEIGHT + 20
	draw_rect(Rect2(Vector2(20, msg_y - 4), Vector2(size.x - 40, 28)),
			  Color(0.5, 0.2, 0.1, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(30, msg_y + 14), msg,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.3))

func _draw_skin_grid() -> void:
	var start_y := HEADER_HEIGHT + 50
	if not GameManager.can_unlock_skins():
		start_y += 35

	var total_w := COLUMNS * CARD_WIDTH + (COLUMNS - 1) * CARD_GAP
	var start_x := (size.x - total_w) / 2.0

	for i in range(skin_order.size()):
		var skin_id: String = skin_order[i]
		var col := i % COLUMNS
		var row := i / COLUMNS
		var card_x := start_x + col * (CARD_WIDTH + CARD_GAP)
		var card_y := start_y + row * (CARD_HEIGHT + CARD_GAP)
		_draw_skin_card(skin_id, Vector2(card_x, card_y))

func _draw_skin_card(skin_id: String, pos: Vector2) -> void:
	var skin_data: Dictionary = skin_system.get_skin_data(skin_id)
	var is_unlocked := skin_id == "default" or GameManager.is_skin_unlocked(skin_id)
	var is_equipped := skin_id == skin_system.current_skin_id
	var is_hovered := skin_id == _hovered_card

	# Card background
	var bg_color := Color(0.1, 0.14, 0.22, 0.9)
	if is_equipped:
		bg_color = Color(0.1, 0.25, 0.15, 0.9)
	elif is_hovered:
		bg_color = Color(0.15, 0.18, 0.28, 0.9)

	draw_rect(Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT)), bg_color)

	# Border
	var border_color := Color(0.3, 0.4, 0.5, 0.6)
	if is_equipped:
		border_color = Color(0.2, 0.9, 0.3, 0.8)
	elif is_hovered:
		border_color = Color(0.5, 0.6, 0.8, 0.8)
	draw_rect(Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT)), border_color, false, 2.0)

	# Animated skin preview
	var preview_center := pos + Vector2(CARD_WIDTH / 2, 60)
	_draw_mini_boat_preview(preview_center, skin_id, skin_data, is_unlocked)

	# Skin name
	var name_text: String = skin_data["name"]
	draw_string(ThemeDB.fallback_font,
				pos + Vector2(CARD_WIDTH / 2 - name_text.length() * 3.5, 115),
				name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.5))

	# Status area
	if is_equipped:
		# "EQUIPPED" badge
		var badge_pos := pos + Vector2(CARD_WIDTH / 2 - 32, 135)
		draw_rect(Rect2(badge_pos, Vector2(64, 22)), Color(0.1, 0.7, 0.2, 0.6))
		draw_string(ThemeDB.fallback_font, badge_pos + Vector2(4, 15),
					"EQUIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	elif is_unlocked:
		# "Equip" button
		var btn_pos := pos + Vector2(CARD_WIDTH / 2 - 28, 135)
		var btn_color := Color(0.15, 0.4, 0.7, 0.8) if not is_hovered else Color(0.2, 0.5, 0.9, 0.9)
		draw_rect(Rect2(btn_pos, Vector2(56, 22)), btn_color)
		draw_rect(Rect2(btn_pos, Vector2(56, 22)), Color.WHITE, false, 1.0)
		draw_string(ThemeDB.fallback_font, btn_pos + Vector2(10, 15),
					"Equip", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		# Locked - show cost
		# Lock icon (simple padlock)
		var lock_center := pos + Vector2(CARD_WIDTH / 2, 142)
		draw_rect(Rect2(lock_center + Vector2(-8, -2), Vector2(16, 12)), Color(0.5, 0.5, 0.5, 0.8))
		draw_arc(lock_center + Vector2(0, -2), 6.0, PI, TAU, 8, Color(0.5, 0.5, 0.5, 0.8), 2.0)

		# Cost
		var cost_text := "%d gold" % SkinSystem.SKIN_COST
		draw_string(ThemeDB.fallback_font,
					pos + Vector2(CARD_WIDTH / 2 - cost_text.length() * 3, 170),
					cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.84, 0.0))

		if not GameManager.can_unlock_skins():
			# Extra lock overlay
			draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CARD_WIDTH - 4, CARD_HEIGHT - 4)),
					  Color(0, 0, 0, 0.4))

func _draw_mini_boat_preview(center: Vector2, skin_id: String, skin_data: Dictionary, is_unlocked: bool) -> void:
	# Build mini hull points
	var hull_pts: PackedVector2Array = []
	var rx := 14.0
	var ry := 10.0
	for i in range(16):
		var a := float(i) / 16.0 * TAU
		hull_pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))

	# Hull color (greyed if locked)
	var hull_color: Color = skin_data["base_color"]
	if not is_unlocked:
		hull_color = Color(0.3, 0.3, 0.3, 0.7)

	# Draw hull
	draw_colored_polygon(hull_pts, hull_color)
	draw_polyline(hull_pts, Color(1, 1, 1, 0.4), 1.0, true)

	# Mini cabin
	draw_rect(Rect2(center + Vector2(-4, -6), Vector2(8, 5)), hull_color.lightened(0.15))

	# Mini eyes
	draw_circle(center + Vector2(-3, -1), 2.0, Color.WHITE)
	draw_circle(center + Vector2(3, -1), 2.0, Color.WHITE)
	draw_circle(center + Vector2(-2.5, -1), 1.0, Color.BLACK)
	draw_circle(center + Vector2(3.5, -1), 1.0, Color.BLACK)

	# Skin effect overlay (only if unlocked or for teaser preview)
	if skin_id != "default" and skin_system:
		skin_system.draw_skin_preview(self, center, hull_pts, skin_id, _anim_time)

func _draw_back_button() -> void:
	var btn_pos := Vector2(20, size.y - 50)
	var btn_size := Vector2(80, 32)
	var is_hov := _hovered_card == "_back"
	var bg := Color(0.3, 0.15, 0.15, 0.8) if not is_hov else Color(0.5, 0.2, 0.2, 0.9)
	draw_rect(Rect2(btn_pos, btn_size), bg)
	draw_rect(Rect2(btn_pos, btn_size), Color.WHITE, false, 1.0)
	draw_string(ThemeDB.fallback_font, btn_pos + Vector2(18, 22),
				"Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_toast() -> void:
	var toast_w := _message_text.length() * 7.0 + 20
	var toast_pos := Vector2((size.x - toast_w) / 2.0, size.y - 90)
	var alpha := minf(_message_timer, 1.0)
	draw_rect(Rect2(toast_pos, Vector2(toast_w, 28)),
			  Color(0.1, 0.1, 0.15, 0.9 * alpha))
	draw_rect(Rect2(toast_pos, Vector2(toast_w, 28)),
			  Color(0.5, 0.7, 1.0, 0.5 * alpha), false, 1.0)
	draw_string(ThemeDB.fallback_font, toast_pos + Vector2(10, 19),
				_message_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(1, 1, 1, alpha))

func _show_message(text: String) -> void:
	_message_text = text
	_message_timer = 2.5

# === INPUT HANDLING ===

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_hover(mouse_pos: Vector2) -> void:
	_hovered_card = ""

	# Check back button
	var btn_pos := Vector2(20, size.y - 50)
	if Rect2(btn_pos, Vector2(80, 32)).has_point(mouse_pos):
		_hovered_card = "_back"
		return

	# Check skin cards
	var start_y := HEADER_HEIGHT + 50
	if not GameManager.can_unlock_skins():
		start_y += 35
	var total_w := COLUMNS * CARD_WIDTH + (COLUMNS - 1) * CARD_GAP
	var start_x := (size.x - total_w) / 2.0

	for i in range(skin_order.size()):
		var col := i % COLUMNS
		var row := i / COLUMNS
		var card_x := start_x + col * (CARD_WIDTH + CARD_GAP)
		var card_y := start_y + row * (CARD_HEIGHT + CARD_GAP)
		if Rect2(Vector2(card_x, card_y), Vector2(CARD_WIDTH, CARD_HEIGHT)).has_point(mouse_pos):
			_hovered_card = skin_order[i]
			return

func _handle_click(mouse_pos: Vector2) -> void:
	# Back button
	var btn_pos := Vector2(20, size.y - 50)
	if Rect2(btn_pos, Vector2(80, 32)).has_point(mouse_pos):
		AudioManager.play("select")
		shop_closed.emit()
		return

	# Check skin cards
	var start_y := HEADER_HEIGHT + 50
	if not GameManager.can_unlock_skins():
		start_y += 35
	var total_w := COLUMNS * CARD_WIDTH + (COLUMNS - 1) * CARD_GAP
	var start_x := (size.x - total_w) / 2.0

	for i in range(skin_order.size()):
		var skin_id: String = skin_order[i]
		var col := i % COLUMNS
		var row := i / COLUMNS
		var card_x := start_x + col * (CARD_WIDTH + CARD_GAP)
		var card_y := start_y + row * (CARD_HEIGHT + CARD_GAP)
		if not Rect2(Vector2(card_x, card_y), Vector2(CARD_WIDTH, CARD_HEIGHT)).has_point(mouse_pos):
			continue

		var is_unlocked := skin_id == "default" or GameManager.is_skin_unlocked(skin_id)

		if is_unlocked:
			# Equip this skin
			skin_system.set_skin(skin_id)
			_selected_skin = skin_id
			AudioManager.play("select")
			skin_equipped.emit(skin_id)
			_show_message("Equipped: %s" % skin_system.get_skin_data(skin_id)["name"])
		else:
			# Try to purchase
			if not GameManager.can_unlock_skins():
				_show_message("Play 5 games to unlock skins!")
				AudioManager.play("hurt")
			elif GameManager.save_data["gold"] < SkinSystem.SKIN_COST:
				_show_message("Not enough gold! Need %d" % SkinSystem.SKIN_COST)
				AudioManager.play("hurt")
			else:
				if skin_system.purchase_skin(skin_id):
					AudioManager.play("chest")
					_show_message("Unlocked: %s!" % skin_system.get_skin_data(skin_id)["name"])
				else:
					AudioManager.play("hurt")
					_show_message("Could not unlock skin")
		return
