"""
Vampire Survivors-style game built with Pygame.
Move to dodge enemies, auto-attack nearby foes, collect XP gems,
and choose power-ups on level-up to survive endless waves.
"""

import pygame
import sys
import math
import random
import time

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCREEN_W, SCREEN_H = 960, 720
FPS = 60
FONT_NAME = None  # default system font

# Colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (220, 40, 40)
GREEN = (50, 200, 50)
BLUE = (60, 120, 220)
YELLOW = (255, 220, 40)
PURPLE = (160, 60, 220)
CYAN = (60, 220, 220)
ORANGE = (240, 150, 30)
DARK_GRAY = (30, 30, 40)
GRAY = (80, 80, 100)
LIGHT_GRAY = (160, 160, 180)
DARK_RED = (100, 15, 15)
GOLD = (255, 200, 50)

# World / camera
WORLD_W, WORLD_H = 3000, 3000
TILE_SIZE = 64

# Player
PLAYER_RADIUS = 16
PLAYER_SPEED = 3.0
PLAYER_BASE_HP = 100
INVULN_TIME = 0.3  # seconds of invulnerability after hit

# Projectile (auto-attack)
PROJ_SPEED = 7
PROJ_RADIUS = 5
PROJ_DAMAGE = 20
PROJ_LIFETIME = 60  # frames
PROJ_COOLDOWN = 30  # frames between shots

# Enemies
ENEMY_RADIUS = 14
ENEMY_BASE_SPEED = 1.2
ENEMY_BASE_HP = 30
ENEMY_DAMAGE = 10
SPAWN_DIST_MIN = 400
SPAWN_DIST_MAX = 600

# XP gems
GEM_RADIUS = 6
GEM_ATTRACT_DIST = 100
GEM_ATTRACT_SPEED = 5

# Waves
INITIAL_SPAWN_RATE = 90  # frames between spawns
MIN_SPAWN_RATE = 15
WAVE_DURATION = 30  # seconds per wave


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def angle_to(a, b):
    return math.atan2(b[1] - a[1], b[0] - a[0])


def clamp(val, lo, hi):
    return max(lo, min(hi, val))


def draw_bar(surface, x, y, w, h, ratio, color, bg=GRAY):
    pygame.draw.rect(surface, bg, (x, y, w, h))
    pygame.draw.rect(surface, color, (x, y, int(w * clamp(ratio, 0, 1)), h))
    pygame.draw.rect(surface, WHITE, (x, y, w, h), 1)


def draw_text(surface, text, size, x, y, color=WHITE, center=False):
    font = pygame.font.Font(FONT_NAME, size)
    img = font.render(str(text), True, color)
    rect = img.get_rect(center=(x, y)) if center else img.get_rect(topleft=(x, y))
    surface.draw.blit(img, rect) if False else surface.blit(img, rect)


