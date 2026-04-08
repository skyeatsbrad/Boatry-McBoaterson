extends Control

# Pause menu overlay

@onready var resume_btn: Button = $PanelContainer/VBox/ResumeButton
@onready var quit_btn: Button = $PanelContainer/VBox/QuitToMenuButton
@onready var title_label: Label = $PanelContainer/VBox/TitleLabel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_btn.pressed.connect(_on_resume)
	quit_btn.pressed.connect(_on_quit_to_menu)
	title_label.text = "PAUSED"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if visible:
		_on_resume()
	else:
		visible = true
		get_tree().paused = true
		AudioManager.play("select")

func _on_resume() -> void:
	visible = false
	get_tree().paused = false

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
