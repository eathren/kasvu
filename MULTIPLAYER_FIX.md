# Multiplayer Authority Fix

## Problem
Players were controlling all ships simultaneously instead of just their own. This was caused by missing multiplayer authority checks in the input processing code.

## Root Cause
In Godot's multiplayer system, each node can have a "multiplayer authority" assigned to it. When a node is spawned for a specific peer (player), only that peer should process input for that node. However, the code was missing `is_multiplayer_authority()` checks, so ALL clients were processing input for ALL ships.

## Files Fixed

### 1. `/entities/player/player_controller.gd`
**Added authority checks to:**
- `control_crew()` - Only the owning player can switch to crew control
- `control_ship()` - Only the owning player can take control of a ship
- `request_dock()` - Only the owning player can request docking
- `_update_camera()` - Only the owning player manages their camera
- `_control_parent_ship()` - Only the owning player can control their ship

### 2. `/entities/player/ships/player_ship/player_ship.gd`
**Added authority checks to:**
- `_physics_process()` - Only process movement input if this is the local player's ship
- `_input()` - Only process input events (docking, dashing) if this is the local player's ship

### 3. `/scripts/weapons/weapon_manager.gd`
**Added authority check to:**
- `_process()` - Only fire weapons if this is the local player's ship (prevents all players from firing all ships' weapons)

### 4. `/entities/player/crew/player.gd`
**Added authority check to:**
- `_physics_process()` - Only process movement input if this is the local player's crew

### 5. `/levels/mine/level_mine.gd`
**Fixed authority assignment:**
- Added `ship.set_multiplayer_authority(peer_id)` to properly assign the ship to its owner
- This ensures the ship's MultiplayerSynchronizer knows which peer owns it

## How It Works Now

### Singleplayer
- Player ID defaults to 1
- All authority checks pass (multiplayer.get_unique_id() returns 1 in singleplayer)
- No changes to gameplay

### Multiplayer
1. Each player gets assigned a unique peer_id (1, 2, 3, 4, etc.)
2. When a ship spawns for a player, both the PlayerController and the ship get `set_multiplayer_authority(peer_id)` called
3. Each client receives the ship data, but only the owning client has `is_multiplayer_authority()` return true
4. Input processing only happens on the client that owns the ship
5. MultiplayerSynchronizer automatically syncs position/rotation/velocity to other clients
6. Other clients see the ship move smoothly but cannot control it

## Testing Checklist

- [x] Add multiplayer authority checks to all input processing
- [x] Assign multiplayer authority to ships when spawned
- [x] Assign multiplayer authority to controllers when spawned
- [x] Verify no compilation errors
- [ ] Test singleplayer (should work exactly as before)
- [ ] Test multiplayer with 2 players (each should only control their own ship)
- [ ] Test multiplayer with 3-4 players
- [ ] Verify weapons only fire from the correct ship
- [ ] Verify camera follows only the player's own ship
- [ ] Verify dashing/docking only affects the player's own ship

## Key Godot Multiplayer Concepts

### `is_multiplayer_authority()`
Returns true only on the client that owns this node. Used to prevent other clients from processing input for nodes they don't own.

### `set_multiplayer_authority(peer_id)`
Assigns ownership of a node to a specific peer. Must be called on the server/host, and automatically replicates to all clients.

### `MultiplayerSynchronizer`
Automatically syncs specified properties (position, rotation, velocity) from the authority peer to all other peers. The ship's .tscn already had this configured correctly.

## What Was Already Working

- ✅ MultiplayerSynchronizer configuration in player_ship.tscn
- ✅ Level spawning logic for multiple players
- ✅ Network connection/disconnection handling
- ✅ Enemy spawning (host authority)
- ✅ Pickup collection (host authority)

## What Was Broken

- ❌ All players controlling all ships (FIXED)
- ❌ All players firing all ships' weapons (FIXED)
- ❌ Camera switching between all ships (FIXED)
- ❌ Input being processed for all entities (FIXED)

## Next Steps

1. Test the game in singleplayer to ensure nothing broke
2. Test with 2 players locally (use `godot --path /home/nolan/Games/kasvu` for second instance)
3. Test with 3-4 players if possible
4. Monitor console for any authority-related errors
5. If issues persist, check the console output for which peer_id is assigned to which player

## Debugging Tips

If you see all players still controlling all ships:
1. Check console output: "Level_Mine: Configured PlayerController and Ship for peer X"
2. Verify each player has a different peer_id
3. Add debug prints: `print("Processing input for ship, authority:", is_multiplayer_authority())`
4. Ensure `multiplayer.is_server()` is true on the host
5. Verify MultiplayerSynchronizer is enabled on the ship node

## Additional Notes

- The crew avatar system isn't currently used (only ships spawn), but it has authority checks in place for future use
- ShipDock spawning doesn't need authority checks since it runs on the host during level initialization
- The trawler and enemies are host-controlled, so they don't need per-player authority checks