# ---------------------------------------------------------------------------
# Entity classes
# ---------------------------------------------------------------------------
class Player:
    def __init__(self):
        self.x = WORLD_W / 2
        self.y = WORLD_H / 2
        self.radius = PLAYER_RADIUS
        self.max_hp = PLAYER_BASE_HP
        self.hp = self.max_hp
        self.speed = PLAYER_SPEED
        self.xp = 0
        self.level = 1
        self.xp_to_next = 20
        self.proj_damage = PROJ_DAMAGE
        self.proj_speed = PROJ_SPEED
        self.proj_count = 1
        self.proj_cooldown = PROJ_COOLDOWN
        self.cooldown_timer = 0
        self.invuln_timer = 0
        self.kills = 0

        # Orbital blade
        self.has_orbit = False
        self.orbit_count = 3
        self.orbit_radius = 70
        self.orbit_damage = 15
        self.orbit_angle = 0.0
        self.orbit_speed = 0.05

        # Aura
        self.has_aura = False
        self.aura_radius = 80
        self.aura_damage = 5
        self.aura_tick = 0

    def gain_xp(self, amount):
        self.xp += amount
        while self.xp >= self.xp_to_next:
            self.xp -= self.xp_to_next
            self.level += 1
            self.xp_to_next = int(self.xp_to_next * 1.4)
            return True
        return False

    def update(self, keys, dt_frames):
        dx = dy = 0
        if keys[pygame.K_w] or keys[pygame.K_UP]:
            dy -= 1
        if keys[pygame.K_s] or keys[pygame.K_DOWN]:
            dy += 1
        if keys[pygame.K_a] or keys[pygame.K_LEFT]:
            dx -= 1
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
            dx += 1
        if dx or dy:
            mag = math.hypot(dx, dy)
            self.x += dx / mag * self.speed
            self.y += dy / mag * self.speed
        self.x = clamp(self.x, self.radius, WORLD_W - self.radius)
        self.y = clamp(self.y, self.radius, WORLD_H - self.radius)

        if self.invuln_timer > 0:
            self.invuln_timer -= 1 / FPS

        if self.cooldown_timer > 0:
            self.cooldown_timer -= 1

        # Orbit
        if self.has_orbit:
            self.orbit_angle += self.orbit_speed

        # Aura tick
        if self.has_aura:
            self.aura_tick += 1

    def draw(self, surface, cam_x, cam_y):
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)

        # Aura glow
        if self.has_aura:
            aura_surf = pygame.Surface((self.aura_radius * 2, self.aura_radius * 2), pygame.SRCALPHA)
            pulse = int(40 + 20 * math.sin(time.time() * 4))
            pygame.draw.circle(aura_surf, (100, 200, 255, pulse), (self.aura_radius, self.aura_radius), self.aura_radius)
            surface.blit(aura_surf, (sx - self.aura_radius, sy - self.aura_radius))

        # Orbital blades
        if self.has_orbit:
            for i in range(self.orbit_count):
                a = self.orbit_angle + (2 * math.pi * i / self.orbit_count)
                ox = sx + math.cos(a) * self.orbit_radius
                oy = sy + math.sin(a) * self.orbit_radius
                pygame.draw.circle(surface, CYAN, (int(ox), int(oy)), 6)
                pygame.draw.circle(surface, WHITE, (int(ox), int(oy)), 6, 1)

        # Player body
        blink = self.invuln_timer > 0 and int(self.invuln_timer * 10) % 2
        if not blink:
            pygame.draw.circle(surface, BLUE, (sx, sy), self.radius)
            pygame.draw.circle(surface, WHITE, (sx, sy), self.radius, 2)
            # Eyes
            pygame.draw.circle(surface, WHITE, (sx - 5, sy - 4), 4)
            pygame.draw.circle(surface, WHITE, (sx + 5, sy - 4), 4)
            pygame.draw.circle(surface, BLACK, (sx - 4, sy - 4), 2)
            pygame.draw.circle(surface, BLACK, (sx + 6, sy - 4), 2)


