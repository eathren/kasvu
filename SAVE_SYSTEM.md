# Save System Guide

## Overview
The game supports 3 save slots with automatic saving and manual loading.

## Save Location
- **Path**: `user://savegame_slot_X.save` (X = 1, 2, or 3)
- **Format**: JSON
- **Godot user folder**: `~/.local/share/godot/app_userdata/Kasvu/` (Linux)

## What Gets Saved
- Current level number
- Game time elapsed
- Random seed (for reproducible worlds)
- Player stats: XP, level, kills, gold, scrap
- Multipliers: scroll, laser, enemy speed, etc.
- Unlocked weapons and weapon levels
- Upgrade modifiers

## API

### Save Game
```gdscript
# Save to current slot
GameState.save_game()

# Save to specific slot
GameState.save_game(2)  # Saves to slot 2
```

### Load Game
```gdscript
# Load from specific slot
if GameState.load_game(1):
	RunManager.start_run()  # Continue from loaded state
else:
	print("Failed to load")
```

### Check Save Slots
```gdscript
# Check if slot has data
if GameState.save_slot_exists(1):
	print("Slot 1 has a save")

# Get slot info (without loading)
var info := GameState.get_save_slot_info(2)
if info.exists:
	print("Level: ", info.level)
	print("Kills: ", info.kills)
	print("Playtime: ", info.playtime, " seconds")
```

### Reset for New Game
```gdscript
# Reset all run stats to defaults
GameState.reset_run()
```

## Auto-Save Triggers
Currently you need to manually call `GameState.save_game()`. Consider adding auto-save on:
- Every level transition
- Every 5 minutes
- When returning to trawler
- After boss kills

Example:
```gdscript
# In RunManager or LevelManager:
func _on_level_complete() -> void:
	if NetworkManager.is_host:  # Only host can save
		GameState.save_game()
	# ... level transition logic
```

## Save Slot UI
The main menu shows all 3 slots with:
- Slot number
- Level reached
- Total kills
- Playtime in minutes
- "Empty" if no data

Slots are clickable buttons that load the save and start the game.

## Multiplayer Considerations
- **Only the host can save**
- Clients cannot save or load
- When host saves, game state is saved for all players
- When loading a multiplayer save, host loads and syncs to clients

## Future Enhancements
- [ ] Cloud saves (Steam Cloud, GOG Galaxy)
- [ ] Save corruption detection & recovery
- [ ] Multiple profiles/characters
- [ ] Delete save button
- [ ] Export/import saves
- [ ] Screenshot thumbnails for saves

