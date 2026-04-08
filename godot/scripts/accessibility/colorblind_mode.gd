extends Node

## Colorblind support (autoload). When enabled, provides shape symbols and text
## overlays so players can identify game elements without relying on color alone.

var enabled := false:
	set(value):
		enabled = value
		_save_setting()

# Shape symbol lookup — Unicode characters drawn on top of enemies
const ENEMY_SYMBOLS := {
	"piranha":    "▲",  # triangle
	"pufferfish": "●",  # circle
	"swordfish":  "➤",  # arrow
	"jellyfish":  "〰", # wave
	"eel":        "⚡",  # zigzag
	"anglerfish": "◆",  # diamond
	"shark":      "■",  # square
}

func _ready() -> void:
	_load_setting()

## Returns the symbol character for the given enemy type.
func get_symbol(enemy_type: String) -> String:
	return ENEMY_SYMBOLS.get(enemy_type, "?")

## Whether draw routines should render accessibility symbols.
func should_draw_symbols() -> bool:
	return enabled

## Draw the enemy symbol centered at a position.
## Call from an enemy's _draw() method: ColorblindMode.draw_enemy_symbol(self, fish_type, offset)
func draw_enemy_symbol(canvas: CanvasItem, enemy_type: String, offset := Vector2.ZERO) -> void:
	if not enabled:
		return
	var sym := get_symbol(enemy_type)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, offset + Vector2(-6, -14), sym,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

## Draw HP percentage text centered on an HP bar.
## Call from an enemy or player _draw(): ColorblindMode.draw_hp_text(self, hp, max_hp, bar_pos)
func draw_hp_text(canvas: CanvasItem, hp: int, max_hp: int, bar_center: Vector2) -> void:
	if not enabled or max_hp <= 0:
		return
	var pct := int(float(hp) / float(max_hp) * 100.0)
	var text := "%d%%" % pct
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, bar_center + Vector2(-10, 3), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

## Draw "XP" label on gem pickups.
func draw_gem_label(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, offset + Vector2(-8, -8), "XP",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

## Draw "+" label on health pickups.
func draw_health_label(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, offset + Vector2(-5, -8), "+",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _load_setting() -> void:
	if GameManager.save_data["settings"].has("colorblind_mode"):
		enabled = GameManager.save_data["settings"]["colorblind_mode"]

func _save_setting() -> void:
	GameManager.save_data["settings"]["colorblind_mode"] = enabled
	GameManager.save_game()
