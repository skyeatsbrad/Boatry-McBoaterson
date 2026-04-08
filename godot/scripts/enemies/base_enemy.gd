extends CharacterBody2D
class_name BaseEnemy

# Base class for all fish enemies with object pool support

signal killed(enemy: BaseEnemy)

@export var max_hp := 30
@export var speed := 80.0
@export var damage := 10
@export var xp_value := 5
@export var gold_value := 1
@export var drop_chance := 0.05
@export var enemy_color := Color.RED
@export var is_boss := false

var hp := 30
var hit_flash_timer := 0.0
var anim_timer := 0.0
var active := false

# Fish types: piranha, pufferfish, swordfish, jellyfish, eel, anglerfish, shark, kraken
var fish_type := "piranha"

# Pool support
func activate(pos: Vector2, wave: int, type: String = "") -> void:
	position = pos
	active = true
	visible = true
	fish_type = type if type != "" else _random_type(wave)
	_apply_type_stats(wave)
	hp = max_hp
	hit_flash_timer = 0.0
	anim_timer = randf() * TAU

func deactivate() -> void:
	active = false
	visible = false
	position = Vector2(-9999, -9999)

func _random_type(wave: int) -> String:
	var roll := randf()
	if wave >= 5 and roll < 0.05:
		return "anglerfish"
	elif wave >= 4 and roll < 0.12:
		return "shark"
	elif wave >= 3 and roll < 0.20:
		return "eel"
	elif wave >= 2 and roll < 0.30:
		return "jellyfish"
	elif wave >= 2 and roll < 0.40:
		return "swordfish"
	elif roll < 0.55:
		return "pufferfish"
	else:
		return "piranha"

func _apply_type_stats(wave: int) -> void:
	var scale := 1.0 + wave * 0.15
	match fish_type:
		"piranha":
			max_hp = int(30 * scale)
			speed = 90.0 + wave * 3.0
			damage = 10 + wave * 2
			xp_value = 5 + wave
			gold_value = 1
			enemy_color = Color(0.86, 0.16, 0.16)
		"pufferfish":
			max_hp = int(20 * scale)
			speed = 60.0
			damage = 8 + wave
			xp_value = 8 + wave
			gold_value = 2
			enemy_color = Color(1.0, 0.75, 0.3)
			drop_chance = 0.1  # explodes on death
		"swordfish":
			max_hp = int(25 * scale)
			speed = 150.0 + wave * 5.0
			damage = 18 + wave * 3
			xp_value = 10 + wave
			gold_value = 2
			enemy_color = Color(0.4, 0.6, 0.9)
		"jellyfish":
			max_hp = int(20 * scale)
			speed = 50.0
			damage = 5 + wave
			xp_value = 7 + wave
			gold_value = 1
			enemy_color = Color(0.7, 0.3, 0.9)  # slows on hit
		"eel":
			max_hp = int(35 * scale)
			speed = 100.0 + wave * 3.0
			damage = 12 + wave * 2
			xp_value = 12 + wave
			gold_value = 3
			enemy_color = Color(0.2, 0.8, 0.8)  # chain damage
		"anglerfish":
			max_hp = int(40 * scale)
			speed = 45.0
			damage = 15 + wave * 2
			xp_value = 15 + wave
			gold_value = 4
			enemy_color = Color(0.3, 0.3, 0.5)  # lures with fake gem
		"shark":
			max_hp = int(80 * scale)
			speed = 70.0 + wave * 2.0
			damage = 25 + wave * 3
			xp_value = 20 + wave * 2
			gold_value = 5
			enemy_color = Color(0.5, 0.5, 0.6)
			drop_chance = 0.15

func _physics_process(delta: float) -> void:
	if not active:
		return
	anim_timer += delta * 4.0
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
	
	# Move toward player (get_tree assumed to find player)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var target: Vector2 = players[0].position
		var dir := (target - position).normalized()
		
		# Swordfish charges in bursts
		if fish_type == "swordfish" and int(anim_timer) % 6 < 2:
			velocity = dir * speed * 2.0
		else:
			velocity = dir * speed
		
		move_and_slide()
	
	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	hit_flash_timer = 0.1
	if hp <= 0:
		killed.emit(self)
		GameManager.add_combo()
		deactivate()

func _draw() -> void:
	if not active:
		return
	var bob := sin(anim_timer) * 2.0
	var c := Color.WHITE if hit_flash_timer > 0 else enemy_color
	
	match fish_type:
		"piranha":
			_draw_piranha(bob, c)
		"pufferfish":
			_draw_pufferfish(bob, c)
		"swordfish":
			_draw_swordfish(bob, c)
		"jellyfish":
			_draw_jellyfish(bob, c)
		"eel":
			_draw_eel(bob, c)
		"anglerfish":
			_draw_anglerfish(bob, c)
		"shark":
			_draw_shark(bob, c)
		_:
			_draw_piranha(bob, c)
	
	# HP bar
	if hp < max_hp:
		var bw := 20.0
		draw_rect(Rect2(Vector2(-bw/2, -18), Vector2(bw, 3)), Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(Vector2(-bw/2, -18), Vector2(bw * float(hp) / max_hp, 3)), Color.RED)

