# 🚢 Boatry McBoaterson

A muscular boat survives waves of fish enemies on the open ocean. Vampire Survivors-style gameplay with an ocean twist.

![Icon](godot/icon.png)

## 🎮 Play Now
- **Web version**: [Play in browser](https://skyeatsbrad.github.io/Boatry-McBoaterson/) (works on any device including iPhone/Android)
- **Windows**: Download from [Releases](https://github.com/skyeatsbrad/Boatry-McBoaterson/releases)

## Features

### Gameplay
- **4 Boat Classes**: Tugboat (cannon), Warship (AoE blast), Speedboat (boomerang), Sailboat (lightning)
- **8 Fish Enemies**: Piranha, Pufferfish, Swordfish, Jellyfish, Electric Eel, Anglerfish, Shark + **Kraken Boss**
- **4 Weapon Types**: Cannon, Chain Lightning, Anchor Boomerang, AoE Explosion
- **Dash Ability**: SPACE to dodge with invulnerability frames
- **Destroyable Items**: Crates, barrels, buoys drop bonus XP, gold, or power-ups
- **14 Power-ups**: Damage, speed, multi-shot, orbital blades, aura, and more
- **Combo System**: Chain kills for XP/gold multipliers (Bronze → Diamond tiers)

### Ocean Hazards
- **Whirlpools** that pull you in
- **Storms** that reduce visibility and shake the screen
- **Whale & Dolphin allies** that swim by and attack enemies

### Progression
- **Persistent Upgrades**: Spend gold on Vitality, Power, Agility, Wisdom
- **6 Animated Skins**: Flame, Electric, Golden, Ghost, Ice (unlock after 5 games)
- **16 Achievements**: First Blood, Boss Slayer, Combo King, Storm Chaser, and more
- **High Score Leaderboard**
- **Ship Log / Bestiary**: Track all enemies encountered

### Game Modes
- **Normal**: Classic wave survival
- **Boss Rush**: Only bosses, escalating difficulty
- **Speed Run**: 5-minute timer, maximize kills
- **Daily Challenge**: Date-seeded run for competitive play

### Multiplayer
- **Local Co-op**: 2-player same-screen (P2: IJKL + Right Shift, or controller 2)
- Dynamic camera zooms to keep both players in view

### Accessibility
- **Colorblind Mode**: Shape symbols on all enemies
- **Game Speed Slider**: 0.5x to 1.5x
- **Screen Reader**: TTS support for menus
- **Haptic Feedback**: Vibration on mobile devices

### Platforms
| Platform | Method | Status |
|----------|--------|--------|
| Web (all devices) | Pygbag / Godot web export | ✅ |
| Windows | Godot .exe / PyInstaller | ✅ |
| Android | Godot APK sideload | ✅ |
| Steam Deck | Godot Linux build | ✅ |
| iOS | Web version in Safari | ✅ |

## Controls
- **WASD / Arrow Keys** — Move
- **SPACE** — Dash
- **Esc** — Pause
- **F11** — Fullscreen
- **F3** — FPS / Performance overlay
- **1/2/3** — Select power-ups on level up
- **Touch** — Virtual joystick on mobile

## Project Structure
```
├── game.py              # Pygame version (standalone)
├── updater.py           # Auto-update from GitHub Releases
├── web/                 # Pygbag web build
├── godot/               # Godot 4 port (full version)
│   ├── project.godot
│   ├── scenes/          # All .tscn scene files
│   ├── scripts/         # GDScript source
│   │   ├── autoload/    # GameManager, AudioManager, AchievementManager
│   │   ├── player/      # Player, weapons, skins
│   │   ├── enemies/     # Fish types, Kraken boss, spawner
│   │   ├── items/       # Gems, health, chests, floating items
│   │   ├── ui/          # All menu screens
│   │   ├── coop/        # Co-op manager, camera
│   │   ├── game_modes/  # Mode manager, combo, bestiary
│   │   ├── mobile/      # Touch controls, haptics
│   │   ├── accessibility/ # Colorblind, speed, screen reader
│   │   ├── effects/     # Particles, screen shake, damage numbers
│   │   ├── hazards/     # Whirlpool, ocean allies
│   │   └── weather/     # Storm system
│   └── assets/
│       ├── shaders/     # Ocean, skin effects, damage flash
│       └── sprites/     # (procedural — no files needed)
└── builds/              # Export output
```

## Development
**Pygame version** (quick play):
```
pip install pygame
python game.py
```

**Godot version** (full features):
1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open `godot/project.godot`
3. Press F5 to run

## License
Made with ❤️ by skyeatsbrad