class Enemy:
    def __init__(self, x, y, wave):
        self.x = x
        self.y = y
        self.radius = ENEMY_RADIUS + random.randint(-2, 4)
        scale = 1 + wave * 0.15
        self.max_hp = int(ENEMY_BASE_HP * scale)
        self.hp = self.max_hp
        self.speed = ENEMY_BASE_SPEED + random.uniform(-0.2, 0.3) + wave * 0.05
        self.damage = ENEMY_DAMAGE + wave * 2
        self.xp_value = 5 + wave
        self.hit_flash = 0
        variant = random.random()
        if variant < 0.15 and wave >= 2:
            # Tank enemy
            self.max_hp = int(self.max_hp * 2.5)
            self.hp = self.max_hp
            self.speed *= 0.6
            self.radius += 6
            self.xp_value *= 3
            self.color = PURPLE
            self.damage = int(self.damage * 1.5)
        elif variant < 0.3 and wave >= 1:
            # Fast enemy
            self.speed *= 1.8
            self.max_hp = int(self.max_hp * 0.6)
            self.hp = self.max_hp
            self.color = ORANGE
        else:
            self.color = RED

    def update(self, px, py):
        a = angle_to((self.x, self.y), (px, py))
        self.x += math.cos(a) * self.speed
        self.y += math.sin(a) * self.speed
        if self.hit_flash > 0:
            self.hit_flash -= 1

    def draw(self, surface, cam_x, cam_y):
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)
        color = WHITE if self.hit_flash > 0 else self.color
        pygame.draw.circle(surface, color, (sx, sy), self.radius)
        pygame.draw.circle(surface, (0, 0, 0), (sx, sy), self.radius, 2)
        # Angry eyes
        pygame.draw.circle(surface, YELLOW, (sx - 4, sy - 3), 3)
        pygame.draw.circle(surface, YELLOW, (sx + 4, sy - 3), 3)
        pygame.draw.circle(surface, BLACK, (sx - 4, sy - 3), 1)
        pygame.draw.circle(surface, BLACK, (sx + 4, sy - 3), 1)
        # HP bar
        if self.hp < self.max_hp:
            bw = self.radius * 2
            draw_bar(surface, sx - self.radius, sy - self.radius - 8, bw, 4,
                     self.hp / self.max_hp, RED)


class Projectile:
    def __init__(self, x, y, angle, speed, damage, color=YELLOW):
        self.x = x
        self.y = y
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed
        self.radius = PROJ_RADIUS
        self.damage = damage
        self.life = PROJ_LIFETIME
        self.color = color

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.life -= 1

    def draw(self, surface, cam_x, cam_y):
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)
        pygame.draw.circle(surface, self.color, (sx, sy), self.radius)
        pygame.draw.circle(surface, WHITE, (sx, sy), self.radius, 1)


class Gem:
    def __init__(self, x, y, value=5):
        self.x = x
        self.y = y
        self.radius = GEM_RADIUS
        self.value = value

    def update(self, px, py):
        d = dist((self.x, self.y), (px, py))
        if d < GEM_ATTRACT_DIST:
            a = angle_to((self.x, self.y), (px, py))
            speed = GEM_ATTRACT_SPEED * (1 - d / GEM_ATTRACT_DIST) + 1
            self.x += math.cos(a) * speed
            self.y += math.sin(a) * speed

    def draw(self, surface, cam_x, cam_y):
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)
        pygame.draw.polygon(surface, GREEN, [
            (sx, sy - self.radius),
            (sx + self.radius, sy),
            (sx, sy + self.radius),
            (sx - self.radius, sy),
        ])
        pygame.draw.polygon(surface, WHITE, [
            (sx, sy - self.radius),
            (sx + self.radius, sy),
            (sx, sy + self.radius),
            (sx - self.radius, sy),
        ], 1)


class DamageNumber:
    def __init__(self, x, y, value, color=WHITE):
        self.x = x
        self.y = y
        self.value = value
        self.color = color
        self.timer = 30
        self.vy = -1.5

    def update(self):
        self.y += self.vy
        self.vy *= 0.95
        self.timer -= 1

    def draw(self, surface, cam_x, cam_y):
        alpha = clamp(self.timer / 30, 0, 1)
        color = tuple(int(c * alpha) for c in self.color)
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)
        draw_text(surface, str(self.value), 16, sx, sy, color, center=True)


