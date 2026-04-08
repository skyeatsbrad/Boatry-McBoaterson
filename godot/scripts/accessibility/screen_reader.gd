extends Node

## Screen reader support (autoload). Uses DisplayServer TTS when available,
## falls back to a visual text popup in the top-left corner.

var enabled := false:
	set(value):
		enabled = value
		_save_setting()

var _tts_available := false
var _popup_label: Label
var _popup_timer := 0.0
const POPUP_DURATION := 3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tts_available = DisplayServer.tts_get_voices().size() > 0
	_load_setting()
	_create_fallback_label()

func _process(delta: float) -> void:
	if _popup_label and _popup_label.visible:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup_label.visible = false

## Speak text via TTS or show it visually.
func speak(text: String) -> void:
	if not enabled or text.is_empty():
		return

	if _tts_available:
		# Stop any current speech then speak new text
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, DisplayServer.tts_get_voices()[0])
	else:
		_show_popup(text)

## Announce a focused UI element. Call when focus changes.
func announce_focus(control: Control) -> void:
	if not enabled or not is_instance_valid(control):
		return

	var text := _describe_control(control)
	if not text.is_empty():
		speak(text)

## Connect to a container's children so focus changes are announced automatically.
func watch_container(container: Control) -> void:
	if not enabled:
		return
	for child in container.get_children():
		if child is Control:
			if not child.focus_entered.is_connected(_on_child_focused.bind(child)):
				child.focus_entered.connect(_on_child_focused.bind(child))

# --- Internals ---

func _describe_control(control: Control) -> String:
	if control is Button:
		var btn := control as Button
		var label := btn.text if not btn.text.is_empty() else btn.tooltip_text
		if btn.disabled:
			return label + ", disabled"
		return label + ", button"

	if control is HSlider or control is VSlider:
		var slider := control as Range
		return "%s, slider, value %d" % [control.name.to_snake_case().replace("_", " "), int(slider.value)]

	if control is Label:
		return (control as Label).text

	if control is CheckBox or control is CheckButton:
		var cb := control as BaseButton
		var state := "checked" if cb.button_pressed else "unchecked"
		return "%s, %s" % [control.name.to_snake_case().replace("_", " "), state]

	# Generic fallback
	if not control.tooltip_text.is_empty():
		return control.tooltip_text
	if "text" in control and not (control.get("text") as String).is_empty():
		return control.get("text") as String
	return control.name.to_snake_case().replace("_", " ")

func _on_child_focused(control: Control) -> void:
	announce_focus(control)

func _create_fallback_label() -> void:
	_popup_label = Label.new()
	_popup_label.name = "ScreenReaderPopup"
	_popup_label.visible = false
	_popup_label.position = Vector2(10, 10)
	_popup_label.size = Vector2(400, 40)
	_popup_label.add_theme_font_size_override("font_size", 18)
	_popup_label.add_theme_color_override("font_color", Color.WHITE)
	_popup_label.modulate.a = 0.9

	# Wrap in a CanvasLayer so it's always on top
	var canvas := CanvasLayer.new()
	canvas.name = "ScreenReaderLayer"
	canvas.layer = 100
	canvas.add_child(_popup_label)
	add_child(canvas)

func _show_popup(text: String) -> void:
	if _popup_label:
		_popup_label.text = text
		_popup_label.visible = true
		_popup_timer = POPUP_DURATION

func _load_setting() -> void:
	if GameManager.save_data["settings"].has("screen_reader"):
		enabled = GameManager.save_data["settings"]["screen_reader"]

func _save_setting() -> void:
	GameManager.save_data["settings"]["screen_reader"] = enabled
	GameManager.save_game()
