# Multiplayer & Menu System - Complete Setup

## ✅ What's Been Implemented

### 1. Main Menu (`ui/menus/main_menu.tscn`)
- **Big START GAME button** - Starts singleplayer instantly
- **HOST MULTIPLAYER** - Create a game server
- **JOIN MULTIPLAYER** - Connect to a host
- **LOAD GAME** - Shows 3 save slots with stats
- **QUIT** - Exit the game

### 2. NetworkManager Autoload (`autoloads/network_manager.gd`)
- Host/client connection management
- ENet multiplayer peer setup
- Player tracking and connection events
- Support for up to 4 players
- Handles disconnections gracefully

### 3. Save/Load System
- **3 save slots** with individual files
- **Auto-detection** of existing saves
- **Save info display**: Level, kills, playtime
- **Host-only saving** in multiplayer
- JSON format for easy debugging

**API:**
```gdscript
GameState.save_game(slot)       # Save to slot 1-3
GameState.load_game(slot)       # Load from slot
GameState.reset_run()           # New game
GameState.get_save_slot_info(slot)  # Preview save
```

### 4. Pause Menu (`ui/menus/pause_menu.tscn`)
- Press **ESC** to pause
- **RESUME** - Continue playing
- **SAVE GAME** - Save current progress (host only)
- **QUIT TO MENU** - Return to main menu
- Semi-transparent overlay
- Prevents input to game while paused

### 5. Game Flow
```
Main Menu → Start/Host/Join → Level → Pause (ESC) → Quit → Main Menu
          ↓ Load Slot
```

## 🔧 What Still Needs Work

### Critical for Multiplayer to Function:

#### 1. **Player Spawning Per Peer**
Currently only one PlayerController spawns. Need to spawn one per connected player:

```gdscript
# In level_mine.gd _ready():
if NetworkManager.is_multiplayer():
	for peer_id in NetworkManager.players.keys():
		_spawn_player_for_peer(peer_id)

func _spawn_player_for_peer(peer_id: int) -> void:
	var controller := PlayerController.new()
	controller.peer_id = peer_id
	controller.set_multiplayer_authority(peer_id)
	add_child(controller)
	# Spawn crew avatar and assign to controller
```

#### 2. **Add MultiplayerSynchronizer Nodes**
For each entity that needs to sync:
- **PlayerShip**: Sync position, rotation, velocity
- **Crew Avatar**: Sync position, velocity
- **Trawler**: Sync position (host authority only)
- **Bullets**: Sync position, rotation
- **Enemies**: Sync position, health (host authority)

**How to add:**
1. Open entity scene (e.g., `player_ship.tscn`)
2. Add child node → `MultiplayerSynchronizer`
3. Set "Root Path" to `..` (parent)
4. Add properties: `global_position:0`, `global_rotation:0`, `velocity:0`
5. Set replication interval to 0 (every frame) for player entities

#### 3. **Host Authority for Game Logic**
Wrap important game logic with authority checks:

```gdscript
# Pickup collection (only host processes)
func _on_pickup_area_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	# ... process pickup

# Enemy spawning (only host spawns)
func _spawn_enemy() -> void:
	if not multiplayer.is_server():
		return
	# ... spawn enemy
	
# World generation (only host generates)
func _generate_world() -> void:
	if not multiplayer.is_server():
		return
	# ... generate tiles
	_sync_world_to_clients.rpc()
```

#### 4. **Lobby Screen** (Nice to have)
Show connected players before starting:
```
HOST LOBBY
-----------
Player 1 (Host) - READY
Player 2        - READY
Player 3        - Not Ready

[Start Game]  (Host only)
[Leave Lobby]
```

### Quality of Life:

#### 5. **Auto-Save System**
Add auto-save triggers:
```gdscript
# In RunManager or LevelManager:
signal level_completed()

func _on_level_completed() -> void:
	if NetworkManager.is_host:
		GameState.save_game()
```

Consider auto-saving:
- Every level transition
- Every 5 minutes
- When docking at trawler
- After major milestones

#### 6. **Game Over / Win Screen**
Currently no end state. Add:
- **Game Over Screen**: When trawler dies
- **Victory Screen**: When run completes
- Both screens should have:
  - Stats summary (kills, XP, time)
  - "Save & Quit" button
  - "Try Again" button

#### 7. **Connection Status UI**
Show connection info during multiplayer:
- Ping/latency indicator
- Player list with status
- Disconnect warnings

## 🎮 Testing the System

### Singleplayer Test:
1. Run game → Main menu appears
2. Click "START GAME" → Level loads
3. Press ESC → Pause menu
4. Click "SAVE GAME" → Saved!
5. Click "QUIT TO MENU" → Back to main menu
6. Click "LOAD GAME" → See your save
7. Click the save slot → Resume from save

### Multiplayer Test (Same Machine):
1. Run game instance 1: Click "HOST MULTIPLAYER"
2. Run game instance 2: Click "JOIN MULTIPLAYER", enter `127.0.0.1`
3. Both should load into the same level
4. **NOTE**: Currently will need sync implementation to work properly

### Network Test (Different Machines):
1. Host: Forward port 7777 (UDP/TCP) on router
2. Host: Start game, click "HOST MULTIPLAYER"
3. Client: Enter host's public IP address
4. Client: Click "CONNECT"

## 📁 File Structure

```
kasvu/
├── autoloads/
│   ├── game_state.gd         (Save/load, game stats)
│   ├── network_manager.gd    (Multiplayer connections)
│   └── run_manager.gd        (Level management)
├── ui/
│   └── menus/
│       ├── main_menu.gd/.tscn      (Start screen)
│       └── pause_menu.gd/.tscn     (In-game pause)
├── levels/
│   └── mine/
│       └── level_mine.tscn   (Has HUD + Pause Menu)
└── Documentation:
    ├── NETWORKING.md         (Multiplayer guide)
    ├── SAVE_SYSTEM.md        (Save/load guide)
    └── MULTIPLAYER_SETUP.md  (This file)
```

## 🔑 Key Concepts

### Host vs Client Authority
- **Host**: Authoritative for game state, world gen, enemy spawning, pickups
- **Client**: Sends input to host, receives state updates
- Use `multiplayer.is_server()` to check if host
- Use `set_multiplayer_authority(peer_id)` for owned entities

### RPC (Remote Procedure Call)
```gdscript
# Call function on all clients:
my_function.rpc(args)

# Call function on specific client:
my_function.rpc_id(peer_id, args)

# RPC decorators:
@rpc("any_peer")        # Anyone can call
@rpc("authority")       # Only authority can call
@rpc("call_local")      # Also execute locally
@rpc("call_remote")     # Only execute remotely
```

### MultiplayerSynchronizer
- Automatically syncs properties across network
- Set replication config: which properties, how often
- Much easier than manual RPC for simple state

## 🚀 Next Steps Priority

1. **Add MultiplayerSynchronizer to PlayerShip** (30 min)
2. **Spawn PlayerController per peer** (1 hour)
3. **Test local multiplayer** (30 min)
4. **Add host authority checks to pickups** (30 min)
5. **Add auto-save on level transitions** (15 min)
6. **Test full loop: start → play → save → quit → load** (30 min)

Total: ~3.5 hours for working multiplayer

## 📚 Resources
- [Godot High-Level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Godot MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html)
- [Godot RPC](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#remote-procedure-calls)