# ---------------------------------------------------------------------------
# Power-up definitions
# ---------------------------------------------------------------------------
POWERUPS = [
    {"name": "Damage Up", "desc": "+30% projectile damage", "color": RED,
     "apply": lambda p: setattr(p, 'proj_damage', int(p.proj_damage * 1.3))},
    {"name": "Speed Up", "desc": "+15% movement speed", "color": CYAN,
     "apply": lambda p: setattr(p, 'speed', p.speed * 1.15)},
    {"name": "Multi-Shot", "desc": "+1 projectile per volley", "color": ORANGE,
     "apply": lambda p: setattr(p, 'proj_count', p.proj_count + 1)},
    {"name": "Fire Rate", "desc": "Shoot 25% faster", "color": YELLOW,
     "apply": lambda p: setattr(p, 'proj_cooldown', max(5, int(p.proj_cooldown * 0.75)))},
    {"name": "Max HP Up", "desc": "+30 max HP and heal", "color": GREEN,
     "apply": lambda p: (setattr(p, 'max_hp', p.max_hp + 30), setattr(p, 'hp', p.max_hp + 30))},
    {"name": "Orbital Blades", "desc": "Spinning blades orbit you", "color": CYAN,
     "apply": lambda p: setattr(p, 'has_orbit', True),
     "condition": lambda p: not p.has_orbit},
    {"name": "Orbit+", "desc": "+2 orbital blades, wider radius", "color": CYAN,
     "apply": lambda p: (setattr(p, 'orbit_count', p.orbit_count + 2),
                         setattr(p, 'orbit_radius', p.orbit_radius + 15)),
     "condition": lambda p: p.has_orbit},
    {"name": "Damage Aura", "desc": "Hurt nearby enemies passively", "color": PURPLE,
     "apply": lambda p: setattr(p, 'has_aura', True),
     "condition": lambda p: not p.has_aura},
    {"name": "Aura+", "desc": "Bigger aura, more damage", "color": PURPLE,
     "apply": lambda p: (setattr(p, 'aura_radius', p.aura_radius + 25),
                         setattr(p, 'aura_damage', p.aura_damage + 5)),
     "condition": lambda p: p.has_aura},
]


def pick_powerups(player, count=3):
    available = [p for p in POWERUPS if p.get("condition", lambda _: True)(player)]
    return random.sample(available, min(count, len(available)))


