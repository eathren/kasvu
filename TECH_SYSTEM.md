# Tech Item System Implementation

## ✅ Completed

### 1. Tech Item Resource System
**File:** `resources/data/tech_item.gd`
- `TechItem` resource class with properties:
  - ID, display name, description, stack description
  - Rarity system (Common, Uncommon, Rare, Epic, Legendary)
  - Category (Offense, Defense, Utility, Support)
  - Max stacks support
  - Rarity colors and helper methods

### 2. Starting Items Created
Located in `resources/data/items/`:

**Neon Halo Cartridge** (Uncommon, Offense)
- Base: +10% crit chance, critical hits chain to 2 enemies for 30% damage
- Per stack: +5% crit, +15% spark damage

**Gilded Barrel Shroud** (Uncommon, Offense)
- Base: +20% damage and +10% knockback while firing continuously (1s)
- Per stack: +10% damage, +5% knockback

**Saintbreaker Rounds** (Rare, Offense)
- Base: Pierce 1 enemy, +15% damage vs elites/bosses
- Per stack: +1 pierce per 2 stacks, +10% boss/elite damage

### 3. Tech Manager Enhanced
**File:** `autoloads/tech_manager.gd`
- Item pool loading system
- Per-player item stack tracking
- `add_item_stack(player_id, item)` - Add items to players
- `get_item_stack(player_id, item_id)` - Check stack counts
- `generate_item_choices(player_id, count, rarity)` - Create level-up options
- `get_level_up_rarity(level)` - Scale rarity with player level
- Max stack enforcement
- Signals: `item_acquired(player_id, item, stack_count)`

### 4. GameState Level-Up System
**File:** `autoloads/game_state.gd`
- Modified `_level_up()` to trigger 95% slowdown:
  ```gdscript
  Engine.time_scale = 0.05  # 5% speed
  ```
- Emits `level_up` signal for UI to catch

### 5. Level-Up UI
**Files:** 
- `ui/level_up/level_up_screen.gd/.tscn`
- `ui/level_up/item_choice_button.gd/.tscn`

**Features:**
- Full-screen overlay with semi-transparent background
- Shows current level and rarity tier
- Displays 4 item choices per level-up
- Each button shows:
  - Item name (colored by rarity)
  - Current and next stack count
  - Full description with stack bonuses
  - Icon (if available)
- Process mode set to ALWAYS (works during time slowdown)
- Resumes time (`Engine.time_scale = 1.0`) when item chosen
- Integrated into GameHUD

### 6. Rarity Scaling System
Rarity chances scale with level:

**Levels 1-4:**
- 70% Common
- 30% Uncommon

**Levels 5-9:**
- 40% Common
- 45% Uncommon
- 15% Rare

**Level 10+:**
- 20% Common
- 30% Uncommon
- 30% Rare
- 15% Epic
- 5% Legendary

## 🎮 How It Works

1. **Player gains XP** → `GameState.add_experience()`
2. **Reaches threshold** → `GameState._level_up()` called
3. **Time slows to 5%** → `Engine.time_scale = 0.05`
4. **Level-up signal emitted** → `GameState.level_up.emit(level)`
5. **UI catches signal** → `LevelUpScreen._on_level_up()`
6. **Rarity determined** → Based on player level
7. **4 items generated** → Same rarity, different items per player
8. **Player chooses** → `TechManager.add_item_stack()`
9. **Time resumes** → `Engine.time_scale = 1.0`
10. **UI hides** → Back to gameplay

## 📝 To Do

### Add Item Effects
Items currently just track stacks. You'll need to implement the actual effects:

```gdscript
# Example in weapon/player code:
var crit_bonus = 0.0
var stack = TechManager.get_item_stack(player_id, "neon_halo_cartridge")
if stack > 0:
    crit_bonus = 0.10 + (stack - 1) * 0.05  # 10% + 5% per extra stack
```

### More Items
Add more tech items to `resources/data/items/` and load them in `TechManager._load_item_pool()`

### Item Icons
Create icon textures and assign them to the `.tres` files

### Multiplayer Sync
If needed, add RPC calls to sync item choices across clients

### Reroll System
Add "reroll" option to get different item choices (costs gold/resource)

## 🔧 Testing

Test level-up by adding XP in console or debug:
```gdscript
GameState.add_experience(30)  # Instant level up
```

Check player items:
```gdscript
print(TechManager.get_player_items(multiplayer.get_unique_id()))
```
