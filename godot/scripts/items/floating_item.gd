extends StaticBody2D

# Destroyable floating items: crates, barrels, buoys
# Drop bonus XP gems, gold, or special power-ups when destroyed

signal destroyed(item: Node2D)

enum ItemType { CRATE, BARREL, BUOY }

@export var item_type := ItemType.CRATE
@export var max_hp := 15
var hp := 15
var anim_timer := 0.0
var bob_offset := 0.0

var drop_table := {
	"bonus_xp": 0.4,
	"gold": 0.35,
	"powerup": 0.15,
	"health": 0.1,
}

func _ready() -> void:
	hp = max_hp
	bob_offset = randf() * TAU
	anim_timer = bob_offset

func _process(delta: float) -> void:
	anim_timer += delta * 2.0
	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		_drop_loot()
		AudioManager.play("splash")
		destroyed.emit(self)
		queue_free()

func _drop_loot() -> void:
	var roll := randf()
	var cumulative := 0.0
	var _drop := "bonus_xp"
	for key in drop_table:
		cumulative += drop_table[key]
		if roll <= cumulative:
			_drop = key
			break
	# Loot spawning handled by parent/game_world

func _draw() -> void:
	var bob := sin(anim_timer) * 3.0
	var rot := sin(anim_timer * 0.3) * 0.1  # gentle rotation
	
	match item_type:
		ItemType.CRATE:
			_draw_crate(bob, rot)
		ItemType.BARREL:
			_draw_barrel(bob, rot)
		ItemType.BUOY:
			_draw_buoy(bob, rot)
	
	# HP indicator (cracks)
	if hp < max_hp:
		var ratio := float(hp) / max_hp
		if ratio < 0.5:
			draw_line(Vector2(-5, bob - 5), Vector2(3, bob + 3), Color(0.3, 0.2, 0.1), 1.5)
		if ratio < 0.3:
			draw_line(Vector2(4, bob - 4), Vector2(-2, bob + 5), Color(0.3, 0.2, 0.1), 1.5)

func _draw_crate(bob: float, rot: float) -> void:
	var size := Vector2(18, 16)
	draw_set_transform(Vector2(0, bob), rot)
	draw_rect(Rect2(-size / 2, size), Color(0.55, 0.35, 0.15))
	draw_rect(Rect2(-size / 2, size), Color(0.4, 0.25, 0.1), false, 2.0)
	# Cross boards
	draw_line(Vector2(-size.x/2, -size.y/2), Vector2(size.x/2, size.y/2),
			  Color(0.45, 0.28, 0.12), 1.5)
	draw_line(Vector2(size.x/2, -size.y/2), Vector2(-size.x/2, size.y/2),
			  Color(0.45, 0.28, 0.12), 1.5)
	draw_set_transform(Vector2.ZERO)

func _draw_barrel(bob: float, rot: float) -> void:
	draw_set_transform(Vector2(0, bob), rot)
	# Barrel body
	draw_circle(Vector2.ZERO, 10.0, Color(0.5, 0.3, 0.15))
	draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.2, 0.1), false, 2.0)
	# Metal bands
	draw_arc(Vector2.ZERO, 7.0, 0, TAU, 16, Color(0.5, 0.5, 0.5), 1.5)
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(0.5, 0.5, 0.5), 1.5)
	draw_set_transform(Vector2.ZERO)

func _draw_buoy(bob: float, _rot: float) -> void:
	# Red and white striped buoy
	draw_circle(Vector2(0, bob), 8.0, Color.RED)
	draw_circle(Vector2(0, bob), 5.0, Color.WHITE)
	draw_circle(Vector2(0, bob), 8.0, Color.BLACK, false, 1.5)
	# Antenna
	draw_line(Vector2(0, bob - 8), Vector2(0, bob - 16), Color(0.4, 0.4, 0.4), 2.0)
	# Blinking light
	if int(anim_timer * 2) % 2 == 0:
		draw_circle(Vector2(0, bob - 16), 2.0, Color.YELLOW)