# ---------------------------------------------------------------------------
# Main game
# ---------------------------------------------------------------------------
class Game:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
        pygame.display.set_caption("Survivor — Pygame")
        self.clock = pygame.time.Clock()
        self.state = "menu"  # menu, playing, levelup, gameover
        self.reset()

    def reset(self):
        self.player = Player()
        self.enemies = []
        self.projectiles = []
        self.gems = []
        self.dmg_numbers = []
        self.wave = 0
        self.wave_timer = 0
        self.spawn_timer = 0
        self.spawn_rate = INITIAL_SPAWN_RATE
        self.game_time = 0
        self.pending_powerups = []
        self.paused = False
        self.cam_x = 0
        self.cam_y = 0

    # ----- spawning --------------------------------------------------------
    def spawn_enemy(self):
        angle = random.uniform(0, 2 * math.pi)
        d = random.uniform(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
        x = self.player.x + math.cos(angle) * d
        y = self.player.y + math.sin(angle) * d
        x = clamp(x, 0, WORLD_W)
        y = clamp(y, 0, WORLD_H)
        self.enemies.append(Enemy(x, y, self.wave))

    # ----- auto-attack -----------------------------------------------------
    def fire_projectiles(self):
        if self.player.cooldown_timer > 0 or not self.enemies:
            return
        # Find nearest enemy
        nearest = min(self.enemies, key=lambda e: dist((e.x, e.y), (self.player.x, self.player.y)))
        base_angle = angle_to((self.player.x, self.player.y), (nearest.x, nearest.y))

        spread = 0.15  # radians between multi-shot projectiles
        count = self.player.proj_count
        for i in range(count):
            offset = (i - (count - 1) / 2) * spread
            self.projectiles.append(
                Projectile(self.player.x, self.player.y,
                           base_angle + offset,
                           self.player.proj_speed,
                           self.player.proj_damage))
        self.player.cooldown_timer = self.player.proj_cooldown

    # ----- collisions ------------------------------------------------------
    def check_collisions(self):
        p = self.player

        # Projectile -> enemy
        for proj in self.projectiles[:]:
            for enemy in self.enemies[:]:
                if dist((proj.x, proj.y), (enemy.x, enemy.y)) < proj.radius + enemy.radius:
                    enemy.hp -= proj.damage
                    enemy.hit_flash = 4
                    self.dmg_numbers.append(DamageNumber(enemy.x, enemy.y - 10, proj.damage, YELLOW))
                    if proj in self.projectiles:
                        self.projectiles.remove(proj)
                    if enemy.hp <= 0:
                        self.gems.append(Gem(enemy.x, enemy.y, enemy.xp_value))
                        self.enemies.remove(enemy)
                        p.kills += 1
                    break

        # Orbital blades -> enemy
        if p.has_orbit:
            for i in range(p.orbit_count):
                a = p.orbit_angle + (2 * math.pi * i / p.orbit_count)
                ox = p.x + math.cos(a) * p.orbit_radius
                oy = p.y + math.sin(a) * p.orbit_radius
                for enemy in self.enemies[:]:
                    if dist((ox, oy), (enemy.x, enemy.y)) < 8 + enemy.radius:
                        enemy.hp -= p.orbit_damage
                        enemy.hit_flash = 4
                        self.dmg_numbers.append(DamageNumber(enemy.x, enemy.y - 10, p.orbit_damage, CYAN))
                        if enemy.hp <= 0:
                            self.gems.append(Gem(enemy.x, enemy.y, enemy.xp_value))
                            self.enemies.remove(enemy)
                            p.kills += 1

        # Aura -> enemy
        if p.has_aura and p.aura_tick % 15 == 0:
            for enemy in self.enemies[:]:
                if dist((p.x, p.y), (enemy.x, enemy.y)) < p.aura_radius + enemy.radius:
                    enemy.hp -= p.aura_damage
                    enemy.hit_flash = 3
                    if enemy.hp <= 0:
                        self.gems.append(Gem(enemy.x, enemy.y, enemy.xp_value))
                        self.enemies.remove(enemy)
                        p.kills += 1

        # Enemy -> player
        for enemy in self.enemies:
            if dist((enemy.x, enemy.y), (p.x, p.y)) < enemy.radius + p.radius:
                if p.invuln_timer <= 0:
                    p.hp -= enemy.damage
                    p.invuln_timer = INVULN_TIME
                    self.dmg_numbers.append(DamageNumber(p.x, p.y - 20, enemy.damage, RED))
                    if p.hp <= 0:
                        self.state = "gameover"

        # Gem -> player
        for gem in self.gems[:]:
            if dist((gem.x, gem.y), (p.x, p.y)) < gem.radius + p.radius + 10:
                leveled = p.gain_xp(gem.value)
                self.gems.remove(gem)
                if leveled:
                    self.pending_powerups = pick_powerups(p)
                    self.state = "levelup"

    # ----- update ----------------------------------------------------------
    def update(self):
        if self.state != "playing":
            return
        keys = pygame.key.get_pressed()
        self.player.update(keys, 1)

        # Camera
        self.cam_x = self.player.x - SCREEN_W / 2
        self.cam_y = self.player.y - SCREEN_H / 2

        # Wave progression
        self.game_time += 1 / FPS
        self.wave_timer += 1 / FPS
        if self.wave_timer >= WAVE_DURATION:
            self.wave_timer = 0
            self.wave += 1
            self.spawn_rate = max(MIN_SPAWN_RATE, int(INITIAL_SPAWN_RATE * (0.8 ** self.wave)))

        # Spawn
        self.spawn_timer += 1
        if self.spawn_timer >= self.spawn_rate:
            self.spawn_timer = 0
            batch = 1 + self.wave // 2
            for _ in range(batch):
                self.spawn_enemy()

        # Fire
        self.fire_projectiles()

        # Update entities
        for proj in self.projectiles[:]:
            proj.update()
            if proj.life <= 0:
                self.projectiles.remove(proj)

        for enemy in self.enemies:
            enemy.update(self.player.x, self.player.y)

        for gem in self.gems:
            gem.update(self.player.x, self.player.y)

        for dn in self.dmg_numbers[:]:
            dn.update()
            if dn.timer <= 0:
                self.dmg_numbers.remove(dn)

        self.check_collisions()

    # ----- drawing ---------------------------------------------------------
    def draw_ground(self):
        # Tiled ground
        start_x = int(self.cam_x // TILE_SIZE) * TILE_SIZE
        start_y = int(self.cam_y // TILE_SIZE) * TILE_SIZE
        for tx in range(start_x, start_x + SCREEN_W + TILE_SIZE * 2, TILE_SIZE):
            for ty in range(start_y, start_y + SCREEN_H + TILE_SIZE * 2, TILE_SIZE):
                sx = tx - self.cam_x
                sy = ty - self.cam_y
                checker = ((tx // TILE_SIZE) + (ty // TILE_SIZE)) % 2
                color = (25, 28, 35) if checker else (30, 34, 42)
                pygame.draw.rect(self.screen, color, (sx, sy, TILE_SIZE, TILE_SIZE))

    def draw_hud(self):
        p = self.player
        # HP bar
        draw_bar(self.screen, 10, 10, 200, 18, p.hp / p.max_hp, RED, DARK_RED)
        draw_text(self.screen, f"HP {p.hp}/{p.max_hp}", 14, 15, 11)

        # XP bar
        draw_bar(self.screen, 10, 34, 200, 12, p.xp / p.xp_to_next, BLUE, GRAY)
        draw_text(self.screen, f"Lv {p.level}", 13, 15, 33)

        # Stats
        minutes = int(self.game_time) // 60
        seconds = int(self.game_time) % 60
        draw_text(self.screen, f"Time  {minutes:02d}:{seconds:02d}", 16, SCREEN_W - 140, 10)
        draw_text(self.screen, f"Wave  {self.wave + 1}", 16, SCREEN_W - 140, 30)
        draw_text(self.screen, f"Kills {p.kills}", 16, SCREEN_W - 140, 50)
        draw_text(self.screen, f"Enemies {len(self.enemies)}", 14, SCREEN_W - 140, 70, LIGHT_GRAY)

    def draw_menu(self):
        self.screen.fill(DARK_GRAY)
        draw_text(self.screen, "SURVIVOR", 64, SCREEN_W // 2, SCREEN_H // 3, GOLD, center=True)
        draw_text(self.screen, "WASD / Arrow keys to move", 20, SCREEN_W // 2, SCREEN_H // 2, LIGHT_GRAY, center=True)
        draw_text(self.screen, "Auto-attack nearest enemy", 20, SCREEN_W // 2, SCREEN_H // 2 + 30, LIGHT_GRAY, center=True)
        draw_text(self.screen, "Collect gems to level up", 20, SCREEN_W // 2, SCREEN_H // 2 + 60, LIGHT_GRAY, center=True)
        draw_text(self.screen, "Press ENTER to start", 24, SCREEN_W // 2, SCREEN_H * 2 // 3 + 20, WHITE, center=True)
        draw_text(self.screen, "Press ESC to quit", 16, SCREEN_W // 2, SCREEN_H * 2 // 3 + 55, GRAY, center=True)

    def draw_levelup(self):
        # Dim overlay
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))

        draw_text(self.screen, f"LEVEL UP!  (Lv {self.player.level})", 36,
                  SCREEN_W // 2, 100, GOLD, center=True)
        draw_text(self.screen, "Choose a power-up:", 20,
                  SCREEN_W // 2, 150, LIGHT_GRAY, center=True)

        box_w, box_h = 280, 90
        start_x = SCREEN_W // 2 - (len(self.pending_powerups) * (box_w + 20)) // 2 + 10
        start_y = 200
        mx, my = pygame.mouse.get_pos()
        self.hovered_powerup = -1

        for i, pu in enumerate(self.pending_powerups):
            bx = start_x + i * (box_w + 20)
            by = start_y
            hovered = bx <= mx <= bx + box_w and by <= my <= by + box_h
            if hovered:
                self.hovered_powerup = i
            border_color = WHITE if hovered else GRAY
            pygame.draw.rect(self.screen, (40, 40, 55), (bx, by, box_w, box_h))
            pygame.draw.rect(self.screen, border_color, (bx, by, box_w, box_h), 2)
            pygame.draw.rect(self.screen, pu["color"], (bx, by, box_w, 4))
            draw_text(self.screen, f"[{i + 1}]  {pu['name']}", 20, bx + 10, by + 15, pu["color"])
            draw_text(self.screen, pu["desc"], 15, bx + 10, by + 50, LIGHT_GRAY)

    def draw_gameover(self):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))
        draw_text(self.screen, "GAME OVER", 56, SCREEN_W // 2, SCREEN_H // 3, RED, center=True)
        minutes = int(self.game_time) // 60
        seconds = int(self.game_time) % 60
        draw_text(self.screen, f"Survived  {minutes:02d}:{seconds:02d}   |   Kills  {self.player.kills}   |   Level  {self.player.level}",
                  22, SCREEN_W // 2, SCREEN_H // 2, LIGHT_GRAY, center=True)
        draw_text(self.screen, "Press ENTER to play again", 22, SCREEN_W // 2, SCREEN_H // 2 + 60, WHITE, center=True)
        draw_text(self.screen, "Press ESC to quit", 16, SCREEN_W // 2, SCREEN_H // 2 + 95, GRAY, center=True)

    def draw(self):
        if self.state == "menu":
            self.draw_menu()
        elif self.state in ("playing", "levelup", "gameover"):
            self.draw_ground()
            for gem in self.gems:
                gem.draw(self.screen, self.cam_x, self.cam_y)
            for enemy in self.enemies:
                enemy.draw(self.screen, self.cam_x, self.cam_y)
            for proj in self.projectiles:
                proj.draw(self.screen, self.cam_x, self.cam_y)
            self.player.draw(self.screen, self.cam_x, self.cam_y)
            for dn in self.dmg_numbers:
                dn.draw(self.screen, self.cam_x, self.cam_y)
            self.draw_hud()

            if self.state == "levelup":
                self.draw_levelup()
            elif self.state == "gameover":
                self.draw_gameover()

    # ----- events ----------------------------------------------------------
    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False

            if event.type == pygame.KEYDOWN:
                if self.state == "menu":
                    if event.key == pygame.K_RETURN:
                        self.state = "playing"
                    elif event.key == pygame.K_ESCAPE:
                        return False

                elif self.state == "playing":
                    if event.key == pygame.K_ESCAPE:
                        self.state = "menu"
                        self.reset()

                elif self.state == "levelup":
                    idx = -1
                    if event.key == pygame.K_1:
                        idx = 0
                    elif event.key == pygame.K_2:
                        idx = 1
                    elif event.key == pygame.K_3:
                        idx = 2
                    if 0 <= idx < len(self.pending_powerups):
                        self.pending_powerups[idx]["apply"](self.player)
                        self.state = "playing"

                elif self.state == "gameover":
                    if event.key == pygame.K_RETURN:
                        self.reset()
                        self.state = "playing"
                    elif event.key == pygame.K_ESCAPE:
                        return False

            if event.type == pygame.MOUSEBUTTONDOWN and self.state == "levelup":
                if hasattr(self, 'hovered_powerup') and 0 <= self.hovered_powerup < len(self.pending_powerups):
                    self.pending_powerups[self.hovered_powerup]["apply"](self.player)
                    self.state = "playing"

        return True

    # ----- main loop -------------------------------------------------------
    def run(self):
        running = True
        while running:
            running = self.handle_events()
            self.update()
            self.draw()
            pygame.display.flip()
            self.clock.tick(FPS)
        pygame.quit()
        sys.exit()


if __name__ == "__main__":
    Game().run()
