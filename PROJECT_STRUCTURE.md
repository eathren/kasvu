# Kasvu Project Structure

## Overview
This project now follows professional Godot best practices with a feature-based organization.

## Folder Structure

```
kasvu/
├── addons/                     # Third-party plugins
├── assets/                     # Raw source assets
│   ├── audio/                 # Sound effects and music
│   ├── art/                   # Sprites, textures (.aseprite, .png)
│   ├── fonts/                 # Font files
│   └── shaders/               # Shader files
├── autoloads/                  # Global singletons (GameState, RunManager, etc.)
├── components/                 # Reusable components
│   ├── health_component/      # HP system (script + scene)
│   ├── speed_component/       # Movement speed (script + scene)
│   ├── weapon_component/      # Weapon management (script + scene)
│   ├── pickup_component/      # Item magnetism (script + scene)
│   ├── faction_component/     # Team/faction (script + scene)
│   └── damage_on_hit_component/  # Collision damage (script + scene)
├── entities/                   # Game objects (enemies, player, items)
│   ├── enemies/               # Enemy types
│   │   ├── enemies.gd         # Base enemy script
│   │   ├── imp/               # Imp enemy (script + scene)
│   │   └── lieutenant/        # Lieutenant enemy (scene)
│   ├── items/
│   │   └── pickups/           # Collectible items
│   │       ├── exp_crystal/   # XP pickup
│   │       ├── gold/          # Gold pickup
│   │       └── scrap/         # Scrap pickup
│   ├── player/                # Player-controlled entities
│   │   ├── crew/              # Crew member (on foot)
│   │   ├── ships/             # Player ships
│   │   │   ├── player_ship/   # Main player ship
│   │   │   └── turret.tscn    # Turret variant
│   │   └── camera_2d.gd       # Camera script
│   ├── projectiles/           # Bullets and projectiles
│   │   └── bullet/            # Basic bullet
│   └── vehicles/              # Large vehicles
│       └── trawler/           # Main trawler vehicle
├── levels/                     # Level scenes
│   ├── main.tscn              # Root game scene
│   └── mine/                  # Mine level
│       └── level_mine.tscn
├── resources/                  # Data-driven configuration
│   ├── config/                # Resource instances (.tres files)
│   │   ├── crew/              # Crew member stats
│   │   ├── enemies/           # Enemy stats per tier
│   │   ├── loot/              # Loot table configs
│   │   ├── ships/             # Ship stats
│   │   └── weapons/           # Weapon stats
│   └── data/                  # Resource class definitions (.gd)
│       ├── crew_stats.gd
│       ├── enemy_stats.gd
│       ├── ship_stats.gd
│       ├── weapon_stats.gd
│       ├── loot_table.gd
│       └── upgrade_data.gd
├── systems/                    # Core game systems
│   ├── combat/                # Combat-related systems
│   │   └── laser.gd/.tscn     # Laser system
│   ├── generation/            # Procedural generation
│   │   └── mine_generator.gd  # Mine level generator
│   └── world/                 # World management
│       ├── wall.gd            # Wall/tile management
│       └── world_root.tscn    # World container
└── ui/                         # User interface
	├── hud/                   # In-game HUD
	│   ├── game_hud.tscn      # Main HUD
	│   └── interaction_prompt.tscn
	├── menus/                 # Menu screens (pause, settings, etc.)
	└── transitions/           # Scene transitions and loading screens
		├── scene_transition.tscn
		└── loading_screen.tscn
```

## Key Principles

### 1. **Scripts Live WITH Scenes**
- No separate `scripts/` folder
- Each entity has its script and scene in the same folder
- Example: `entities/enemies/imp/imp.gd` + `imp.tscn`

### 2. **Group by Feature, Not Type**
- ✅ `entities/enemies/imp/`
- ❌ `scripts/enemies/` + `scenes/enemies/`

### 3. **Components Are Self-Contained**
- Each component in its own folder with script + scene
- Example: `components/health_component/health_component.gd` + `health_component.tscn`

### 4. **Data-Driven Configuration**
- Resource definitions: `resources/data/*.gd`
- Resource instances: `resources/config/**/*.tres`
- Edit `.tres` files to balance the game without touching code

## Common Tasks

### Adding a New Enemy
1. Create folder: `entities/enemies/new_enemy/`
2. Add `new_enemy.gd` (extends `enemies.gd`)
3. Add `new_enemy.tscn`
4. Create stats: `resources/config/enemies/new_enemy_tier1.tres`

### Adding a New Component
1. Create folder: `components/new_component/`
2. Add `new_component.gd`
3. Add `new_component.tscn`
4. Attach to entities as needed

### Tweaking Balance
1. Open `.tres` file in `resources/config/`
2. Edit values in Godot Inspector
3. Save and test - no code changes needed!

## Migration Notes
- ✅ All files moved and organized
- ✅ `autoload/` → `autoloads/`
- ✅ Components reorganized into subfolders
- ✅ Entities separated by type (enemies, player, items, vehicles)
- ✅ Systems extracted from `scripts/core/`
- ✅ UI organized into hud/menus/transitions
- ✅ Levels moved to root with scripts
- ✅ Old `scripts/` and `scenes/` folders removed

## Next Steps
1. Open project in Godot
2. Let Godot reimport/update references
3. Test the game to ensure everything works
4. Continue development with clean structure!
