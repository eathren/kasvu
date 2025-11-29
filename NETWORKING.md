# Multiplayer Networking Guide

## Overview
This game uses Godot's built-in high-level multiplayer API with ENet for networking.

## Architecture
- **Host-Client Model**: One player hosts, others join
- **Host Authority**: Host manages game state, world generation, saves
- **Max Players**: 4
- **Default Port**: 7777

## Files Created
- `autoloads/network_manager.gd` - Manages connections and player spawning
- `ui/menus/main_menu.gd` + `.tscn` - Main menu with host/join options

## What's Working
✅ Main menu with Start/Host/Join/Load/Quit buttons
✅ NetworkManager autoload for creating/joining games
✅ Save/load system with 3 save slots
✅ GameState.reset_run() for new games

## What Needs Implementation

### 1. **Player Spawning & Authority**
Each player needs their own `PlayerController` instance:

```gdscript
# In level_mine.gd or similar:
func _ready() -> void:
	if NetworkManager.is_multiplayer():
		# Spawn a PlayerController for each connected peer
		for peer_id in NetworkManager.players.keys():
			spawn_player_controller(peer_id)
	else:
		# Singleplayer - spawn one controller
		spawn_player_controller(1)

func spawn_player_controller(peer_id: int) -> void:
	var controller := preload("res://entities/player/player_controller.tscn").instantiate()
	controller.peer_id = peer_id
	controller.set_multiplayer_authority(peer_id)
	add_child(controller)
```

### 2. **Network Synchronization**
Use `MultiplayerSynchronizer` nodes for automatic syncing:

**For PlayerShip** (entities/player/ships/player_ship/player_ship.tscn):
- Add `MultiplayerSynchronizer` node
- Sync: `global_position`, `global_rotation`, `velocity`
- Replication interval: 0 (every frame)

**For Crew Avatar**:
- Add `MultiplayerSynchronizer` node
- Sync: `global_position`, `velocity`

**For Trawler** (only host spawns):
- Add `MultiplayerSynchronizer` node
- Sync: `global_position`, `velocity`

### 3. **RPCs for Game Events**
Add RPC calls for important events:

```gdscript
# In PlayerShip:
func take_damage(amount: float) -> void:
	if multiplayer.is_server():
		_take_damage_rpc.rpc(amount)

@rpc("authority", "call_remote")
func _take_damage_rpc(amount: float) -> void:
	health_component.take_damage(amount)

# In GameState:
@rpc("authority", "call_local")
func _sync_xp(xp: int, level: int) -> void:
	current_xp = xp
	current_level = level
	experience_gained.emit(xp, current_xp)
```

### 4. **Lobby/Waiting Screen**
When joining a game, show a lobby screen:
- List of connected players
- "Ready" button
- Host "Start Game" button

### 5. **Host Authority for Important Actions**
Only the host should:
- Generate the world (other clients receive tiles via RPC)
- Spawn enemies (clients see synced instances)
- Handle pickups (collect on host, sync to clients)
- Save the game

```gdscript
# In pickup_component.gd:
func _collect(collector: Node2D) -> void:
	if not multiplayer.is_server():
		return  # Only host processes pickups
	
	# ... existing collection logic
	_collect_rpc.rpc_id(collector.get_multiplayer_authority())

@rpc("authority", "call_remote")
func _collect_rpc() -> void:
	# Play effects on client
	pass
```

### 6. **Camera Per Player**
Each player needs their own camera:
- PlayerController owns the camera
- Camera follows player's crew/ship
- Split-screen for local multiplayer (future)

## Testing Multiplayer

### Local Testing (Same Machine)
1. Run the game normally (Player 1 - Host)
2. Export and run a second instance with `--client` flag, or:
3. Run from command line:
   ```bash
   # Terminal 1 (Host)
   ./kasvu --host
   
   # Terminal 2 (Client)
   ./kasvu --join 127.0.0.1
   ```

### Network Testing (Different Machines)
1. Host needs to forward port 7777 (TCP/UDP)
2. Clients connect to host's public IP
3. Consider using Steam networking for easier connectivity

## Performance Considerations
- Only sync what's necessary (positions, health, not every frame of animation)
- Use delta compression where possible
- Host simulates physics, clients interpolate
- Despawn off-screen entities on clients

## Future Enhancements
- [ ] Voice chat integration
- [ ] Steam lobby integration  
- [ ] Reconnection support
- [ ] Latency compensation
- [ ] Client-side prediction for movement
- [ ] Spectator mode for dead players
- [ ] In-game chat

