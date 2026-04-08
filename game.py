"""
Survivor - A Vampire Survivors-style game built with Pygame.
Features: multiple weapons, bosses, dash, particles, screen shake,
persistent upgrades, character select, achievements, minimap, and more.
"""

import pygame
import sys
import math
import random
import time
import json
import os
import array as arr_module
import threading

try:
    from updater import check_for_update, download_and_apply_update, get_current_version
    HAS_UPDATER = True
except ImportError:
    HAS_UPDATER = False

# ===========================================================================
# Section 1: Constants
# ===========================================================================
SCREEN_W, SCREEN_H = 960, 720
FPS = 60
FONT_NAME = None

BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (200, 30, 30)
GREEN = (50, 200, 50)
BLUE = (50, 90, 180)
YELLOW = (255, 210, 40)
PURPLE = (140, 40, 200)
CYAN = (60, 200, 220)
ORANGE = (240, 140, 20)
DARK_GRAY = (18, 16, 22)
GRAY = (60, 55, 70)
LIGHT_GRAY = (140, 135, 155)
DARK_RED = (90, 10, 10)
GOLD = (255, 195, 40)
PINK = (255, 100, 150)
TEAL = (0, 160, 170)

# Atmospheric palette
FIRE_BRIGHT = (255, 180, 40)
FIRE_MID = (240, 100, 20)
FIRE_DARK = (180, 40, 10)
EMBER_COLOR = (255, 140, 30)
OCEAN_DEEP = (8, 12, 28)
OCEAN_MID = (12, 22, 45)
OCEAN_LIGHT = (18, 35, 60)
OCEAN_FOAM = (80, 120, 160)
HULL_WHITE = (220, 215, 210)
HULL_BLUE = (50, 70, 140)
HULL_RED = (150, 30, 30)
CAPE_BLUE = (35, 45, 100)
CAPE_DARK = (20, 25, 55)
EYE_GLOW = (255, 80, 20)
BLOOD_RED = (160, 20, 20)

WORLD_W, WORLD_H = 3000, 3000
TILE_SIZE = 64

PLAYER_RADIUS = 28
PLAYER_SPEED = 3.0
PLAYER_BASE_HP = 120
INVULN_TIME = 0.4
DASH_SPEED = 12
DASH_DURATION = 8
DASH_COOLDOWN = 90

PROJ_SPEED = 7
PROJ_RADIUS = 5
PROJ_DAMAGE = 20
PROJ_LIFETIME = 60
PROJ_COOLDOWN = 30

ENEMY_RADIUS = 16
ENEMY_BASE_SPEED = 0.9
ENEMY_BASE_HP = 25
ENEMY_DAMAGE = 8
SPAWN_DIST_MIN = 450
SPAWN_DIST_MAX = 650

GEM_RADIUS = 6
GEM_ATTRACT_DIST = 100
GEM_ATTRACT_SPEED = 5

INITIAL_SPAWN_RATE = 120
MIN_SPAWN_RATE = 25
WAVE_DURATION = 45
BOSS_WAVE_INTERVAL = 5

MINIMAP_SIZE = 120
MINIMAP_MARGIN = 10

SAVE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "save_data.json")


# ===========================================================================
# Section 2: Helpers
# ===========================================================================
def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])

def angle_to(a, b):
    return math.atan2(b[1] - a[1], b[0] - a[0])

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def lerp(a, b, t):
    return a + (b - a) * t

_font_cache = {}
def get_font(size):
    if size not in _font_cache:
        _font_cache[size] = pygame.font.Font(FONT_NAME, size)
    return _font_cache[size]

def draw_text(surface, text, size, x, y, color=WHITE, center=False):
    font = get_font(size)
    img = font.render(str(text), True, color)
    rect = img.get_rect(center=(x, y)) if center else img.get_rect(topleft=(x, y))
    surface.blit(img, rect)
    return rect

def draw_bar(surface, x, y, w, h, ratio, color, bg=GRAY):
    pygame.draw.rect(surface, bg, (x, y, w, h))
    pygame.draw.rect(surface, color, (x, y, int(w * clamp(ratio, 0, 1)), h))
    pygame.draw.rect(surface, WHITE, (x, y, w, h), 1)


# ===========================================================================

# ===========================================================================
# Section 2b: Sprite Loading System
# ===========================================================================
ASSET_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
SPRITES = {}

def load_sprites():
    """Load all sprite assets, scale preserving aspect ratio."""
    global SPRITES
    defs = {
        "player_tugboat": ("player_tugboat.png", 90),
        "player_warship": ("player_warship.png", 90),
        "player_speedboat": ("player_speedboat.png", 90),
        "hero_boat": ("hero_boat.png", 90),
        "enemy_zombie": ("enemy_zombie.png", 48),
        "enemy_skeleton": ("enemy_skeleton.png", 48),
        "enemy_cthulhu_fisher": ("enemy_cthulhu_fisher.png", 58),
        "enemy_anglerfish": ("enemy_anglerfish.png", 50),
        "enemy_cthulhu_priest": ("enemy_cthulhu_priest.png", 58),
        "boss_kraken": ("boss_kraken.png", 130),
    }
    for key, (filename, target_h) in defs.items():
        path = os.path.join(ASSET_DIR, filename)
        try:
            raw = pygame.image.load(path).convert_alpha()
            w, h = raw.get_size()
            scale = target_h / h
            new_w, new_h = int(w * scale), int(h * scale)
            img = pygame.transform.smoothscale(raw, (new_w, new_h))
            SPRITES[key] = img
            SPRITES[key + "_flip"] = pygame.transform.flip(img, True, False)
        except Exception as e:
            print(f"Warning: Could not load {filename}: {e}")
    # Character select previews (larger)
    preview_h = 110
    for name in ["player_tugboat", "player_warship", "player_speedboat", "hero_boat"]:
        fname = defs[name][0]
        path = os.path.join(ASSET_DIR, fname)
        try:
            raw = pygame.image.load(path).convert_alpha()
            w, h = raw.get_size()
            scale = preview_h / h
            SPRITES[name + "_preview"] = pygame.transform.smoothscale(
                raw, (int(w * scale), preview_h))
        except Exception:
            pass

# Mapping from character index to sprite key
CHAR_SPRITE_KEYS = ["player_tugboat", "player_warship", "player_speedboat"]
# Mapping from enemy variant to sprite key(s)
ENEMY_SPRITE_MAP = {
    "normal": ["enemy_zombie", "enemy_skeleton"],
    "fast": ["enemy_anglerfish"],
    "tank": ["enemy_cthulhu_fisher"],
    "elite": ["enemy_cthulhu_priest"],
}



# Section 3: Save / Load System
# ===========================================================================
DEFAULT_SAVE = {
    "gold": 0,
    "upgrades": {"max_hp": 0, "damage": 0, "speed": 0, "xp_bonus": 0},
    "high_scores": [],
    "achievements": [],
    "settings": {"sfx_volume": 0.7, "fullscreen": False},
    "total_kills": 0,
    "total_runs": 0,
}

def load_save():
    try:
        with open(SAVE_FILE, "r") as f:
            data = json.load(f)
        for k, v in DEFAULT_SAVE.items():
            if k not in data:
                data[k] = v if not isinstance(v, (dict, list)) else json.loads(json.dumps(v))
        return data
    except Exception:
        return json.loads(json.dumps(DEFAULT_SAVE))