func _draw_piranha(bob: float, c: Color) -> void:
	# Small aggressive fish
	draw_circle(Vector2(0, bob), 10.0, c)
	draw_circle(Vector2(0, bob), 10.0, Color.BLACK, false, 1.5)
	# Tail
	draw_line(Vector2(-10, bob), Vector2(-16, bob - 5), c, 2.0)
	draw_line(Vector2(-10, bob), Vector2(-16, bob + 5), c, 2.0)
	# Eye
	draw_circle(Vector2(4, bob - 2), 2.5, Color.YELLOW)
	draw_circle(Vector2(4, bob - 2), 1.0, Color.BLACK)
	# Teeth
	draw_line(Vector2(8, bob + 1), Vector2(10, bob + 4), Color.WHITE, 1.5)
	draw_line(Vector2(6, bob + 1), Vector2(7, bob + 4), Color.WHITE, 1.5)

func _draw_pufferfish(bob: float, c: Color) -> void:
	var puff := sin(anim_timer * 0.5) * 3.0 + 14.0
	draw_circle(Vector2(0, bob), puff, c)
	# Spikes
	for i in range(8):
		var a := float(i) / 8.0 * TAU + anim_timer * 0.3
		var tip := Vector2(cos(a), sin(a)) * (puff + 5) + Vector2(0, bob)
		var base_pt := Vector2(cos(a), sin(a)) * puff + Vector2(0, bob)
		draw_line(base_pt, tip, c.darkened(0.3), 2.0)
	draw_circle(Vector2(3, bob - 3), 3.0, Color.WHITE)
	draw_circle(Vector2(3, bob - 3), 1.5, Color.BLACK)

func _draw_swordfish(bob: float, c: Color) -> void:
	draw_circle(Vector2(0, bob), 11.0, c)
	# Sword nose
	draw_line(Vector2(11, bob), Vector2(25, bob), c.lightened(0.3), 3.0)
	draw_line(Vector2(11, bob), Vector2(25, bob), Color.WHITE, 1.0)
	# Tail
	draw_line(Vector2(-11, bob), Vector2(-18, bob - 6), c, 2.5)
	draw_line(Vector2(-11, bob), Vector2(-18, bob + 6), c, 2.5)
	draw_circle(Vector2(4, bob - 3), 2.5, Color.WHITE)
	draw_circle(Vector2(4, bob - 3), 1.0, Color.BLACK)

func _draw_jellyfish(bob: float, c: Color) -> void:
	# Dome
	draw_arc(Vector2(0, bob), 12.0, PI, TAU, 16, c, 3.0)
	draw_circle(Vector2(0, bob - 2), 10.0, Color(c.r, c.g, c.b, 0.5))
	# Tentacles
	for i in range(5):
		var x := -8.0 + i * 4.0
		var wave_y := sin(anim_timer + i) * 4.0
		draw_line(Vector2(x, bob + 5), Vector2(x, bob + 18 + wave_y),
				  Color(c.r, c.g, c.b, 0.6), 1.5)
	draw_circle(Vector2(-3, bob - 3), 2.0, Color.WHITE)
	draw_circle(Vector2(3, bob - 3), 2.0, Color.WHITE)

func _draw_eel(bob: float, c: Color) -> void:
	# Wavy body
	var pts: PackedVector2Array = []
	for i in range(8):
		var t := float(i) / 7.0
		var x := lerpf(-15.0, 15.0, t)
		var y := sin(anim_timer + t * 4.0) * 4.0 + bob
		pts.append(Vector2(x, y))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], c, 5.0)
	# Electric sparks
	if int(anim_timer * 3) % 2 == 0:
		draw_line(pts[2] + Vector2(0, -5), pts[2] + Vector2(3, -10), Color.CYAN, 1.5)
	draw_circle(pts[7], 4.0, c)
	draw_circle(pts[7] + Vector2(2, -1), 1.5, Color.YELLOW)

func _draw_anglerfish(bob: float, c: Color) -> void:
	draw_circle(Vector2(0, bob), 14.0, c)
	# Lure
	var lure_glow := (sin(anim_timer * 2.0) + 1.0) / 2.0
	draw_line(Vector2(0, bob - 14), Vector2(5, bob - 25), c.lightened(0.3), 1.5)
	draw_circle(Vector2(5, bob - 25), 4.0, Color(0.2, 1.0, 0.2, lure_glow))
	# Big mouth
	draw_arc(Vector2(5, bob + 4), 8.0, 0, PI, 8, Color.BLACK, 2.0)
	# Teeth
	for i in range(4):
		var tx := 1.0 + i * 3.0
		draw_line(Vector2(tx, bob + 2), Vector2(tx, bob + 6), Color.WHITE, 1.5)
	draw_circle(Vector2(6, bob - 4), 3.0, Color.YELLOW)
	draw_circle(Vector2(6, bob - 4), 1.5, Color.RED)

func _draw_shark(bob: float, c: Color) -> void:
	# Large body
	draw_circle(Vector2(0, bob), 16.0, c)
	draw_circle(Vector2(0, bob), 16.0, Color.BLACK, false, 2.0)
	# Dorsal fin
	var fin_pts: PackedVector2Array = [
		Vector2(0, bob - 16), Vector2(-8, bob - 28), Vector2(6, bob - 16)]
	draw_colored_polygon(fin_pts, c.darkened(0.2))
	# Tail
	draw_line(Vector2(-16, bob), Vector2(-24, bob - 8), c, 3.0)
	draw_line(Vector2(-16, bob), Vector2(-24, bob + 8), c, 3.0)
	# Eye
	draw_circle(Vector2(8, bob - 4), 3.0, Color.WHITE)
	draw_circle(Vector2(8, bob - 4), 1.5, Color.BLACK)
	# Teeth
	draw_line(Vector2(14, bob + 3), Vector2(16, bob + 7), Color.WHITE, 2.0)
	draw_line(Vector2(11, bob + 4), Vector2(12, bob + 8), Color.WHITE, 2.0)
