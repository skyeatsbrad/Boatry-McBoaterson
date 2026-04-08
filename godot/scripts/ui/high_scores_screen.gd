extends Control

# High scores / leaderboard – top 10 runs

@onready var list_container: VBoxContainer = $VBoxContainer/ScrollContainer/ListContainer
@onready var totals_label: Label = $VBoxContainer/TotalsLabel
@onready var back_btn: Button = $VBoxContainer/BackButton

const GOLD_COLOR := Color(1.0, 0.84, 0.0)
const SILVER_COLOR := Color.WHITE
const GRAY_COLOR := Color(0.55, 0.55, 0.55)

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_build_list()

func _build_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	# Header row
	var header := _make_row("#", "Character", "Kills", "Wave", "Level", "Time", Color(0.7, 0.7, 0.7))
	list_container.add_child(header)

	var scores: Array = GameManager.save_data["high_scores"]
	for i in range(mini(scores.size(), 10)):
		var entry: Dictionary = scores[i]
		var color: Color
		if i == 0:
			color = GOLD_COLOR
		elif i <= 2:
			color = SILVER_COLOR
		else:
			color = GRAY_COLOR

		var rank := str(i + 1)
		var char_name: String = entry.get("character", "—")
		var kills := str(entry.get("kills", 0))
		var wave := str(entry.get("wave", 0))
		var level := str(entry.get("level", 0))
		var time_str: String = entry.get("time", "00:00")

		var row := _make_row(rank, char_name, kills, wave, level, time_str, color)
		list_container.add_child(row)

	if scores.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No runs recorded yet. Go play!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)

	# Totals
	var total_runs: int = GameManager.save_data.get("total_runs", 0)
	var total_kills: int = GameManager.save_data.get("total_kills", 0)
	totals_label.text = "Total Runs: %d  |  Total Kills: %d" % [total_runs, total_kills]

func _make_row(rank: String, char_name: String, kills: String, wave: String,
			   level: String, time_str: String, color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var cols := [
		{"text": rank,      "width": 40},
		{"text": char_name, "width": 120},
		{"text": kills,     "width": 80},
		{"text": wave,      "width": 60},
		{"text": level,     "width": 60},
		{"text": time_str,  "width": 70},
	]
	for col in cols:
		var lbl := Label.new()
		lbl.text = col["text"]
		lbl.custom_minimum_size.x = col["width"]
		lbl.add_theme_color_override("font_color", color)
		hbox.add_child(lbl)

	return hbox

func _on_back() -> void:
	AudioManager.play("select")
	visible = false