def save_game(data):
    try:
        with open(SAVE_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass


# ===========================================================================
# Section 4: Sound System
# ===========================================================================
class SoundManager:
    def __init__(self):
        try:
            pygame.mixer.init(frequency=22050, size=-16, channels=1, buffer=512)
            self.enabled = True
        except Exception:
            self.enabled = False
        self.sounds = {}
        self.volume = 0.5
        if self.enabled:
            self._generate_sounds()

    def _tone(self, freq, dur, vol=0.3, wave="sine"):
        sr = 22050
        n = int(sr * dur)
        buf = arr_module.array("h", [0] * n)
        for i in range(n):
            t = i / sr
            env = max(0, 1 - i / n)
            if wave == "sine":
                v = math.sin(2 * math.pi * freq * t)
            elif wave == "square":
                v = 1 if math.sin(2 * math.pi * freq * t) > 0 else -1
            elif wave == "noise":
                v = random.uniform(-1, 1)
            else:
                v = math.sin(2 * math.pi * freq * t)
            buf[i] = int(v * vol * env * 32767)
        return pygame.mixer.Sound(buffer=buf)

    def _generate_sounds(self):
        self.sounds["shoot"] = self._tone(600, 0.08, 0.2)
        self.sounds["hit"] = self._tone(200, 0.1, 0.25, "square")
        self.sounds["kill"] = self._tone(800, 0.12, 0.2)
        self.sounds["gem"] = self._tone(1200, 0.06, 0.15)
        self.sounds["levelup"] = self._tone(880, 0.3, 0.3)
        self.sounds["dash"] = self._tone(400, 0.15, 0.2, "noise")
        self.sounds["hurt"] = self._tone(150, 0.2, 0.3, "square")
        self.sounds["boss_roar"] = self._tone(80, 0.5, 0.4, "square")
        self.sounds["explosion"] = self._tone(100, 0.3, 0.35, "noise")
        self.sounds["lightning"] = self._tone(1500, 0.1, 0.2, "square")
        self.sounds["heal"] = self._tone(1000, 0.2, 0.2)
        self.sounds["chest"] = self._tone(660, 0.15, 0.25)
        self.sounds["achievement"] = self._tone(1100, 0.4, 0.3)
        self.sounds["select"] = self._tone(500, 0.05, 0.15)
        self.sounds["boomerang"] = self._tone(350, 0.12, 0.2)

    def play(self, name):
        if self.enabled and name in self.sounds:
            s = self.sounds[name]
            s.set_volume(self.volume)
            s.play()

    def set_volume(self, vol):
        self.volume = clamp(vol, 0, 1)


# ===========================================================================
# Section 5: Particle System
# ===========================================================================
class Particle:
    __slots__ = ("x", "y", "vx", "vy", "color", "life", "max_life", "size", "shrink", "glow")

    def __init__(self, x, y, vx, vy, color, life=20, size=3, shrink=True, glow=False):
        self.x, self.y = x, y
        self.vx, self.vy = vx, vy
        self.color = color
        self.life = self.max_life = life
        self.size = size
        self.shrink = shrink
        self.glow = glow

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.vx *= 0.96
        self.vy *= 0.96
        self.life -= 1

    def draw(self, surface, cam_x, cam_y):
        alpha = self.life / self.max_life
        sz = self.size * alpha if self.shrink else self.size
        if sz < 0.5:
            return
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        c = tuple(int(ch * alpha) for ch in self.color)
        if self.glow and sz > 2:
            glow_surf = pygame.Surface((int(sz * 4), int(sz * 4)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*self.color, int(40 * alpha)),
                               (int(sz * 2), int(sz * 2)), int(sz * 2))
            surface.blit(glow_surf, (sx - int(sz * 2), sy - int(sz * 2)))
        pygame.draw.circle(surface, c, (sx, sy), max(1, int(sz)))


class ParticleSystem:
    def __init__(self):
        self.particles = []

    def emit(self, x, y, color, count=8, speed=3, life=20, size=3, glow=False):
        for _ in range(count):
            a = random.uniform(0, math.pi * 2)
            sp = random.uniform(speed * 0.3, speed)
            self.particles.append(
                Particle(x, y, math.cos(a) * sp, math.sin(a) * sp,
                         color, life + random.randint(-5, 5), size, glow=glow))

    def update(self):
        self.particles = [p for p in self.particles if p.life > 0]
        for p in self.particles:
            p.update()

    def draw(self, surface, cam_x, cam_y):
        for p in self.particles:
            p.draw(surface, cam_x, cam_y)


# ===========================================================================
# Section 6: Screen Shake
# ===========================================================================
class ScreenShake:
    def __init__(self):
        self.amount = 0
        self.offset_x = 0
        self.offset_y = 0

    def shake(self, intensity):
        self.amount = max(self.amount, intensity)

    def update(self):
        if self.amount > 0.5:
            self.offset_x = random.uniform(-self.amount, self.amount)
            self.offset_y = random.uniform(-self.amount, self.amount)
            self.amount *= 0.85
        else:
            self.amount = self.offset_x = self.offset_y = 0


# ===========================================================================
# Section 7: Weapon Entities
# ===========================================================================
class Projectile:
    def __init__(self, x, y, angle, speed, damage, color=YELLOW,
                 radius=PROJ_RADIUS, life=PROJ_LIFETIME):
        self.x, self.y = x, y
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed
        self.radius = radius
        self.damage = damage
        self.life = life
        self.color = color

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.life -= 1

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        # Glow behind projectile
        gs = pygame.Surface((self.radius * 4, self.radius * 4), pygame.SRCALPHA)
        pygame.draw.circle(gs, (*self.color, 40),
                           (self.radius * 2, self.radius * 2), self.radius * 2)
        surface.blit(gs, (sx - self.radius * 2, sy - self.radius * 2))
        pygame.draw.circle(surface, self.color, (sx, sy), self.radius)
        pygame.draw.circle(surface, WHITE, (sx, sy), max(1, self.radius - 2))
        pygame.draw.circle(surface, self.color, (sx, sy), self.radius, 1)


class Boomerang:
    def __init__(self, x, y, angle, speed, damage, owner_ref):
        self.x, self.y = x, y
        self.angle = angle
        self.speed = speed
        self.damage = damage
        self.radius = 8
        self.color = TEAL
        self.phase = "out"
        self.dist_traveled = 0
        self.max_dist = 200
        self.rotation = 0
        self.owner_ref = owner_ref  # mutable list [px, py]
        self.hit_enemies = set()

    def update(self):
        self.rotation += 0.3
        if self.phase == "out":
            self.x += math.cos(self.angle) * self.speed
            self.y += math.sin(self.angle) * self.speed
            self.dist_traveled += self.speed
            if self.dist_traveled >= self.max_dist:
                self.phase = "return"
                self.hit_enemies.clear()
        else:
            a = angle_to((self.x, self.y), (self.owner_ref[0], self.owner_ref[1]))
            self.x += math.cos(a) * self.speed * 1.2
            self.y += math.sin(a) * self.speed * 1.2

    @property
    def returned(self):
        return (self.phase == "return" and
                dist((self.x, self.y), (self.owner_ref[0], self.owner_ref[1])) < 30)

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        pts = []
        for i in range(4):
            a = self.rotation + i * math.pi / 2
            pts.append((sx + math.cos(a) * self.radius,
                        sy + math.sin(a) * self.radius))
        pygame.draw.polygon(surface, self.color, pts)
        pygame.draw.polygon(surface, WHITE, pts, 1)


class LightningBolt:
    def __init__(self, x, y, targets, damage):
        self.segments = []
        self.damage = damage
        self.life = 12
        cx, cy = x, y
        for tx, ty in targets:
            self.segments.append(((cx, cy), (tx, ty)))
            cx, cy = tx, ty

    def update(self):
        self.life -= 1

    def draw(self, surface, cam_x, cam_y):
        alpha = self.life / 12
        for (x1, y1), (x2, y2) in self.segments:
            sx1, sy1 = int(x1 - cam_x), int(y1 - cam_y)
            sx2, sy2 = int(x2 - cam_x), int(y2 - cam_y)
            c = tuple(int(ch * alpha) for ch in CYAN)
            w = max(1, int(3 * alpha))
            mid_x = (sx1 + sx2) // 2 + random.randint(-8, 8)
            mid_y = (sy1 + sy2) // 2 + random.randint(-8, 8)
            pygame.draw.line(surface, c, (sx1, sy1), (mid_x, mid_y), w)
            pygame.draw.line(surface, c, (mid_x, mid_y), (sx2, sy2), w)


class ExplosionEffect:
    def __init__(self, x, y, radius, damage, color=ORANGE):
        self.x, self.y = x, y
        self.max_radius = radius
        self.damage = damage
        self.color = color
        self.life = 15
        self.max_life = 15

    def update(self):
        self.life -= 1

    def draw(self, surface, cam_x, cam_y):
        alpha = self.life / self.max_life
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        r = int(self.max_radius * (1 - alpha * 0.3))
        if r < 1:
            return
        # Outer fire glow
        outer_r = int(r * 1.5)
        surf = pygame.Surface((outer_r * 2, outer_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(surf, (255, 80, 10, int(30 * alpha)),
                           (outer_r, outer_r), outer_r)
        pygame.draw.circle(surf, (*self.color, int(120 * alpha)), (outer_r, outer_r), r)
        pygame.draw.circle(surf, (255, 220, 100, int(80 * alpha)),
                           (outer_r, outer_r), max(1, r // 2))
        pygame.draw.circle(surf, (255, 255, 200, int(50 * alpha)),
                           (outer_r, outer_r), max(1, r // 4))
        surface.blit(surf, (sx - outer_r, sy - outer_r))


# ===========================================================================
# Section 8: Game Entities
# ===========================================================================
CHARACTERS = [
    {"name": "Tugboat", "color": BLUE,
     "desc": "Balanced fighter. Cannon weapon.",
     "hp_mod": 1.0, "spd_mod": 1.0, "dmg_mod": 1.0, "weapon": "projectile"},
    {"name": "Warship", "color": PURPLE,
     "desc": "Slow tank. Lightning mast.",
     "hp_mod": 1.4, "spd_mod": 0.7, "dmg_mod": 1.3, "weapon": "lightning"},
    {"name": "Speedboat", "color": GREEN,
     "desc": "Fast & fragile. Anchor boomerang.",
     "hp_mod": 0.8, "spd_mod": 1.3, "dmg_mod": 1.0, "weapon": "boomerang"},
]


class Player:
    def __init__(self, char_idx=0, upgrades=None):
        ch = CHARACTERS[char_idx]
        ups = upgrades or {"max_hp": 0, "damage": 0, "speed": 0, "xp_bonus": 0}
        self.char_idx = char_idx
        self.char_color = ch["color"]
        self.x = WORLD_W / 2
        self.y = WORLD_H / 2
        self.radius = PLAYER_RADIUS
        self.max_hp = int((PLAYER_BASE_HP + ups["max_hp"] * 10) * ch["hp_mod"])
        self.hp = self.max_hp
        self.speed = (PLAYER_SPEED + ups["speed"] * 0.2) * ch["spd_mod"]
        self.xp = 0
        self.level = 1
        self.xp_to_next = 20
        self.xp_bonus = 1.0 + ups["xp_bonus"] * 0.1
        self.proj_damage = int((PROJ_DAMAGE + ups["damage"] * 5) * ch["dmg_mod"])
        self.proj_speed = PROJ_SPEED
        self.proj_count = 1
        self.proj_cooldown = PROJ_COOLDOWN
        self.cooldown_timer = 0
        self.invuln_timer = 0
        self.kills = 0
        self.gold = 0
        self.powerups_chosen = 0
        self.weapon = ch["weapon"]

        # Dash
        self.dash_timer = 0
        self.dash_cooldown_timer = 0
        self.dash_dx = 0
        self.dash_dy = 0
        self.dashes_used = 0

        # Orbit
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

        # Lightning weapon timers
        self.lightning_cooldown = 45
        self.lightning_timer = 0
        self.lightning_chains = 3
        self.lightning_range = 150

        # Boomerang weapon timers
        self.boomerang_cooldown = 50
        self.boomerang_timer = 0
        self.boomerang_count = 1

        # Explosion ability
        self.has_explosion = False
        self.explosion_cooldown = 120
        self.explosion_timer = 0
        self.explosion_radius = 100
        self.explosion_damage = 30

        # Animation
        self.bob_timer = 0
        self.facing_x = 1

    def gain_xp(self, amount):
        self.xp += int(amount * self.xp_bonus)
        while self.xp >= self.xp_to_next:
            self.xp -= self.xp_to_next
            self.level += 1
            self.xp_to_next = int(self.xp_to_next * 1.4)
            return True
        return False

    def start_dash(self, keys):
        if self.dash_cooldown_timer > 0 or self.dash_timer > 0:
            return False
        dx = dy = 0
        if keys[pygame.K_w] or keys[pygame.K_UP]: dy -= 1
        if keys[pygame.K_s] or keys[pygame.K_DOWN]: dy += 1
        if keys[pygame.K_a] or keys[pygame.K_LEFT]: dx -= 1
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]: dx += 1
        if dx == 0 and dy == 0:
            dx = self.facing_x
        mag = math.hypot(dx, dy)
        if mag > 0:
            self.dash_dx = dx / mag
            self.dash_dy = dy / mag
        self.dash_timer = DASH_DURATION
        self.dash_cooldown_timer = DASH_COOLDOWN
        self.invuln_timer = DASH_DURATION / FPS + 0.05
        self.dashes_used += 1
        return True

    def update(self, keys):
        self.bob_timer += 0.1
        if self.dash_timer > 0:
            self.x += self.dash_dx * DASH_SPEED
            self.y += self.dash_dy * DASH_SPEED
            self.dash_timer -= 1
        else:
            dx = dy = 0
            if keys[pygame.K_w] or keys[pygame.K_UP]: dy -= 1
            if keys[pygame.K_s] or keys[pygame.K_DOWN]: dy += 1
            if keys[pygame.K_a] or keys[pygame.K_LEFT]: dx -= 1
            if keys[pygame.K_d] or keys[pygame.K_RIGHT]: dx += 1
            if dx != 0:
                self.facing_x = dx
            if dx or dy:
                mag = math.hypot(dx, dy)
                self.x += dx / mag * self.speed
                self.y += dy / mag * self.speed

        self.x = clamp(self.x, self.radius, WORLD_W - self.radius)
        self.y = clamp(self.y, self.radius, WORLD_H - self.radius)

        if self.invuln_timer > 0: self.invuln_timer -= 1 / FPS
        if self.cooldown_timer > 0: self.cooldown_timer -= 1
        if self.dash_cooldown_timer > 0: self.dash_cooldown_timer -= 1
        if self.lightning_timer > 0: self.lightning_timer -= 1
        if self.boomerang_timer > 0: self.boomerang_timer -= 1
        if self.explosion_timer > 0: self.explosion_timer -= 1
        if self.has_orbit: self.orbit_angle += self.orbit_speed
        if self.has_aura: self.aura_tick += 1

    def draw(self, surface, cam_x, cam_y):
        sx = int(self.x - cam_x)
        sy = int(self.y - cam_y)
        bob = math.sin(self.bob_timer) * 4
        ex = 1 if self.facing_x >= 0 else -1
        t = pygame.time.get_ticks() / 1000.0

        # Aura glow
        if self.has_aura:
            aura_surf = pygame.Surface(
                (self.aura_radius * 2, self.aura_radius * 2), pygame.SRCALPHA)
            pulse = int(30 + 20 * math.sin(t * 4))
            pygame.draw.circle(aura_surf, (255, 100, 30, pulse),
                               (self.aura_radius, self.aura_radius), self.aura_radius)
            pygame.draw.circle(aura_surf, (255, 60, 10, pulse // 2),
                               (self.aura_radius, self.aura_radius), int(self.aura_radius * 0.7))
            surface.blit(aura_surf, (sx - self.aura_radius, sy - self.aura_radius))

        # Orbital blades
        if self.has_orbit:
            for i in range(self.orbit_count):
                a = self.orbit_angle + (2 * math.pi * i / self.orbit_count)
                ox = sx + math.cos(a) * self.orbit_radius
                oy = sy + math.sin(a) * self.orbit_radius
                gs = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.circle(gs, (100, 200, 255, 60), (10, 10), 10)
                surface.blit(gs, (int(ox) - 10, int(oy) - 10))
                pygame.draw.circle(surface, CYAN, (int(ox), int(oy)), 8)
                pygame.draw.circle(surface, WHITE, (int(ox), int(oy)), 8, 2)
                pygame.draw.circle(surface, WHITE, (int(ox), int(oy)), 4)

        # Get sprite
        sprite_key = CHAR_SPRITE_KEYS[self.char_idx] if self.char_idx < len(CHAR_SPRITE_KEYS) else "player_tugboat"
        flip_key = sprite_key + ("_flip" if ex < 0 else "")
        sprite = SPRITES.get(flip_key)

        # Wake/foam behind boat
        for i in range(4):
            wx = sx - ex * (20 + i * 12)
            wy = int(sy + bob + 18 + random.randint(-2, 2))
            wa = max(0, 70 - i * 18)
            ws = pygame.Surface((14, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(ws, (120, 160, 200, wa), (0, 0, 14, 6))
            surface.blit(ws, (wx - 7, wy - 3))

        # Dash ghost trail (using sprites)
        if self.dash_timer > 0 and sprite:
            for i in range(4):
                gx = int(sx - self.dash_dx * (i + 1) * 18)
                gy = int(sy + bob - self.dash_dy * (i + 1) * 18)
                alpha = max(0, 120 - i * 30)
                ghost = sprite.copy()
                ghost.set_alpha(alpha)
                surface.blit(ghost, (gx - sprite.get_width() // 2,
                                     gy - sprite.get_height() // 2))

        blink = self.invuln_timer > 0 and int(self.invuln_timer * 10) % 2
        if not blink:
            by = int(sy + bob)
            if sprite:
                # Shadow under sprite
                sw, sh = sprite.get_size()
                shadow = pygame.Surface((sw, 12), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow, (0, 0, 0, 30), (4, 0, sw - 8, 12))
                surface.blit(shadow, (sx - sw // 2, by + sh // 3))

                draw_sprite = sprite
                # Damage flash (red tint when recently hit)
                if self.invuln_timer > 0.2:
                    draw_sprite = sprite.copy()
                    tint = pygame.Surface(sprite.get_size(), pygame.SRCALPHA)
                    tint.fill((255, 60, 60, 100))
                    draw_sprite.blit(tint, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                    white = pygame.Surface(sprite.get_size(), pygame.SRCALPHA)
                    white.fill((255, 180, 180, 80))
                    draw_sprite.blit(white, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

                surface.blit(draw_sprite, (sx - sw // 2, by - sh // 2))
            else:
                # Fallback: simple colored circle
                pygame.draw.circle(surface, self.char_color, (sx, by), self.radius)
                pygame.draw.circle(surface, WHITE, (sx, by), self.radius, 2)

        # Dash cooldown indicator
        if self.dash_cooldown_timer > 0:
            ratio = 1 - self.dash_cooldown_timer / DASH_COOLDOWN
            draw_bar(surface, sx - 20, int(sy + bob) + self.radius + 6,
                     40, 4, ratio, CYAN, DARK_GRAY)



class Enemy:
    def __init__(self, x, y, wave):
        self.x, self.y = x, y
        self.radius = ENEMY_RADIUS + random.randint(-2, 4)
        scale = 1 + wave * 0.08
        self.max_hp = int(ENEMY_BASE_HP * scale)
        self.hp = self.max_hp
        self.speed = ENEMY_BASE_SPEED + random.uniform(-0.2, 0.3) + wave * 0.05
        self.damage = ENEMY_DAMAGE + wave * 2
        self.xp_value = 5 + wave
        self.gold_value = 1 + wave // 2
        self.hit_flash = 0
        self.is_boss = False
        self.anim_timer = random.uniform(0, math.pi * 2)
        self.drop_chance = 0.05

        variant = random.random()
        if variant < 0.12 and wave >= 2:
            self.max_hp = int(self.max_hp * 2.5)
            self.hp = self.max_hp
            self.speed *= 0.6
            self.radius += 6
            self.xp_value *= 3
            self.gold_value *= 2
            self.color = PURPLE
            self.damage = int(self.damage * 1.5)
            self.variant = "tank"
        elif variant < 0.24 and wave >= 1:
            self.speed *= 1.8
            self.max_hp = int(self.max_hp * 0.6)
            self.hp = self.max_hp
            self.color = ORANGE
            self.variant = "fast"
        elif variant < 0.32 and wave >= 4:
            self.max_hp = int(self.max_hp * 1.8)
            self.hp = self.max_hp
            self.speed *= 0.9
            self.radius += 4
            self.xp_value *= 2
            self.gold_value *= 2
            self.color = TEAL
            self.damage = int(self.damage * 1.3)
            self.variant = "elite"
        else:
            self.color = RED
            self.variant = "normal"
        # Assign sprite key for this variant
        sprite_options = ENEMY_SPRITE_MAP.get(self.variant, ["enemy_zombie"])
        self.sprite_key = random.choice(sprite_options)


    def update(self, px, py):
        a = angle_to((self.x, self.y), (px, py))
        self.x += math.cos(a) * self.speed
        self.y += math.sin(a) * self.speed
        if self.hit_flash > 0:
            self.hit_flash -= 1
        self.anim_timer += 0.08

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        bob = math.sin(self.anim_timer) * 3
        sy_b = int(sy + bob)

        # Get sprite (face toward player = face right by default)
        sprite = SPRITES.get(self.sprite_key)
        if sprite:
            sw, sh = sprite.get_size()

            # Shadow underneath
            shadow = pygame.Surface((sw + 4, 10), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow, (0, 0, 0, 25), (0, 0, sw + 4, 10))
            surface.blit(shadow, (sx - sw // 2 - 2, sy_b + sh // 3))

            draw_sprite = sprite
            # Hit flash (white overlay)
            if self.hit_flash > 0:
                draw_sprite = sprite.copy()
                white = pygame.Surface(sprite.get_size(), pygame.SRCALPHA)
                white.fill((255, 255, 255, 160))
                draw_sprite.blit(white, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

            surface.blit(draw_sprite, (sx - sw // 2, sy_b - sh // 2))
        else:
            # Fallback: simple colored circle
            r = self.radius
            color = WHITE if self.hit_flash > 0 else self.color
            pygame.draw.circle(surface, color, (sx, sy_b), r)
            pygame.draw.circle(surface, BLACK, (sx, sy_b), r, 2)

        # HP bar
        if self.hp < self.max_hp:
            sp = SPRITES.get(self.sprite_key)
            bw = max(24, (sp.get_width() if sp else self.radius * 2) + 8)
            bx = sx - bw // 2
            sh = sp.get_height() if sp else self.radius * 2
            hp_y = sy_b - sh // 2 - 8
            pygame.draw.rect(surface, (20, 10, 10), (bx - 1, hp_y - 1, bw + 2, 7))
            pygame.draw.rect(surface, BLOOD_RED,
                             (bx, hp_y, int(bw * self.hp / self.max_hp), 5))
            pygame.draw.rect(surface, (80, 30, 30), (bx, hp_y, bw, 5), 1)



class Boss(Enemy):
    def __init__(self, x, y, wave):
        super().__init__(x, y, wave)
        self.is_boss = True
        self.radius = 32 + wave * 2
        self.max_hp = int(ENEMY_BASE_HP * (8 + wave * 3))
        self.hp = self.max_hp
        self.speed = ENEMY_BASE_SPEED * 0.7
        self.damage = ENEMY_DAMAGE * 3 + wave * 4
        self.xp_value = 50 + wave * 20
        self.gold_value = 20 + wave * 10
        self.color = DARK_RED
        self.variant = "boss"
        self.drop_chance = 1.0

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        pulse = math.sin(self.anim_timer) * 4
        r = int(self.radius + pulse)
        t = pygame.time.get_ticks() / 1000.0

        # Dark aura rings
        for ar in range(3):
            aura_r = r + 20 + ar * 15
            aura = pygame.Surface((aura_r * 2, aura_r * 2), pygame.SRCALPHA)
            a = max(0, 25 - ar * 8)
            pygame.draw.circle(aura, (120, 0, 40, a), (aura_r, aura_r), aura_r)
            surface.blit(aura, (sx - aura_r, sy - aura_r))

        # Fire ring around boss
        for i in range(8):
            fa = t * 2 + i * math.pi / 4
            fx = sx + math.cos(fa) * (r + 15)
            fy = sy + math.sin(fa) * (r + 15)
            fs = pygame.Surface((16, 16), pygame.SRCALPHA)
            fc = random.choice([FIRE_BRIGHT, FIRE_MID, FIRE_DARK])
            pygame.draw.circle(fs, (*fc, 120), (8, 8), 6 + random.randint(-2, 2))
            surface.blit(fs, (int(fx) - 8, int(fy) - 8))

        # Draw kraken sprite scaled to current boss radius
        sprite = SPRITES.get("boss_kraken")
        if sprite:
            # Scale sprite to match boss radius (with pulse)
            base_h = max(80, r * 3)
            raw = sprite
            ow, oh = raw.get_size()
            scale = base_h / oh
            sw, sh = int(ow * scale), int(oh * scale)
            scaled = pygame.transform.smoothscale(raw, (sw, sh))

            draw_sprite = scaled
            if self.hit_flash > 0:
                draw_sprite = scaled.copy()
                white = pygame.Surface((sw, sh), pygame.SRCALPHA)
                white.fill((255, 255, 255, 160))
                draw_sprite.blit(white, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

            surface.blit(draw_sprite, (sx - sw // 2, sy - sh // 2))
        else:
            # Fallback circle
            color = WHITE if self.hit_flash > 0 else self.color
            pygame.draw.circle(surface, color, (sx, sy), r)
            pygame.draw.circle(surface, (120, 25, 25), (sx, sy), r, 4)

        # Boss HP bar (wide, ornate)
        bw = min(240, self.radius * 5)
        bx = sx - bw // 2
        hp_y = sy - r - 28
        pygame.draw.rect(surface, (10, 5, 5), (bx - 2, hp_y - 2, bw + 4, 14))
        fill_w = int(bw * self.hp / self.max_hp)
        pygame.draw.rect(surface, BLOOD_RED, (bx, hp_y, fill_w, 10))
        for gi in range(fill_w):
            ga = int(30 * math.sin(gi * 0.1 + t * 3))
            gs = pygame.Surface((1, 10), pygame.SRCALPHA)
            gs.fill((255, 255, 255, max(0, ga)))
            surface.blit(gs, (bx + gi, hp_y))
        pygame.draw.rect(surface, GOLD, (bx - 2, hp_y - 2, bw + 4, 14), 2)
        draw_text(surface, "KRAKEN", 14, sx, hp_y - 14, GOLD, center=True)



class Gem:
    def __init__(self, x, y, value=5):
        self.x, self.y = x, y
        self.radius = GEM_RADIUS
        self.value = value
        self.anim_timer = random.uniform(0, math.pi * 2)

    def update(self, px, py, attract_range=GEM_ATTRACT_DIST):
        self.anim_timer += 0.1
        d = dist((self.x, self.y), (px, py))
        if d < attract_range:
            a = angle_to((self.x, self.y), (px, py))
            speed = GEM_ATTRACT_SPEED * (1 - d / attract_range) + 1
            self.x += math.cos(a) * speed
            self.y += math.sin(a) * speed

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        bob = math.sin(self.anim_timer) * 3
        sy_b = int(sy + bob)
        # Blue crystal glow (like VS blue gems)
        glow = pygame.Surface((28, 28), pygame.SRCALPHA)
        pygame.draw.circle(glow, (60, 120, 255, 50), (14, 14), 14)
        surface.blit(glow, (sx - 14, sy_b - 14))
        glow2 = pygame.Surface((16, 16), pygame.SRCALPHA)
        pygame.draw.circle(glow2, (80, 160, 255, 80), (8, 8), 8)
        surface.blit(glow2, (sx - 8, sy_b - 8))
        # Diamond shape (blue crystal)
        r = self.radius + 1
        pts = [(sx, sy_b - r - 2), (sx + r, sy_b),
               (sx, sy_b + r), (sx - r, sy_b)]
        pygame.draw.polygon(surface, (40, 100, 220), pts)
        # Inner highlight
        inner = [(sx, sy_b - r + 2), (sx + r - 3, sy_b),
                 (sx, sy_b + r - 3), (sx - r + 3, sy_b)]
        pygame.draw.polygon(surface, (80, 160, 255), inner)
        # Sparkle
        pygame.draw.polygon(surface, (180, 220, 255), pts, 2)
        sparkle = int(3 + 2 * math.sin(self.anim_timer * 2))
        pygame.draw.circle(surface, (200, 230, 255), (sx - 1, sy_b - r + 3), sparkle)


class HealthPickup:
    def __init__(self, x, y, heal=20):
        self.x, self.y = x, y
        self.heal = heal
        self.radius = 8
        self.anim_timer = 0

    def update(self):
        self.anim_timer += 0.08

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        bob = math.sin(self.anim_timer) * 3
        sy_b = int(sy + bob)
        pygame.draw.rect(surface, RED, (sx - 6, sy_b - 2, 12, 4))
        pygame.draw.rect(surface, RED, (sx - 2, sy_b - 6, 4, 12))
        pygame.draw.rect(surface, WHITE, (sx - 7, sy_b - 7, 14, 14), 1)


class TreasureChest:
    def __init__(self, x, y):
        self.x, self.y = x, y
        self.radius = 14
        self.anim_timer = 0

    def update(self):
        self.anim_timer += 0.1

    def draw(self, surface, cam_x, cam_y):
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        glow_val = int(20 + 15 * math.sin(self.anim_timer))
        glow = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(glow, (255, 200, 50, glow_val), (20, 20), 20)
        surface.blit(glow, (sx - 20, sy - 20))
        pygame.draw.rect(surface, (139, 90, 43), (sx - 10, sy - 6, 20, 14))
        pygame.draw.rect(surface, (180, 120, 60), (sx - 10, sy - 10, 20, 6))
        pygame.draw.rect(surface, GOLD, (sx - 2, sy - 4, 4, 4))
        pygame.draw.rect(surface, WHITE, (sx - 11, sy - 11, 22, 20), 1)


class DamageNumber:
    def __init__(self, x, y, value, color=WHITE):
        self.x, self.y = x, y
        self.value = value
        self.color = color
        self.timer = 40
        self.vy = -2.5
        self.scale = 1.5  # start big, shrink

    def update(self):
        self.y += self.vy
        self.vy *= 0.94
        self.timer -= 1
        self.scale = max(1.0, self.scale - 0.02)

    def draw(self, surface, cam_x, cam_y):
        alpha = clamp(self.timer / 30, 0, 1)
        sx, sy = int(self.x - cam_x), int(self.y - cam_y)
        size = int(22 * self.scale)
        font = get_font(size)
        text = str(self.value)
        # Dark outline for readability
        outline_color = (0, 0, 0)
        for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2), (-1, 0), (1, 0), (0, -1), (0, 1)]:
            img = font.render(text, True, outline_color)
            img.set_alpha(int(255 * alpha))
            rect = img.get_rect(center=(sx + ox, sy + oy))
            surface.blit(img, rect)
        # Main colored text
        color = tuple(int(c * alpha) for c in self.color)
        img = font.render(text, True, color)
        rect = img.get_rect(center=(sx, sy))
        surface.blit(img, rect)


# ===========================================================================
# Section 9: Achievements
# ===========================================================================
ACHIEVEMENT_DEFS = [
    {"id": "first_blood", "name": "First Blood", "desc": "Kill your first enemy",
     "check": lambda p, g: p.kills >= 1},
    {"id": "centurion", "name": "Centurion", "desc": "Kill 100 enemies in one run",
     "check": lambda p, g: p.kills >= 100},
    {"id": "slaughter", "name": "Slaughter", "desc": "Kill 500 enemies in one run",
     "check": lambda p, g: p.kills >= 500},
    {"id": "wave5", "name": "Wave Rider", "desc": "Survive 5 waves",
     "check": lambda p, g: g.wave >= 5},
    {"id": "wave10", "name": "Veteran", "desc": "Survive 10 waves",
     "check": lambda p, g: g.wave >= 10},
    {"id": "boss_slayer", "name": "Boss Slayer", "desc": "Defeat a boss",
     "check": lambda p, g: g.bosses_killed >= 1},
    {"id": "level10", "name": "Powered Up", "desc": "Reach level 10",
     "check": lambda p, g: p.level >= 10},
    {"id": "level20", "name": "Unstoppable", "desc": "Reach level 20",
     "check": lambda p, g: p.level >= 20},
    {"id": "dasher", "name": "Speed Demon", "desc": "Dash 50 times in one run",
     "check": lambda p, g: p.dashes_used >= 50},
    {"id": "survivor5", "name": "Survivor", "desc": "Survive for 5 minutes",
     "check": lambda p, g: g.game_time >= 300},
    {"id": "survivor10", "name": "Endurance", "desc": "Survive for 10 minutes",
     "check": lambda p, g: g.game_time >= 600},
    {"id": "rich", "name": "Treasure Hunter", "desc": "Collect 500 gold total",
     "check": lambda p, g: g.save["gold"] + p.gold >= 500},
]


class AchievementPopup:
    def __init__(self, name):
        self.name = name
        self.timer = 180
        self.y_offset = -40

    def update(self):
        self.timer -= 1
        if self.y_offset < 0:
            self.y_offset += 3

    def draw(self, surface):
        if self.timer <= 0:
            return
        alpha = min(1.0, self.timer / 30)
        y = 80 + int(self.y_offset)
        w, h = 280, 40
        x = SCREEN_W // 2 - w // 2
        bg = pygame.Surface((w, h), pygame.SRCALPHA)
        bg.fill((40, 40, 60, int(200 * alpha)))
        surface.blit(bg, (x, y))
        pygame.draw.rect(surface, GOLD, (x, y, w, h), 2)
        c = tuple(int(ch * alpha) for ch in GOLD)
        draw_text(surface, f"Achievement: {self.name}", 16,
                  SCREEN_W // 2, y + 20, c, center=True)


# ===========================================================================
# Section 10: Power-ups
# ===========================================================================
POWERUPS = [
    {"name": "Damage Up", "desc": "+30% projectile damage", "color": RED,
     "apply": lambda p: setattr(p, "proj_damage", int(p.proj_damage * 1.3))},
    {"name": "Speed Up", "desc": "+15% movement speed", "color": CYAN,
     "apply": lambda p: setattr(p, "speed", p.speed * 1.15)},
    {"name": "Multi-Shot", "desc": "+1 projectile", "color": ORANGE,
     "apply": lambda p: setattr(p, "proj_count", p.proj_count + 1)},
    {"name": "Fire Rate", "desc": "Shoot 25% faster", "color": YELLOW,
     "apply": lambda p: setattr(p, "proj_cooldown", max(5, int(p.proj_cooldown * 0.75)))},
    {"name": "Max HP Up", "desc": "+30 max HP & heal", "color": GREEN,
     "apply": lambda p: (setattr(p, "max_hp", p.max_hp + 30),
                         setattr(p, "hp", p.max_hp + 30))},
    {"name": "Orbital Blades", "desc": "Spinning blades orbit you", "color": CYAN,
     "apply": lambda p: setattr(p, "has_orbit", True),
     "condition": lambda p: not p.has_orbit},
    {"name": "Orbit+", "desc": "+2 blades, wider radius", "color": CYAN,
     "apply": lambda p: (setattr(p, "orbit_count", p.orbit_count + 2),
                         setattr(p, "orbit_radius", p.orbit_radius + 15)),
     "condition": lambda p: p.has_orbit},
    {"name": "Damage Aura", "desc": "Hurt nearby enemies", "color": PURPLE,
     "apply": lambda p: setattr(p, "has_aura", True),
     "condition": lambda p: not p.has_aura},
    {"name": "Aura+", "desc": "Bigger & stronger aura", "color": PURPLE,
     "apply": lambda p: (setattr(p, "aura_radius", p.aura_radius + 25),
                         setattr(p, "aura_damage", p.aura_damage + 5)),
     "condition": lambda p: p.has_aura},
    {"name": "Lightning", "desc": "Chain lightning weapon", "color": CYAN,
     "apply": lambda p: setattr(p, "weapon", "lightning"),
     "condition": lambda p: p.weapon != "lightning"},
    {"name": "Boomerang", "desc": "Returning blade weapon", "color": TEAL,
     "apply": lambda p: setattr(p, "weapon", "boomerang"),
     "condition": lambda p: p.weapon != "boomerang"},
    {"name": "Explosion", "desc": "Periodic AoE blast", "color": ORANGE,
     "apply": lambda p: setattr(p, "has_explosion", True),
     "condition": lambda p: not p.has_explosion},
    {"name": "Explosion+", "desc": "Bigger blast, more damage", "color": ORANGE,
     "apply": lambda p: (setattr(p, "explosion_radius", p.explosion_radius + 30),
                         setattr(p, "explosion_damage", p.explosion_damage + 15)),
     "condition": lambda p: p.has_explosion},
    {"name": "XP Magnet", "desc": "Double gem attract range", "color": GREEN,
     "apply": lambda p: None, "special": "magnet"},
]


def pick_powerups(player, count=3):
    available = [p for p in POWERUPS
                 if p.get("condition", lambda _: True)(player)]
    return random.sample(available, min(count, len(available)))


# ===========================================================================
# Section 11: Upgrade Shop
# ===========================================================================
SHOP_ITEMS = [
    {"key": "max_hp", "name": "Vitality", "desc": "+10 starting HP",
     "base_cost": 30, "color": GREEN},
    {"key": "damage", "name": "Power", "desc": "+5 base damage",
     "base_cost": 40, "color": RED},
    {"key": "speed", "name": "Agility", "desc": "+0.2 move speed",
     "base_cost": 35, "color": CYAN},
    {"key": "xp_bonus", "name": "Wisdom", "desc": "+10% XP gain",
     "base_cost": 50, "color": PURPLE},
]


def get_upgrade_cost(item, level):
    return item["base_cost"] + level * 20


# ===========================================================================
# Section 12: Main Game
# ===========================================================================
class Game:
    def __init__(self):
        pygame.init()
        self.save = load_save()
        self.fullscreen = self.save["settings"]["fullscreen"]
        flags = pygame.FULLSCREEN if self.fullscreen else 0
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H), flags)
        pygame.display.set_caption("BOATRY McBOATERSON")
        load_sprites()
        self.clock = pygame.time.Clock()
        self.sound = SoundManager()
        self.sound.set_volume(self.save["settings"]["sfx_volume"])
        self.particles = ParticleSystem()
        self.shake = ScreenShake()
        self.state = "menu"
        self.char_idx = 0
        self.show_fps = False
        self.achievement_popups = []
        self.gem_attract_range = GEM_ATTRACT_DIST
        self.menu_selection = 0
        self.settings_selection = 0
        self.shop_selection = 0
        # Auto-update check (runs in background thread)
        self.update_available = None  # (version, url) or None
        self.update_status = ""  # "", "checking", "downloading", "ready", "failed"
        if HAS_UPDATER:
            self.update_status = "checking"
            threading.Thread(target=self._check_update, daemon=True).start()
        self.reset()

    def _check_update(self):
        ver, url = check_for_update()
        if ver:
            self.update_available = (ver, url)
            self.update_status = "available"
        else:
            self.update_status = ""

    def _do_update(self):
        if not self.update_available:
            return
        ver, url = self.update_available
        self.update_status = "downloading"
        if download_and_apply_update(ver, url):
            self.update_status = "ready"
        else:
            self.update_status = "failed"

    def reset(self):
        self.player = Player(self.char_idx, self.save["upgrades"])
        self.enemies = []
        self.projectiles = []
        self.boomerangs = []
        self.lightnings = []
        self.explosions = []
        self.gems = []
        self.health_pickups = []
        self.chests = []
        self.dmg_numbers = []
        self.wave = 0
        self.wave_timer = 0
        self.spawn_timer = 0
        self.spawn_rate = INITIAL_SPAWN_RATE
        self.game_time = 0
        self.pending_powerups = []
        self.cam_x = self.cam_y = 0
        self.bosses_killed = 0
        self.boss_spawned_this_wave = False
        self.chest_timer = 0
        self.gem_attract_range = GEM_ATTRACT_DIST
        self.new_achievements = []
        self.ember_timer = 0

    def toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        flags = pygame.FULLSCREEN if self.fullscreen else 0
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H), flags)
        self.save["settings"]["fullscreen"] = self.fullscreen
        save_game(self.save)

    # ----- achievement checking -----
    def check_achievements(self):
        for ach in ACHIEVEMENT_DEFS:
            if ach["id"] not in self.save["achievements"]:
                if ach["check"](self.player, self):
                    self.save["achievements"].append(ach["id"])
                    self.achievement_popups.append(AchievementPopup(ach["name"]))
                    self.sound.play("achievement")
                    self.new_achievements.append(ach["id"])

    # ----- spawning -----
    def spawn_enemy(self):
        angle = random.uniform(0, 2 * math.pi)
        d = random.uniform(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
        x = clamp(self.player.x + math.cos(angle) * d, 0, WORLD_W)
        y = clamp(self.player.y + math.sin(angle) * d, 0, WORLD_H)
        self.enemies.append(Enemy(x, y, self.wave))

    def spawn_boss(self):
        angle = random.uniform(0, 2 * math.pi)
        x = clamp(self.player.x + math.cos(angle) * 500, 50, WORLD_W - 50)
        y = clamp(self.player.y + math.sin(angle) * 500, 50, WORLD_H - 50)
        self.enemies.append(Boss(x, y, self.wave))
        self.sound.play("boss_roar")
        self.shake.shake(10)

    def spawn_chest(self):
        angle = random.uniform(0, 2 * math.pi)
        d = random.uniform(100, 300)
        x = clamp(self.player.x + math.cos(angle) * d, 50, WORLD_W - 50)
        y = clamp(self.player.y + math.sin(angle) * d, 50, WORLD_H - 50)
        self.chests.append(TreasureChest(x, y))

    # ----- weapons -----
    def fire_weapons(self):
        p = self.player
        if not self.enemies:
            return

        nearest = min(self.enemies,
                      key=lambda e: dist((e.x, e.y), (p.x, p.y)))
        base_angle = angle_to((p.x, p.y), (nearest.x, nearest.y))

        if p.weapon == "projectile" and p.cooldown_timer <= 0:
            spread = 0.15
            for i in range(p.proj_count):
                offset = (i - (p.proj_count - 1) / 2) * spread
                self.projectiles.append(
                    Projectile(p.x, p.y, base_angle + offset,
                               p.proj_speed, p.proj_damage))
            p.cooldown_timer = p.proj_cooldown
            self.sound.play("shoot")

        if p.weapon == "lightning" and p.lightning_timer <= 0:
            targets = []
            hit = set()
            cx, cy = p.x, p.y
            for _ in range(p.lightning_chains):
                best, best_d = None, p.lightning_range
                for e in self.enemies:
                    if id(e) in hit:
                        continue
                    d2 = dist((cx, cy), (e.x, e.y))
                    if d2 < best_d:
                        best, best_d = e, d2
                if best:
                    targets.append((best.x, best.y))
                    hit.add(id(best))
                    best.hp -= p.proj_damage
                    best.hit_flash = 4
                    self.dmg_numbers.append(
                        DamageNumber(best.x, best.y - 10, p.proj_damage, CYAN))
                    self.particles.emit(best.x, best.y, CYAN, 5, 2, 10, 2, glow=True)
                    if best.hp <= 0:
                        self._kill_enemy(best)
                    cx, cy = best.x, best.y
                else:
                    break
            if targets:
                self.lightnings.append(LightningBolt(p.x, p.y, targets, p.proj_damage))
                p.lightning_timer = p.lightning_cooldown
                self.sound.play("lightning")

        if p.weapon == "boomerang" and p.boomerang_timer <= 0:
            for i in range(p.boomerang_count):
                offset = (i - (p.boomerang_count - 1) / 2) * 0.3
                self.boomerangs.append(
                    Boomerang(p.x, p.y, base_angle + offset, 6,
                              p.proj_damage, [p.x, p.y]))
            p.boomerang_timer = p.boomerang_cooldown
            self.sound.play("boomerang")

        if p.has_explosion and p.explosion_timer <= 0:
            self.explosions.append(
                ExplosionEffect(p.x, p.y, p.explosion_radius, p.explosion_damage))
            self.sound.play("explosion")
            self.shake.shake(6)
            self.particles.emit(p.x, p.y, ORANGE, 20, 5, 25, 4, glow=True)
            for e in self.enemies[:]:
                if dist((p.x, p.y), (e.x, e.y)) < p.explosion_radius + e.radius:
                    e.hp -= p.explosion_damage
                    e.hit_flash = 4
                    self.dmg_numbers.append(
                        DamageNumber(e.x, e.y - 10, p.explosion_damage, ORANGE))
                    if e.hp <= 0:
                        self._kill_enemy(e)
            p.explosion_timer = p.explosion_cooldown

    def _kill_enemy(self, enemy):
        if enemy not in self.enemies:
            return
        self.gems.append(Gem(enemy.x, enemy.y, enemy.xp_value))
        self.player.gold += enemy.gold_value
        self.particles.emit(enemy.x, enemy.y, enemy.color, 12, 4, 20, 3)
        if random.random() < enemy.drop_chance:
            self.health_pickups.append(
                HealthPickup(enemy.x, enemy.y, 15 + self.wave * 2))
        if enemy.is_boss:
            self.bosses_killed += 1
            self.shake.shake(15)
            self.particles.emit(enemy.x, enemy.y, GOLD, 30, 6, 30, 5, glow=True)
            self.sound.play("explosion")
        else:
            self.sound.play("kill")
        self.enemies.remove(enemy)
        self.player.kills += 1

    # ----- collisions -----
    def check_collisions(self):
        p = self.player

        for proj in self.projectiles[:]:
            for enemy in self.enemies[:]:
                if dist((proj.x, proj.y), (enemy.x, enemy.y)) < proj.radius + enemy.radius:
                    enemy.hp -= proj.damage
                    enemy.hit_flash = 4
                    self.dmg_numbers.append(
                        DamageNumber(enemy.x, enemy.y - 10, proj.damage, YELLOW))
                    self.particles.emit(proj.x, proj.y, YELLOW, 4, 2, 10, 2)
                    self.sound.play("hit")
                    if proj in self.projectiles:
                        self.projectiles.remove(proj)
                    if enemy.hp <= 0:
                        self._kill_enemy(enemy)
                    break

        for boom in self.boomerangs[:]:
            for enemy in self.enemies[:]:
                if id(enemy) in boom.hit_enemies:
                    continue
                if dist((boom.x, boom.y), (enemy.x, enemy.y)) < boom.radius + enemy.radius:
                    enemy.hp -= boom.damage
                    enemy.hit_flash = 4
                    boom.hit_enemies.add(id(enemy))
                    self.dmg_numbers.append(
                        DamageNumber(enemy.x, enemy.y - 10, boom.damage, TEAL))
                    self.particles.emit(boom.x, boom.y, TEAL, 3, 2, 8, 2)
                    self.sound.play("hit")
                    if enemy.hp <= 0:
                        self._kill_enemy(enemy)

        if p.has_orbit:
            for i in range(p.orbit_count):
                a = p.orbit_angle + (2 * math.pi * i / p.orbit_count)
                ox = p.x + math.cos(a) * p.orbit_radius
                oy = p.y + math.sin(a) * p.orbit_radius
                for enemy in self.enemies[:]:
                    if dist((ox, oy), (enemy.x, enemy.y)) < 8 + enemy.radius:
                        enemy.hp -= p.orbit_damage
                        enemy.hit_flash = 4
                        self.dmg_numbers.append(
                            DamageNumber(enemy.x, enemy.y - 10, p.orbit_damage, CYAN))
                        if enemy.hp <= 0:
                            self._kill_enemy(enemy)

        if p.has_aura and p.aura_tick % 15 == 0:
            for enemy in self.enemies[:]:
                if dist((p.x, p.y), (enemy.x, enemy.y)) < p.aura_radius + enemy.radius:
                    enemy.hp -= p.aura_damage
                    enemy.hit_flash = 3
                    if enemy.hp <= 0:
                        self._kill_enemy(enemy)

        for enemy in self.enemies:
            if dist((enemy.x, enemy.y), (p.x, p.y)) < enemy.radius + p.radius:
                if p.invuln_timer <= 0:
                    p.hp -= enemy.damage
                    p.invuln_timer = INVULN_TIME
                    self.dmg_numbers.append(
                        DamageNumber(p.x, p.y - 20, enemy.damage, RED))
                    self.particles.emit(p.x, p.y, RED, 8, 3, 15, 2)
                    self.sound.play("hurt")
                    self.shake.shake(5)
                    if p.hp <= 0:
                        self.end_run()

        for gem in self.gems[:]:
            if dist((gem.x, gem.y), (p.x, p.y)) < gem.radius + p.radius + 10:
                leveled = p.gain_xp(gem.value)
                self.gems.remove(gem)
                self.sound.play("gem")
                self.particles.emit(gem.x, gem.y, GREEN, 4, 2, 8, 2)
                if leveled:
                    p.powerups_chosen += 1
                    self.pending_powerups = pick_powerups(p)
                    self.state = "levelup"
                    self.sound.play("levelup")

        for hp_item in self.health_pickups[:]:
            if dist((hp_item.x, hp_item.y), (p.x, p.y)) < hp_item.radius + p.radius + 10:
                p.hp = min(p.max_hp, p.hp + hp_item.heal)
                self.health_pickups.remove(hp_item)
                self.sound.play("heal")
                self.dmg_numbers.append(
                    DamageNumber(p.x, p.y - 20, f"+{hp_item.heal}", GREEN))
                self.particles.emit(hp_item.x, hp_item.y, GREEN, 6, 2, 12, 2, glow=True)

        for chest in self.chests[:]:
            if dist((chest.x, chest.y), (p.x, p.y)) < chest.radius + p.radius + 10:
                self.chests.remove(chest)
                self.sound.play("chest")
                self.particles.emit(chest.x, chest.y, GOLD, 15, 4, 20, 3, glow=True)
                reward = random.choice(["heal", "gold", "powerup"])
                if reward == "heal":
                    p.hp = min(p.max_hp, p.hp + 50)
                    self.dmg_numbers.append(
                        DamageNumber(chest.x, chest.y - 20, "+50 HP", GREEN))
                elif reward == "gold":
                    bonus = 20 + self.wave * 5
                    p.gold += bonus
                    self.dmg_numbers.append(
                        DamageNumber(chest.x, chest.y - 20, f"+{bonus}g", GOLD))
                else:
                    self.pending_powerups = pick_powerups(p)
                    if self.pending_powerups:
                        self.state = "levelup"

    def end_run(self):
        self.save["gold"] += self.player.gold
        self.save["total_kills"] += self.player.kills
        self.save["total_runs"] += 1
        minutes = int(self.game_time) // 60
        seconds = int(self.game_time) % 60
        entry = {
            "time": f"{minutes:02d}:{seconds:02d}",
            "kills": self.player.kills,
            "level": self.player.level,
            "wave": self.wave + 1,
            "character": CHARACTERS[self.char_idx]["name"],
        }
        self.save["high_scores"].append(entry)
        self.save["high_scores"].sort(key=lambda s: s["kills"], reverse=True)
        self.save["high_scores"] = self.save["high_scores"][:10]
        save_game(self.save)
        self.state = "gameover"

    # ----- update -----
    def update(self):
        if self.state != "playing":
            return
        keys = pygame.key.get_pressed()
        p = self.player
        p.update(keys)

        for b in self.boomerangs:
            b.owner_ref[0] = p.x
            b.owner_ref[1] = p.y

        self.cam_x = p.x - SCREEN_W / 2 + self.shake.offset_x
        self.cam_y = p.y - SCREEN_H / 2 + self.shake.offset_y
        self.shake.update()

        self.game_time += 1 / FPS
        self.wave_timer += 1 / FPS
        if self.wave_timer >= WAVE_DURATION:
            self.wave_timer = 0
            self.wave += 1
            self.spawn_rate = max(MIN_SPAWN_RATE,
                                  int(INITIAL_SPAWN_RATE * (0.9 ** self.wave)))
            self.boss_spawned_this_wave = False

        if (self.wave > 0 and self.wave % BOSS_WAVE_INTERVAL == 0
                and not self.boss_spawned_this_wave):
            self.spawn_boss()
            self.boss_spawned_this_wave = True

        self.spawn_timer += 1
        if self.spawn_timer >= self.spawn_rate:
            self.spawn_timer = 0
            for _ in range(1 + self.wave // 3):
                self.spawn_enemy()

        self.chest_timer += 1
        if self.chest_timer >= FPS * 45:
            self.chest_timer = 0
            self.spawn_chest()

        self.fire_weapons()

        for proj in self.projectiles[:]:
            proj.update()
            if proj.life <= 0:
                self.projectiles.remove(proj)
        for boom in self.boomerangs[:]:
            boom.update()
            if boom.returned:
                self.boomerangs.remove(boom)
        for ln in self.lightnings[:]:
            ln.update()
            if ln.life <= 0:
                self.lightnings.remove(ln)
        for ex in self.explosions[:]:
            ex.update()
            if ex.life <= 0:
                self.explosions.remove(ex)
        for enemy in self.enemies:
            enemy.update(p.x, p.y)
        for gem in self.gems:
            gem.update(p.x, p.y, self.gem_attract_range)
        for hp_item in self.health_pickups:
            hp_item.update()
        for ch in self.chests:
            ch.update()
        for dn in self.dmg_numbers[:]:
            dn.update()
            if dn.timer <= 0:
                self.dmg_numbers.remove(dn)
        self.particles.update()
        # Ambient embers (atmospheric fire particles)
        self.ember_timer += 1
        if self.ember_timer % 3 == 0:
            ex = p.x + random.uniform(-SCREEN_W * 0.6, SCREEN_W * 0.6)
            ey = p.y + random.uniform(-SCREEN_H * 0.6, SCREEN_H * 0.6)
            ec = random.choice([FIRE_BRIGHT, FIRE_MID, EMBER_COLOR, (255, 200, 60)])
            self.particles.particles.append(
                Particle(ex, ey, random.uniform(-0.3, 0.3), random.uniform(-1.5, -0.5),
                         ec, life=random.randint(30, 60), size=random.randint(1, 3),
                         shrink=True, glow=True))
        for ap in self.achievement_popups[:]:
            ap.update()
            if ap.timer <= 0:
                self.achievement_popups.remove(ap)

        self.check_collisions()
        self.check_achievements()

    # ----- drawing -----
    def draw_ground(self):
        # Dark atmospheric ocean
        self.screen.fill(OCEAN_DEEP)
        start_x = int(self.cam_x // TILE_SIZE) * TILE_SIZE
        start_y = int(self.cam_y // TILE_SIZE) * TILE_SIZE
        t = pygame.time.get_ticks() / 1000.0
        for tx in range(start_x, start_x + SCREEN_W + TILE_SIZE * 2, TILE_SIZE):
            for ty in range(start_y, start_y + SCREEN_H + TILE_SIZE * 2, TILE_SIZE):
                sx = tx - self.cam_x
                sy = ty - self.cam_y
                wave = math.sin(tx * 0.008 + t * 0.5) * 0.5 + 0.5
                wave2 = math.sin(ty * 0.006 + t * 0.4 + 1.5) * 0.5 + 0.5
                wave3 = math.sin((tx + ty) * 0.005 + t * 0.3) * 0.5 + 0.5
                blend = (wave + wave2 + wave3) / 3
                r = int(8 + blend * 12)
                g = int(14 + blend * 18)
                b = int(30 + blend * 30)
                color = (r, g, b)
                pygame.draw.rect(self.screen, color,
                                 (sx, sy, TILE_SIZE, TILE_SIZE))
                # Subtle wave highlight on peaks
                if blend > 0.65:
                    foam_a = int((blend - 0.65) / 0.35 * 20)
                    foam = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
                    foam.fill((60, 90, 130, foam_a))
                    self.screen.blit(foam, (sx, sy))

        # Floating debris: wood planks, barrels, seaweed (deterministic positions)
        random.seed(1337)
        for _ in range(60):
            dx = random.randint(0, WORLD_W)
            dy = random.randint(0, WORLD_H)
            dtype = random.choice(["plank", "plank", "plank", "barrel", "seaweed", "seaweed", "crate"])
            dsx = dx - self.cam_x
            dsy = dy - self.cam_y + math.sin(t * 0.4 + dx * 0.005) * 4
            if -40 < dsx < SCREEN_W + 40 and -40 < dsy < SCREEN_H + 40:
                dsx_i, dsy_i = int(dsx), int(dsy)
                if dtype == "plank":
                    rot = math.sin(dx * 0.01 + t * 0.2) * 0.3
                    w, h = random.randint(20, 36), random.randint(5, 8)
                    plank = pygame.Surface((w, h), pygame.SRCALPHA)
                    c1 = (60 + random.randint(0, 30), 40 + random.randint(0, 20),
                          20 + random.randint(0, 15))
                    c2 = tuple(max(0, c - 15) for c in c1)
                    plank.fill((*c1, 120))
                    pygame.draw.line(plank, (*c2, 140), (2, h // 2), (w - 2, h // 2), 1)
                    pygame.draw.rect(plank, (*c2, 80), (0, 0, w, h), 1)
                    rotated = pygame.transform.rotate(plank, math.degrees(rot))
                    self.screen.blit(rotated, (dsx_i - rotated.get_width() // 2,
                                                dsy_i - rotated.get_height() // 2))
                elif dtype == "barrel":
                    bs = pygame.Surface((14, 16), pygame.SRCALPHA)
                    pygame.draw.ellipse(bs, (80, 55, 30, 110), (0, 0, 14, 16))
                    pygame.draw.ellipse(bs, (60, 40, 20, 80), (0, 0, 14, 16), 1)
                    pygame.draw.line(bs, (90, 70, 40, 120), (1, 5), (13, 5), 1)
                    pygame.draw.line(bs, (90, 70, 40, 120), (1, 11), (13, 11), 1)
                    self.screen.blit(bs, (dsx_i - 7, dsy_i - 8))
                elif dtype == "seaweed":
                    sw = math.sin(t * 1.5 + dx * 0.02) * 6
                    for seg in range(3):
                        sx_s = dsx_i + int(sw * seg * 0.4)
                        sy_s = dsy_i - seg * 5
                        ss = pygame.Surface((8, 7), pygame.SRCALPHA)
                        gc = (20 + random.randint(0, 20), 60 + random.randint(0, 30),
                              15 + random.randint(0, 10))
                        pygame.draw.ellipse(ss, (*gc, 80), (0, 0, 8, 7))
                        self.screen.blit(ss, (sx_s - 4, sy_s))
                elif dtype == "crate":
                    cs = pygame.Surface((12, 12), pygame.SRCALPHA)
                    cs.fill((70, 50, 25, 100))
                    pygame.draw.rect(cs, (50, 35, 15, 120), (0, 0, 12, 12), 1)
                    pygame.draw.line(cs, (50, 35, 15, 100), (0, 0), (12, 12), 1)
                    pygame.draw.line(cs, (50, 35, 15, 100), (12, 0), (0, 12), 1)
                    self.screen.blit(cs, (dsx_i - 6, dsy_i - 6))
        random.seed()

    def draw_minimap(self):
        mm = pygame.Surface((MINIMAP_SIZE, MINIMAP_SIZE), pygame.SRCALPHA)
        mm.fill((0, 0, 0, 140))
        sx = MINIMAP_SIZE / WORLD_W
        sy = MINIMAP_SIZE / WORLD_H
        pygame.draw.circle(mm, WHITE,
                           (int(self.player.x * sx), int(self.player.y * sy)), 3)
        for e in self.enemies:
            c = GOLD if e.is_boss else RED
            sz = 2 if e.is_boss else 1
            pygame.draw.circle(mm, c, (int(e.x * sx), int(e.y * sy)), sz)
        for ch in self.chests:
            pygame.draw.circle(mm, GOLD, (int(ch.x * sx), int(ch.y * sy)), 2)
        # Gold ornate border
        pygame.draw.rect(mm, (120, 90, 30), (0, 0, MINIMAP_SIZE, MINIMAP_SIZE), 2)
        pygame.draw.rect(mm, GOLD, (1, 1, MINIMAP_SIZE - 2, MINIMAP_SIZE - 2), 1)
        self.screen.blit(mm, (SCREEN_W - MINIMAP_SIZE - MINIMAP_MARGIN,
                              SCREEN_H - MINIMAP_SIZE - MINIMAP_MARGIN))

    def draw_hud(self):
        p = self.player
        t = pygame.time.get_ticks() / 1000.0

        # === TOP-LEFT: Level & stats panel ===
        panel_h = 95  # taller panel for weapon icons
        left_panel = pygame.Surface((230, panel_h), pygame.SRCALPHA)
        left_panel.fill((0, 0, 0, 140))
        self.screen.blit(left_panel, (5, 5))
        pygame.draw.rect(self.screen, (80, 60, 30), (5, 5, 230, panel_h), 2)

        # XP bar (thin, glowing)
        xp_ratio = p.xp / p.xp_to_next
        pygame.draw.rect(self.screen, (20, 15, 30), (12, 12, 214, 12))
        xp_w = int(214 * xp_ratio)
        pygame.draw.rect(self.screen, (40, 100, 220), (12, 12, xp_w, 12))
        pygame.draw.rect(self.screen, (60, 130, 255), (12, 12, xp_w, 4))
        pygame.draw.rect(self.screen, (100, 80, 40), (12, 12, 214, 12), 1)
        draw_text(self.screen, f"Lv {p.level}", 14, 16, 10, GOLD)

        # Gold (with coin icon)
        pygame.draw.circle(self.screen, GOLD, (24, 38), 7)
        pygame.draw.circle(self.screen, (200, 160, 30), (24, 38), 7, 1)
        draw_text(self.screen, "$", 10, 24, 38, (120, 80, 20), center=True)
        draw_text(self.screen, f"{p.gold}", 16, 36, 30, GOLD)

        # Weapon icons row (like VS: small icons showing equipped abilities)
        icon_y = 52
        icon_x = 14
        # Main weapon icon
        wc = {
            "projectile": (255, 200, 60),
            "lightning": (60, 200, 255),
            "boomerang": (0, 170, 170),
        }.get(p.weapon, WHITE)
        # Weapon icon box
        pygame.draw.rect(self.screen, (30, 25, 40), (icon_x, icon_y, 22, 22))
        pygame.draw.rect(self.screen, wc, (icon_x, icon_y, 22, 22), 1)
        if p.weapon == "projectile":
            pygame.draw.circle(self.screen, wc, (icon_x + 11, icon_y + 11), 6)
            pygame.draw.circle(self.screen, WHITE, (icon_x + 11, icon_y + 11), 3)
        elif p.weapon == "lightning":
            pygame.draw.polygon(self.screen, wc, [
                (icon_x + 9, icon_y + 3), (icon_x + 5, icon_y + 12),
                (icon_x + 10, icon_y + 12), (icon_x + 13, icon_y + 19),
                (icon_x + 17, icon_y + 10), (icon_x + 12, icon_y + 10)])
        elif p.weapon == "boomerang":
            pygame.draw.arc(self.screen, wc,
                            (icon_x + 3, icon_y + 3, 16, 16), 0.5, 4.5, 3)
        icon_x += 26

        # Extra ability icons
        if p.has_orbit:
            pygame.draw.rect(self.screen, (30, 25, 40), (icon_x, icon_y, 22, 22))
            pygame.draw.rect(self.screen, CYAN, (icon_x, icon_y, 22, 22), 1)
            pygame.draw.circle(self.screen, CYAN, (icon_x + 11, icon_y + 11), 7, 2)
            pygame.draw.circle(self.screen, CYAN, (icon_x + 11, icon_y + 5), 3)
            icon_x += 26
        if p.has_aura:
            pygame.draw.rect(self.screen, (30, 25, 40), (icon_x, icon_y, 22, 22))
            pygame.draw.rect(self.screen, PURPLE, (icon_x, icon_y, 22, 22), 1)
            pygame.draw.circle(self.screen, PURPLE, (icon_x + 11, icon_y + 11), 8, 2)
            pygame.draw.circle(self.screen, PURPLE, (icon_x + 11, icon_y + 11), 4, 1)
            icon_x += 26
        if p.has_explosion:
            pygame.draw.rect(self.screen, (30, 25, 40), (icon_x, icon_y, 22, 22))
            pygame.draw.rect(self.screen, ORANGE, (icon_x, icon_y, 22, 22), 1)
            for ei in range(5):
                ea = ei * math.pi * 2 / 5
                ex_i = icon_x + 11 + int(math.cos(ea) * 6)
                ey_i = icon_y + 11 + int(math.sin(ea) * 6)
                pygame.draw.circle(self.screen, ORANGE, (ex_i, ey_i), 2)
            pygame.draw.circle(self.screen, FIRE_BRIGHT, (icon_x + 11, icon_y + 11), 3)
            icon_x += 26

        # Dash hint
        draw_text(self.screen, "SPACE=dash", 10, 14, 80, GRAY)

        # === TOP-RIGHT: Timer & wave ===
        right_panel = pygame.Surface((160, 70), pygame.SRCALPHA)
        right_panel.fill((0, 0, 0, 140))
        self.screen.blit(right_panel, (SCREEN_W - 165, 5))
        pygame.draw.rect(self.screen, (80, 60, 30), (SCREEN_W - 165, 5, 160, 70), 2)

        minutes = int(self.game_time) // 60
        seconds = int(self.game_time) % 60
        draw_text(self.screen, f"{minutes:02d}:{seconds:02d}", 24,
                  SCREEN_W - 155, 10, GOLD)
        draw_text(self.screen, f"Wave {self.wave + 1}", 18,
                  SCREEN_W - 155, 36, WHITE)
        draw_text(self.screen, f"Kills {p.kills}", 14,
                  SCREEN_W - 155, 56, LIGHT_GRAY)

        # === BOTTOM: Large ornate health bar ===
        bar_w = 400
        bar_h = 24
        bar_x = SCREEN_W // 2 - bar_w // 2
        bar_y = SCREEN_H - 40
        # Background panel
        bg_panel = pygame.Surface((bar_w + 60, bar_h + 16), pygame.SRCALPHA)
        bg_panel.fill((0, 0, 0, 160))
        self.screen.blit(bg_panel, (bar_x - 30, bar_y - 8))
        # HP bar background
        pygame.draw.rect(self.screen, (30, 8, 8), (bar_x, bar_y, bar_w, bar_h))
        # HP fill
        hp_ratio = max(0, p.hp / p.max_hp)
        fill_w = int(bar_w * hp_ratio)
        # Gradient red fill
        for i in range(fill_w):
            ratio_i = i / bar_w
            r = int(180 + 40 * math.sin(ratio_i * 6 + t * 3))
            g = int(20 + 15 * ratio_i)
            b = int(10 + 10 * ratio_i)
            pygame.draw.line(self.screen, (min(255, r), g, b),
                             (bar_x + i, bar_y + 2),
                             (bar_x + i, bar_y + bar_h - 2))
        # Bright highlight on top of HP bar
        if fill_w > 0:
            hl = pygame.Surface((fill_w, 4), pygame.SRCALPHA)
            hl.fill((255, 255, 255, 30))
            self.screen.blit(hl, (bar_x, bar_y + 2))
        # Border (ornate gold)
        pygame.draw.rect(self.screen, GOLD, (bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), 3)
        # Corner ornaments
        for cx, cy in [(bar_x - 6, bar_y + bar_h // 2),
                       (bar_x + bar_w + 6, bar_y + bar_h // 2)]:
            pygame.draw.polygon(self.screen, GOLD, [
                (cx - 6, cy), (cx, cy - 6), (cx + 6, cy), (cx, cy + 6)])
        # HP text
        draw_text(self.screen, f"{p.hp}/{p.max_hp}", 16,
                  SCREEN_W // 2, bar_y + bar_h // 2, WHITE, center=True)

        # FPS counter
        if self.show_fps:
            draw_text(self.screen, f"FPS: {int(self.clock.get_fps())}", 14,
                      SCREEN_W - 80, SCREEN_H - 60, LIGHT_GRAY)

        self.draw_minimap()

        # === VIGNETTE (dark edges for atmosphere) ===
        vig = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        # Top and bottom gradient bars
        for i in range(80):
            a = int(120 * (1 - i / 80))
            pygame.draw.line(vig, (0, 0, 0, a), (0, i), (SCREEN_W, i))
            pygame.draw.line(vig, (0, 0, 0, a),
                             (0, SCREEN_H - 1 - i), (SCREEN_W, SCREEN_H - 1 - i))
        # Left and right
        for i in range(60):
            a = int(80 * (1 - i / 60))
            pygame.draw.line(vig, (0, 0, 0, a), (i, 0), (i, SCREEN_H))
            pygame.draw.line(vig, (0, 0, 0, a),
                             (SCREEN_W - 1 - i, 0), (SCREEN_W - 1 - i, SCREEN_H))
        self.screen.blit(vig, (0, 0))

    def draw_menu(self):
        self.screen.fill(OCEAN_DEEP)
        t = pygame.time.get_ticks() / 1000.0
        # Animated background waves
        for y in range(0, SCREEN_H, 40):
            wave = math.sin(y * 0.02 + t * 0.5) * 0.5 + 0.5
            c = (int(8 + wave * 8), int(12 + wave * 12), int(28 + wave * 20))
            pygame.draw.rect(self.screen, c, (0, y, SCREEN_W, 40))
        # Ember particles on menu
        for i in range(30):
            ex = int((i * 97 + t * 20 * (1 + i % 3)) % SCREEN_W)
            ey = int(SCREEN_H - (i * 43 + t * 40 * (1 + i % 2)) % (SCREEN_H + 100))
            ea = max(0, min(180, 180 - abs(ey - SCREEN_H // 2)))
            es = pygame.Surface((4, 4), pygame.SRCALPHA)
            ec = random.choice([(255, 160, 30), (255, 100, 20), (255, 200, 60)])
            pygame.draw.circle(es, (*ec, ea), (2, 2), 2)
            self.screen.blit(es, (ex, ey))
        # Title with glow
        glow_s = pygame.Surface((500, 100), pygame.SRCALPHA)
        gi = int(40 + 20 * math.sin(t * 2))
        pygame.draw.ellipse(glow_s, (255, 150, 30, gi), (50, 10, 400, 80))
        self.screen.blit(glow_s, (SCREEN_W // 2 - 250, 60))
        # Title text with outline
        for ox, oy in [(-3, -3), (3, -3), (-3, 3), (3, 3)]:
            draw_text(self.screen, "BOATRY", 64,
                      SCREEN_W // 2 + ox, 100 + oy, (40, 20, 10), center=True)
        draw_text(self.screen, "BOATRY", 64, SCREEN_W // 2, 100, GOLD, center=True)
        for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            draw_text(self.screen, "McBOATERSON", 40,
                      SCREEN_W // 2 + ox, 155 + oy, (20, 10, 5), center=True)
        draw_text(self.screen, "McBOATERSON", 40,
                  SCREEN_W // 2, 155, WHITE, center=True)
        # Menu items
        items = ["Play", "Characters", "Upgrades", "Achievements",
                 "High Scores", "Settings", "Quit"]
        for i, item in enumerate(items):
            y = 260 + i * 45
            sel = i == self.menu_selection
            color = GOLD if sel else (80, 75, 90)
            prefix = "> " if sel else "  "
            if sel:
                # Selection glow
                gs = pygame.Surface((300, 35), pygame.SRCALPHA)
                gs.fill((255, 150, 30, 20))
                self.screen.blit(gs, (SCREEN_W // 2 - 150, y - 17))
            draw_text(self.screen, f"{prefix}{item}", 24,
                      SCREEN_W // 2, y, color, center=True)
        draw_text(self.screen, "Arrow keys to navigate, Enter to select", 14,
                  SCREEN_W // 2, SCREEN_H - 40, (60, 55, 70), center=True)
        # Update notification
        if self.update_status == "available" and self.update_available:
            ver = self.update_available[0]
            draw_text(self.screen, f"Update v{ver} available! Press U to update", 16,
                      SCREEN_W // 2, SCREEN_H - 65, GREEN, center=True)
        elif self.update_status == "downloading":
            draw_text(self.screen, "Downloading update...", 16,
                      SCREEN_W // 2, SCREEN_H - 65, YELLOW, center=True)
        elif self.update_status == "ready":
            draw_text(self.screen, "Update installed! Restart the game to apply.", 16,
                      SCREEN_W // 2, SCREEN_H - 65, GREEN, center=True)
        elif self.update_status == "failed":
            draw_text(self.screen, "Update failed. Try again later.", 16,
                      SCREEN_W // 2, SCREEN_H - 65, RED, center=True)
        # Version
        if HAS_UPDATER:
            draw_text(self.screen, f"v{get_current_version()}", 12,
                      SCREEN_W - 60, SCREEN_H - 20, GRAY)

    def draw_char_select(self):
        self.screen.fill(OCEAN_DEEP)
        t = pygame.time.get_ticks() / 1000.0
        # Animated bg
        for y in range(0, SCREEN_H, 40):
            wave = math.sin(y * 0.02 + t * 0.3) * 0.5 + 0.5
            c = (int(8 + wave * 6), int(12 + wave * 10), int(28 + wave * 15))
            pygame.draw.rect(self.screen, c, (0, y, SCREEN_W, 40))
        # Ornate title
        for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            draw_text(self.screen, "SELECT YOUR VESSEL", 36,
                      SCREEN_W // 2 + ox, 50 + oy, (40, 20, 10), center=True)
        draw_text(self.screen, "SELECT YOUR VESSEL", 36,
                  SCREEN_W // 2, 50, GOLD, center=True)

        box_w, box_h = 240, 280
        total_w = len(CHARACTERS) * (box_w + 20)
        start_x = SCREEN_W // 2 - total_w // 2 + 10
        for i, ch in enumerate(CHARACTERS):
            bx = start_x + i * (box_w + 20)
            by = 100
            selected = i == self.char_idx

            # Card background
            card = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
            card.fill((15, 10, 25, 220))
            self.screen.blit(card, (bx, by))

            # Border (gold if selected)
            bc = GOLD if selected else (80, 60, 30)
            pygame.draw.rect(self.screen, bc, (bx, by, box_w, box_h), 3)
            pygame.draw.rect(self.screen, (60, 45, 20),
                             (bx + 4, by + 4, box_w - 8, box_h - 8), 1)
            # Color accent strip
            pygame.draw.rect(self.screen, ch["color"],
                             (bx + 6, by + 6, box_w - 12, 4))

            # Draw sprite preview
            cx, cy = bx + box_w // 2, by + 80
            bob = math.sin(t * 2 + i) * 3
            cy_b = int(cy + bob)
            preview_key = CHAR_SPRITE_KEYS[i] + "_preview" if i < len(CHAR_SPRITE_KEYS) else "hero_boat_preview"
            preview = SPRITES.get(preview_key)
            if preview:
                pw, ph = preview.get_size()
                # Shadow
                shadow = pygame.Surface((pw, 10), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow, (0, 0, 0, 30), (0, 0, pw, 10))
                self.screen.blit(shadow, (cx - pw // 2, cy_b + ph // 3))
                self.screen.blit(preview, (cx - pw // 2, cy_b - ph // 2))
            else:
                # Fallback circle
                pygame.draw.circle(self.screen, ch["color"], (cx, cy_b), 20)


            # Selection glow
            if selected:
                gs = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
                gs.fill((255, 200, 60, 10))
                self.screen.blit(gs, (bx, by))

            # Character info
            for ox, oy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
                draw_text(self.screen, ch["name"], 24,
                          bx + box_w // 2 + ox, by + 140 + oy, (10, 5, 5), center=True)
            draw_text(self.screen, ch["name"], 24,
                      bx + box_w // 2, by + 140, ch["color"], center=True)
            draw_text(self.screen, ch["desc"], 13,
                      bx + box_w // 2, by + 170, LIGHT_GRAY, center=True)
            # Stat bars
            stats_y = by + 195
            for label, val, color in [("HP", ch['hp_mod'], RED),
                                       ("SPD", ch['spd_mod'], CYAN),
                                       ("DMG", ch['dmg_mod'], ORANGE)]:
                draw_text(self.screen, label, 11, bx + 15, stats_y, GRAY)
                bar_w_s = int(140 * val)
                pygame.draw.rect(self.screen, (30, 20, 20),
                                 (bx + 50, stats_y + 2, 140, 8))
                pygame.draw.rect(self.screen, color,
                                 (bx + 50, stats_y + 2, bar_w_s, 8))
                pygame.draw.rect(self.screen, (80, 60, 30),
                                 (bx + 50, stats_y + 2, 140, 8), 1)
                stats_y += 18

            draw_text(self.screen, f"Weapon: {ch['weapon'].upper()}", 12,
                      bx + box_w // 2, by + box_h - 30, GOLD, center=True)

        draw_text(self.screen, "Left/Right to choose, Enter to confirm, Esc back",
                  14, SCREEN_W // 2, SCREEN_H - 30, GRAY, center=True)

    def draw_shop(self):
        self.screen.fill(OCEAN_DEEP)
        draw_text(self.screen, "UPGRADES", 36, SCREEN_W // 2, 50, GOLD, center=True)
        draw_text(self.screen, f"Gold: {self.save['gold']}", 22,
                  SCREEN_W // 2, 95, GOLD, center=True)
        for i, item in enumerate(SHOP_ITEMS):
            y = 160 + i * 80
            level = self.save["upgrades"][item["key"]]
            cost = get_upgrade_cost(item, level)
            selected = i == self.shop_selection
            border = WHITE if selected else GRAY
            bx, bw, bh = SCREEN_W // 2 - 200, 400, 65
            pygame.draw.rect(self.screen, (40, 40, 55), (bx, y, bw, bh))
            pygame.draw.rect(self.screen, border, (bx, y, bw, bh),
                             2 if selected else 1)
            draw_text(self.screen, f"{item['name']} (Lv {level})", 20,
                      bx + 15, y + 10, item["color"])
            draw_text(self.screen, item["desc"], 14, bx + 15, y + 36, LIGHT_GRAY)
            cost_color = GREEN if self.save["gold"] >= cost else RED
            draw_text(self.screen, f"Cost: {cost}g", 16,
                      bx + bw - 100, y + 22, cost_color)
        draw_text(self.screen, "Enter to buy, Esc to go back", 14,
                  SCREEN_W // 2, SCREEN_H - 40, GRAY, center=True)

    def draw_achievements(self):
        self.screen.fill(OCEAN_DEEP)
        draw_text(self.screen, "ACHIEVEMENTS", 36,
                  SCREEN_W // 2, 50, GOLD, center=True)
        unlocked = self.save["achievements"]
        y = 120
        for ach in ACHIEVEMENT_DEFS:
            done = ach["id"] in unlocked
            color = GREEN if done else GRAY
            icon = "*" if done else "x"
            draw_text(self.screen, f"[{icon}] {ach['name']}", 18, 200, y, color)
            desc_color = LIGHT_GRAY if done else DARK_GRAY
            draw_text(self.screen, ach["desc"], 14, 500, y + 2, desc_color)
            y += 35
        draw_text(self.screen, f"{len(unlocked)}/{len(ACHIEVEMENT_DEFS)} unlocked",
                  16, SCREEN_W // 2, SCREEN_H - 60, LIGHT_GRAY, center=True)
        draw_text(self.screen, "Esc to go back", 14,
                  SCREEN_W // 2, SCREEN_H - 35, GRAY, center=True)

    def draw_high_scores(self):
        self.screen.fill(OCEAN_DEEP)
        draw_text(self.screen, "HIGH SCORES", 36,
                  SCREEN_W // 2, 50, GOLD, center=True)
        if not self.save["high_scores"]:
            draw_text(self.screen, "No scores yet. Go play!", 20,
                      SCREEN_W // 2, 200, GRAY, center=True)
        else:
            header = f"{'#':<4}{'Char':<10}{'Kills':<10}{'Wave':<8}{'Lv':<8}{'Time':<8}"
            draw_text(self.screen, header, 16, 180, 120, LIGHT_GRAY)
            for i, sc in enumerate(self.save["high_scores"][:10]):
                y = 155 + i * 30
                c = GOLD if i == 0 else (WHITE if i < 3 else LIGHT_GRAY)
                ch_name = sc.get("character", "?")
                row = (f"{i+1:<4}{ch_name:<10}{sc['kills']:<10}"
                       f"{sc['wave']:<8}{sc['level']:<8}{sc['time']:<8}")
                draw_text(self.screen, row, 15, 180, y, c)
        draw_text(self.screen,
                  f"Total runs: {self.save['total_runs']}  |  "
                  f"Total kills: {self.save['total_kills']}",
                  14, SCREEN_W // 2, SCREEN_H - 60, GRAY, center=True)
        draw_text(self.screen, "Esc to go back", 14,
                  SCREEN_W // 2, SCREEN_H - 35, GRAY, center=True)

    def draw_settings(self):
        self.screen.fill(OCEAN_DEEP)
        draw_text(self.screen, "SETTINGS", 36, SCREEN_W // 2, 80, GOLD, center=True)
        items = [
            ("SFX Volume", f"{int(self.save['settings']['sfx_volume'] * 100)}%"),
            ("Fullscreen", "On" if self.fullscreen else "Off"),
            ("FPS Counter (F3)", "On" if self.show_fps else "Off"),
        ]
        for i, (name, val) in enumerate(items):
            y = 200 + i * 60
            sel = i == self.settings_selection
            color = WHITE if sel else GRAY
            prefix = "> " if sel else "  "
            draw_text(self.screen, f"{prefix}{name}: {val}", 22,
                      SCREEN_W // 2, y, color, center=True)
            if sel:
                draw_text(self.screen, "Left/Right to adjust", 13,
                          SCREEN_W // 2, y + 25, GRAY, center=True)
        draw_text(self.screen, "Esc to go back  |  F11 toggle fullscreen", 14,
                  SCREEN_W // 2, SCREEN_H - 40, GRAY, center=True)

    def draw_pause(self):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))
        draw_text(self.screen, "PAUSED", 48,
                  SCREEN_W // 2, SCREEN_H // 2 - 40, WHITE, center=True)
        draw_text(self.screen, "Esc to resume  |  Q to quit to menu", 18,
                  SCREEN_W // 2, SCREEN_H // 2 + 20, LIGHT_GRAY, center=True)

    def draw_levelup(self):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))
        t = pygame.time.get_ticks() / 1000.0

        # === ORNATE "LEVEL UP" BANNER ===
        banner_w, banner_h = 340, 55
        bx = SCREEN_W // 2 - banner_w // 2
        by_b = 65
        # Banner background (dark with gold)
        banner = pygame.Surface((banner_w, banner_h), pygame.SRCALPHA)
        banner.fill((20, 12, 8, 220))
        self.screen.blit(banner, (bx, by_b))
        # Gold border with corner details
        pygame.draw.rect(self.screen, GOLD, (bx, by_b, banner_w, banner_h), 3)
        pygame.draw.rect(self.screen, (180, 140, 30),
                         (bx + 3, by_b + 3, banner_w - 6, banner_h - 6), 1)
        # Corner gems
        for cx, cy in [(bx + 8, by_b + 8), (bx + banner_w - 8, by_b + 8),
                       (bx + 8, by_b + banner_h - 8), (bx + banner_w - 8, by_b + banner_h - 8)]:
            pygame.draw.circle(self.screen, (200, 50, 30), (cx, cy), 4)
            pygame.draw.circle(self.screen, (255, 100, 80), (cx - 1, cy - 1), 2)
        # Text with outline
        for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2), (-1, 0), (1, 0), (0, -1), (0, 1)]:
            draw_text(self.screen, "LEVEL UP", 38,
                      SCREEN_W // 2 + ox, by_b + banner_h // 2 + oy, (60, 30, 10), center=True)
        draw_text(self.screen, "LEVEL UP", 38,
                  SCREEN_W // 2, by_b + banner_h // 2, GOLD, center=True)

        # Level indicator bar
        lv_w = 140
        lv_x = SCREEN_W // 2 - lv_w // 2
        lv_y = by_b + banner_h + 8
        pygame.draw.rect(self.screen, (60, 20, 15), (lv_x, lv_y, lv_w, 22))
        pygame.draw.rect(self.screen, (120, 40, 30), (lv_x, lv_y, lv_w, 22), 2)
        draw_text(self.screen, f"LAN {self.player.level}", 14,
                  SCREEN_W // 2, lv_y + 11, GOLD, center=True)

        # === POWER-UP CARDS ===
        box_w, box_h = 240, 160
        gap = 24
        total = len(self.pending_powerups) * box_w + (len(self.pending_powerups) - 1) * gap
        start_x = SCREEN_W // 2 - total // 2
        card_top = lv_y + 40
        mx, my = pygame.mouse.get_pos()
        self.hovered_powerup = -1

        for i, pu in enumerate(self.pending_powerups):
            cx = start_x + i * (box_w + gap)
            cy = card_top
            hovered = cx <= mx <= cx + box_w and cy <= my <= cy + box_h
            if hovered:
                self.hovered_powerup = i

            # Card background
            card = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
            card.fill((15, 10, 25, 230))
            self.screen.blit(card, (cx, cy))

            # Card inner region (darker with color tint)
            inner_m = 6
            inner_rect = (cx + inner_m, cy + inner_m,
                          box_w - inner_m * 2, box_h - inner_m * 2)
            tint = tuple(max(0, c // 6) for c in pu["color"])
            pygame.draw.rect(self.screen, (tint[0] + 15, tint[1] + 10, tint[2] + 20),
                             inner_rect)

            # Gold border (double-line ornate)
            bc = GOLD if hovered else (140, 110, 40)
            pygame.draw.rect(self.screen, bc, (cx, cy, box_w, box_h), 3)
            pygame.draw.rect(self.screen, (100, 75, 25),
                             (cx + 4, cy + 4, box_w - 8, box_h - 8), 1)

            # Corner ornaments
            for co_x, co_y in [(cx + 6, cy + 6), (cx + box_w - 6, cy + 6),
                               (cx + 6, cy + box_h - 6), (cx + box_w - 6, cy + box_h - 6)]:
                pygame.draw.circle(self.screen, bc, (co_x, co_y), 3)

            # Top color accent strip
            pygame.draw.rect(self.screen, pu["color"],
                             (cx + inner_m, cy + inner_m, box_w - inner_m * 2, 4))

            # Icon area (center, draws a symbolic icon based on power-up color)
            icon_cx = cx + box_w // 2
            icon_cy = cy + 55
            # Icon glow
            ig = pygame.Surface((50, 50), pygame.SRCALPHA)
            gi = int(30 + 15 * math.sin(t * 3 + i))
            pygame.draw.circle(ig, (*pu["color"], gi), (25, 25), 25)
            self.screen.blit(ig, (icon_cx - 25, icon_cy - 25))
            # Icon symbol (simple but effective)
            ic = pu["color"]
            if "Damage" in pu["name"] or "Explosion" in pu["name"]:
                # Fire/explosion icon
                for fi in range(5):
                    fa = fi * math.pi * 2 / 5 + t * 2
                    fx = icon_cx + int(math.cos(fa) * 12)
                    fy = icon_cy + int(math.sin(fa) * 12)
                    pygame.draw.circle(self.screen, ic, (fx, fy), 5)
                pygame.draw.circle(self.screen, FIRE_BRIGHT, (icon_cx, icon_cy), 8)
            elif "Speed" in pu["name"]:
                # Arrow icon
                pygame.draw.polygon(self.screen, ic, [
                    (icon_cx + 15, icon_cy), (icon_cx - 5, icon_cy - 10),
                    (icon_cx - 5, icon_cy - 4), (icon_cx - 15, icon_cy - 4),
                    (icon_cx - 15, icon_cy + 4), (icon_cx - 5, icon_cy + 4),
                    (icon_cx - 5, icon_cy + 10)])
            elif "HP" in pu["name"] or "Heal" in pu["name"]:
                # Heart/cross icon
                pygame.draw.rect(self.screen, ic, (icon_cx - 8, icon_cy - 3, 16, 6))
                pygame.draw.rect(self.screen, ic, (icon_cx - 3, icon_cy - 8, 6, 16))
            elif "Lightning" in pu["name"]:
                # Bolt icon
                pygame.draw.polygon(self.screen, ic, [
                    (icon_cx - 2, icon_cy - 14), (icon_cx - 8, icon_cy + 2),
                    (icon_cx - 1, icon_cy + 2), (icon_cx + 2, icon_cy + 14),
                    (icon_cx + 8, icon_cy - 2), (icon_cx + 1, icon_cy - 2)])
            elif "Orbit" in pu["name"]:
                # Spinning blades icon
                for bi in range(3):
                    ba = bi * math.pi * 2 / 3 + t * 3
                    bx_o = icon_cx + int(math.cos(ba) * 10)
                    by_o = icon_cy + int(math.sin(ba) * 10)
                    pygame.draw.circle(self.screen, ic, (bx_o, by_o), 5)
                pygame.draw.circle(self.screen, WHITE, (icon_cx, icon_cy), 4, 1)
            elif "Aura" in pu["name"]:
                # Ring icon
                pygame.draw.circle(self.screen, ic, (icon_cx, icon_cy), 14, 3)
                pygame.draw.circle(self.screen, ic, (icon_cx, icon_cy), 8, 2)
            elif "Magnet" in pu["name"]:
                # Magnet icon
                pygame.draw.arc(self.screen, ic,
                                (icon_cx - 10, icon_cy - 10, 20, 20), 0, math.pi, 4)
                pygame.draw.line(self.screen, ic, (icon_cx - 10, icon_cy),
                                 (icon_cx - 10, icon_cy + 8), 4)
                pygame.draw.line(self.screen, ic, (icon_cx + 10, icon_cy),
                                 (icon_cx + 10, icon_cy + 8), 4)
            else:
                # Generic star icon
                for si in range(5):
                    sa = si * math.pi * 2 / 5 - math.pi / 2
                    sa2 = sa + math.pi / 5
                    px1 = icon_cx + int(math.cos(sa) * 14)
                    py1 = icon_cy + int(math.sin(sa) * 14)
                    px2 = icon_cx + int(math.cos(sa2) * 6)
                    py2 = icon_cy + int(math.sin(sa2) * 6)
                    pygame.draw.line(self.screen, ic, (icon_cx, icon_cy), (px1, py1), 2)
                    pygame.draw.circle(self.screen, ic, (px1, py1), 3)

            # Power-up name (with outline)
            name_y = cy + 100
            for ox, oy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
                draw_text(self.screen, pu["name"].upper(), 17,
                          cx + box_w // 2 + ox, name_y + oy, (10, 5, 5), center=True)
            draw_text(self.screen, pu["name"].upper(), 17,
                      cx + box_w // 2, name_y, pu["color"], center=True)
            # Description
            draw_text(self.screen, pu["desc"], 13,
                      cx + box_w // 2, name_y + 22, LIGHT_GRAY, center=True)
            # Key hint
            draw_text(self.screen, f"[{i + 1}]", 12,
                      cx + box_w // 2, cy + box_h - 14, GRAY, center=True)

            # Hover highlight glow
            if hovered:
                hl = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
                hl.fill((255, 200, 80, 15))
                self.screen.blit(hl, (cx, cy))

    def draw_gameover(self):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        self.screen.blit(overlay, (0, 0))
        # Red glow behind GAME OVER
        glow = pygame.Surface((400, 80), pygame.SRCALPHA)
        pygame.draw.ellipse(glow, (200, 20, 20, 40), (0, 0, 400, 80))
        self.screen.blit(glow, (SCREEN_W // 2 - 200, SCREEN_H // 3 - 50))
        for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            draw_text(self.screen, "GAME OVER", 56,
                      SCREEN_W // 2 + ox, SCREEN_H // 3 - 20 + oy, (40, 0, 0), center=True)
        draw_text(self.screen, "GAME OVER", 56,
                  SCREEN_W // 2, SCREEN_H // 3 - 20, RED, center=True)
        p = self.player
        minutes = int(self.game_time) // 60
        seconds = int(self.game_time) % 60
        stats = (f"Survived {minutes:02d}:{seconds:02d}  |  Kills {p.kills}"
                 f"  |  Level {p.level}  |  Wave {self.wave+1}")
        draw_text(self.screen, stats, 20,
                  SCREEN_W // 2, SCREEN_H // 2 - 20, LIGHT_GRAY, center=True)
        draw_text(self.screen, f"Gold earned: {p.gold}", 18,
                  SCREEN_W // 2, SCREEN_H // 2 + 15, GOLD, center=True)
        if self.new_achievements:
            names = [a["name"] for a in ACHIEVEMENT_DEFS
                     if a["id"] in self.new_achievements]
            draw_text(self.screen, f"New: {', '.join(names)}", 16,
                      SCREEN_W // 2, SCREEN_H // 2 + 45, GREEN, center=True)
        draw_text(self.screen, "Enter to play again  |  Esc for menu", 20,
                  SCREEN_W // 2, SCREEN_H // 2 + 80, WHITE, center=True)

    def draw(self):
        if self.state == "menu":
            self.draw_menu()
        elif self.state == "char_select":
            self.draw_char_select()
        elif self.state == "shop":
            self.draw_shop()
        elif self.state == "achievements":
            self.draw_achievements()
        elif self.state == "high_scores":
            self.draw_high_scores()
        elif self.state == "settings":
            self.draw_settings()
        elif self.state in ("playing", "paused", "levelup", "gameover"):
            self.draw_ground()
            for ch in self.chests:
                ch.draw(self.screen, self.cam_x, self.cam_y)
            for hp_item in self.health_pickups:
                hp_item.draw(self.screen, self.cam_x, self.cam_y)
            for gem in self.gems:
                gem.draw(self.screen, self.cam_x, self.cam_y)
            for ex in self.explosions:
                ex.draw(self.screen, self.cam_x, self.cam_y)
            for enemy in self.enemies:
                enemy.draw(self.screen, self.cam_x, self.cam_y)
            for proj in self.projectiles:
                proj.draw(self.screen, self.cam_x, self.cam_y)
            for boom in self.boomerangs:
                boom.draw(self.screen, self.cam_x, self.cam_y)
            for ln in self.lightnings:
                ln.draw(self.screen, self.cam_x, self.cam_y)
            self.player.draw(self.screen, self.cam_x, self.cam_y)
            self.particles.draw(self.screen, self.cam_x, self.cam_y)
            for dn in self.dmg_numbers:
                dn.draw(self.screen, self.cam_x, self.cam_y)
            self.draw_hud()
            for ap in self.achievement_popups:
                ap.draw(self.screen)
            if self.state == "paused":
                self.draw_pause()
            elif self.state == "levelup":
                self.draw_levelup()
            elif self.state == "gameover":
                self.draw_gameover()

    # ----- events -----
    def _apply_powerup(self, idx):
        if 0 <= idx < len(self.pending_powerups):
            pu = self.pending_powerups[idx]
            if pu.get("special") == "magnet":
                self.gem_attract_range *= 2
            else:
                pu["apply"](self.player)
            self.sound.play("select")
            self.state = "playing"

    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_F11:
                    self.toggle_fullscreen()
                    continue
                if event.key == pygame.K_F3:
                    self.show_fps = not self.show_fps
                    continue

                if self.state == "menu":
                    if event.key in (pygame.K_UP, pygame.K_w):
                        self.menu_selection = (self.menu_selection - 1) % 7
                        self.sound.play("select")
                    elif event.key in (pygame.K_DOWN, pygame.K_s):
                        self.menu_selection = (self.menu_selection + 1) % 7
                        self.sound.play("select")
                    elif event.key == pygame.K_RETURN:
                        c = self.menu_selection
                        if c == 0:
                            self.reset()
                            self.state = "playing"
                        elif c == 1:
                            self.state = "char_select"
                        elif c == 2:
                            self.state = "shop"
                            self.shop_selection = 0
                        elif c == 3:
                            self.state = "achievements"
                        elif c == 4:
                            self.state = "high_scores"
                        elif c == 5:
                            self.state = "settings"
                            self.settings_selection = 0
                        elif c == 6:
                            return False
                    elif event.key == pygame.K_ESCAPE:
                        return False
                    elif event.key == pygame.K_u:
                        if self.update_status == "available" and self.update_available:
                            threading.Thread(target=self._do_update, daemon=True).start()

                elif self.state == "char_select":
                    if event.key in (pygame.K_LEFT, pygame.K_a):
                        self.char_idx = (self.char_idx - 1) % len(CHARACTERS)
                        self.sound.play("select")
                    elif event.key in (pygame.K_RIGHT, pygame.K_d):
                        self.char_idx = (self.char_idx + 1) % len(CHARACTERS)
                        self.sound.play("select")
                    elif event.key in (pygame.K_RETURN, pygame.K_ESCAPE):
                        self.state = "menu"

                elif self.state == "shop":
                    if event.key in (pygame.K_UP, pygame.K_w):
                        self.shop_selection = (self.shop_selection - 1) % len(SHOP_ITEMS)
                        self.sound.play("select")
                    elif event.key in (pygame.K_DOWN, pygame.K_s):
                        self.shop_selection = (self.shop_selection + 1) % len(SHOP_ITEMS)
                        self.sound.play("select")
                    elif event.key == pygame.K_RETURN:
                        item = SHOP_ITEMS[self.shop_selection]
                        level = self.save["upgrades"][item["key"]]
                        cost = get_upgrade_cost(item, level)
                        if self.save["gold"] >= cost:
                            self.save["gold"] -= cost
                            self.save["upgrades"][item["key"]] += 1
                            save_game(self.save)
                            self.sound.play("chest")
                        else:
                            self.sound.play("hurt")
                    elif event.key == pygame.K_ESCAPE:
                        self.state = "menu"

                elif self.state == "settings":
                    if event.key in (pygame.K_UP, pygame.K_w):
                        self.settings_selection = (self.settings_selection - 1) % 3
                        self.sound.play("select")
                    elif event.key in (pygame.K_DOWN, pygame.K_s):
                        self.settings_selection = (self.settings_selection + 1) % 3
                        self.sound.play("select")
                    elif event.key in (pygame.K_LEFT, pygame.K_a,
                                       pygame.K_RIGHT, pygame.K_d):
                        delta = (0.1 if event.key in (pygame.K_RIGHT, pygame.K_d)
                                 else -0.1)
                        if self.settings_selection == 0:
                            vol = clamp(
                                self.save["settings"]["sfx_volume"] + delta, 0, 1)
                            self.save["settings"]["sfx_volume"] = round(vol, 1)
                            self.sound.set_volume(vol)
                            save_game(self.save)
                            self.sound.play("select")
                        elif self.settings_selection == 1:
                            self.toggle_fullscreen()
                        elif self.settings_selection == 2:
                            self.show_fps = not self.show_fps
                    elif event.key == pygame.K_ESCAPE:
                        self.state = "menu"

                elif self.state in ("achievements", "high_scores"):
                    if event.key == pygame.K_ESCAPE:
                        self.state = "menu"

                elif self.state == "playing":
                    if event.key == pygame.K_ESCAPE:
                        self.state = "paused"
                    elif event.key == pygame.K_SPACE:
                        if self.player.start_dash(pygame.key.get_pressed()):
                            self.sound.play("dash")
                            self.particles.emit(
                                self.player.x, self.player.y,
                                self.player.char_color, 8, 3, 12, 3)

                elif self.state == "paused":
                    if event.key == pygame.K_ESCAPE:
                        self.state = "playing"
                    elif event.key == pygame.K_q:
                        self.state = "menu"

                elif self.state == "levelup":
                    idx = -1
                    if event.key == pygame.K_1: idx = 0
                    elif event.key == pygame.K_2: idx = 1
                    elif event.key == pygame.K_3: idx = 2
                    self._apply_powerup(idx)

                elif self.state == "gameover":
                    if event.key == pygame.K_RETURN:
                        self.reset()
                        self.state = "playing"
                    elif event.key == pygame.K_ESCAPE:
                        self.state = "menu"

            if event.type == pygame.MOUSEBUTTONDOWN and self.state == "levelup":
                if hasattr(self, "hovered_powerup"):
                    self._apply_powerup(self.hovered_powerup)

        return True

    # ----- main loop -----
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
