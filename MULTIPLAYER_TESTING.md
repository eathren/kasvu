# Multiplayer Testing Guide

## ✅ What's Implemented

### 1. Network Architecture
- Host-client model with ENet
- Up to 4 players supported
- MultiplayerSynchronizer on all key entities
- Host authority for game logic

### 2. Synchronized Entities
- ✅ PlayerShip (position, rotation, velocity)
- ✅ Trawler (position, rotation, velocity)
- ✅ Bullets (position, rotation)
- ✅ Enemies/Imp (position, rotation)

### 3. Host Authority
- ✅ Enemy spawning (host only)
- ✅ Pickup collection (host only)
- ✅ World generation (host only)
- ✅ Save/load (host only)

### 4. Multiplayer UI
- ✅ Main menu with host/join options
- ✅ Lobby screen showing connected players
- ✅ Host can start game from lobby
- ✅ Pause menu works in multiplayer

### 5. Player Management
- ✅ PlayerController spawned per peer
- ✅ Each player has their own crew avatar
- ✅ Each player has their own camera
- ✅ Late joiners are supported

## 🧪 Test Scenarios

### Test 1: Local Multiplayer (Same Machine)
**Setup:**
1. Run Godot instance 1: Click F5 or run from editor
2. Export project and run instance 2: `godot --path . --windowed`

**Steps:**
1. Instance 1: Click "HOST MULTIPLAYER" → Should see lobby
2. Instance 2: Click "JOIN MULTIPLAYER" → Enter `127.0.0.1` → Click "CONNECT"
3. Both instances: Should see lobby with 2 players listed
4. Instance 1: Click "START GAME"
5. Both instances: Should load into mine level

**Expected:**
- Both players spawn in trawler
- Both players can move independently
- Enemies spawn (visible to both)
- Pickups work (host processes, both see collection)
- Bullets from both players hit enemies

### Test 2: Host Authority
**Steps:**
1. Start 2-player game (see Test 1)
2. Player 1 (host): Kill an enemy
3. Player 2 (client): Try to kill an enemy
4. Player 1 (host): Collect a pickup
5. Player 2 (client): Try to collect a pickup

**Expected:**
- Both players can damage/kill enemies
- Pickups are collected by host, clients see them disappear
- Enemy spawning only happens once (no duplicates)

### Test 3: Player Spawning
**Steps:**
1. Start 2-player game
2. Both players undock ships (press E at ladder)
3. Both players control their ships
4. Both players return to dock (press E near ship dock)

**Expected:**
- 2 separate PlayerShips spawn
- Each player controls their own ship
- Ships move independently
- Docking works for both

### Test 4: Late Joiner
**Steps:**
1. Start host game solo
2. Play for 1 minute
3. Have client join mid-game

**Expected:**
- Client joins successfully
- Client sees current game state
- New PlayerController spawns for client
- Client can undock and play

### Test 5: Save/Load in Multiplayer
**Steps:**
1. Start 2-player game as host
2. Host presses ESC → "SAVE GAME"
3. Both quit to menu
4. Host: "LOAD GAME" → Load the save
5. Client: "JOIN MULTIPLAYER" → Connect to host

**Expected:**
- Save works (host only)
- Load restores game state
- Client can rejoin and continue

### Test 6: Disconnection Handling
**Steps:**
1. Start 2-player game
2. Client closes their window
3. Host continues playing
4. Or: Host closes their window

**Expected:**
- When client disconnects: Host continues, client's PlayerController is cleaned up
- When host disconnects: Client returns to main menu

## 🐛 Known Issues & Limitations

### Issue 1: World Not Synced to Clients
**Problem:** Clients don't see the generated tiles
**Status:** Known limitation - clients would need RPC to sync tiles
**Workaround:** For now, only host sees full world

**Fix (if needed):**
```gdscript
# In level_mine.gd
func _apply_tiles(level_data: Dictionary) -> void:
	# Apply locally
	# ...
	
	# Sync to clients
	if multiplayer.is_server():
		_sync_tiles_to_clients.rpc(level_data["wall_cells"])

@rpc("authority", "call_remote")
func _sync_tiles_to_clients(wall_cells: Array) -> void:
	for cell in wall_cells:
		wall.set_cell(cell, 5, Vector2i(1, 1))
```

### Issue 2: Crew Avatar Might Not Sync
**Problem:** Crew avatar doesn't have MultiplayerSynchronizer
**Status:** Should be added if crew movement needs sync
**Workaround:** Each player's crew is only visible to them

**Fix (if needed):**
Add MultiplayerSynchronizer to `entities/player/crew/player.tscn`

### Issue 3: Performance with Many Enemies
**Problem:** Syncing 100+ enemies can cause lag
**Status:** Expected with current sync rate
**Optimization:** Increase `replication_interval` for enemies to 0.2

## 📊 Performance Tips

### Reduce Network Traffic
1. **Increase replication intervals:**
   - Enemies: 0.1-0.2 seconds (currently 0.1)
   - Trawler: 0.05 seconds (currently 0.05)
   - Bullets: Keep at 0.0 for accuracy

2. **Sync only what's on screen:**
   - Despawn enemies far from trawler
   - Don't sync bullets beyond their lifetime

3. **Use delta compression:**
   - Already enabled with `delta_interval = 0.0`

### Network Bandwidth
- ~10KB/s per player @ 30 enemies
- ~20KB/s per player @ 60 enemies
- Total upload for host: ~60KB/s for 4 players

## 🎮 How to Run Multiple Instances

### Method 1: Editor + Export
```bash
# Terminal 1: Run from editor
(Just press F5 in Godot)

# Terminal 2: Run exported version
cd /home/nolan/Games/kasvu
godot --path . --windowed
```

### Method 2: Multiple Godot Instances
```bash
# Terminal 1
godot --path /home/nolan/Games/kasvu &

# Terminal 2
godot --path /home/nolan/Games/kasvu &
```

### Method 3: Export and Run
```bash
# Export project first: Project → Export → Linux
# Then run multiple times:
./kasvu.x86_64 &
./kasvu.x86_64 &
```

## ✅ Checklist Before Release

- [ ] Test 2-player local multiplayer
- [ ] Test 4-player local multiplayer
- [ ] Test over LAN
- [ ] Test host authority (pickups, enemies)
- [ ] Test save/load in multiplayer
- [ ] Test disconnection handling
- [ ] Test late joiner
- [ ] Performance test with 50+ enemies
- [ ] Test all 4 ship docks with 4 players
- [ ] Test pause menu in multiplayer

## 🚀 Next Improvements

1. **Add world sync RPC** - So clients see tiles
2. **Add crew sync** - So players see each other's crew
3. **Add reconnect support** - Resume after disconnect
4. **Add spectator mode** - For dead players
5. **Add in-game chat** - Text communication
6. **Add voice chat** - Via Steam or Discord SDK
7. **Add ready system** - Players mark ready in lobby
8. **Add kick player** - Host can kick misbehaving players

