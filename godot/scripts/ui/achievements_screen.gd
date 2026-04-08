extends Control

# Achievement viewer – lists all 16 achievements with unlock status

@onready var count_label: Label = $VBoxContainer/CountLabel
@onready var list_container: VBoxContainer = $VBoxContainer/ScrollContainer/ListContainer
@onready var back_btn: Button = $VBoxContainer/BackButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_build_list()

func _build_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var unlocked_ids: Array = GameManager.save_data["achievements"]
	var total := AchievementManager.ACHIEVEMENTS.size()
	var unlocked_count := 0

	for ach in AchievementManager.ACHIEVEMENTS:
		var is_unlocked: bool = ach["id"] in unlocked_ids
		if is_unlocked:
			unlocked_count += 1

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var icon := Label.new()
		icon.custom_minimum_size.x = 30
		if is_unlocked:
			icon.text = "✓"
			icon.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		else:
			icon.text = "✗"
			icon.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = ach["name"]
		name_lbl.custom_minimum_size.x = 180
		if is_unlocked:
			name_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = ach["desc"]
		if not is_unlocked:
			desc_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		hbox.add_child(desc_lbl)

		list_container.add_child(hbox)

	count_label.text = "%d/%d unlocked" % [unlocked_count, total]

func _on_back() -> void:
	AudioManager.play("select")
	visible = false
