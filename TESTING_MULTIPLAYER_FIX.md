# Quick Testing Guide - Multiplayer Fix

## How to Test the Fix

### Test 1: Singleplayer Still Works
1. Launch the game normally
2. Click "START GAME" from main menu
3. Verify you can control your ship with WASD
4. Verify weapons fire correctly
5. Verify camera follows your ship
6. **Expected:** Everything works exactly as before

### Test 2: Two Player Local Multiplayer
1. Launch first instance (Player 1):
   - Click "HOST MULTIPLAYER"
   - Wait in lobby
   
2. Launch second instance (Player 2):
   ```bash
   godot --path /home/nolan/Games/kasvu
   ```
   - Click "JOIN MULTIPLAYER"
   - Leave IP as 127.0.0.1
   - Click CONNECT
   
3. Player 1: Click "START GAME" in lobby

4. **Test Controls:**
   - Player 1: Press WASD - only your ship should move
   - Player 2: Press WASD - only your ship should move
   - **Expected:** Each player controls ONLY their own ship
   
5. **Test Weapons:**
   - Player 1: Move mouse around - only your ship's weapons fire
   - Player 2: Move mouse around - only your ship's weapons fire
   - **Expected:** Weapons fire from correct ship only
   
6. **Test Camera:**
   - Player 1: Your camera should follow only your ship
   - Player 2: Your camera should follow only your ship
   - **Expected:** Each player's camera is independent

### Test 3: Verify Synchronization
1. With two players connected:
   - Player 1: Move your ship
   - Player 2: You should see Player 1's ship moving smoothly
   - Player 2: Move your ship
   - Player 1: You should see Player 2's ship moving smoothly
   - **Expected:** Both players see each other's ships moving

### Test 4: Verify You Can't Control Other Ships
1. With two players connected:
   - Player 1: Press WASD
   - Player 2: Watch Player 1's ship - press WASD
   - **Expected:** Your keys do NOT control the other player's ship

## Common Issues & Solutions

### Issue: Still controlling all ships
**Solution:** Check console output:
```
Level_Mine: Configured PlayerController and Ship for peer 1
Level_Mine: Configured PlayerController and Ship for peer 2
```
If you see the same peer_id for both, there's a networking issue.

### Issue: Ships don't move at all
**Solution:** This shouldn't happen, but if it does:
1. Check if `is_multiplayer_authority()` is always returning false
2. Verify you're in the correct scene (main_menu -> lobby -> game)
3. Try restarting both instances

### Issue: Weapons not firing
**Solution:** 
1. Check if WeaponManager is properly attached to ship
2. Verify starting weapon is assigned in ship scene
3. Check console for weapon-related errors

### Issue: Camera not following
**Solution:**
1. Camera should be a child of the ship node
2. Only the local player's camera should be active
3. Check PlayerController's _update_camera() logs

## Console Output to Look For

### Successful multiplayer session should show:
```
NetworkManager: Server created on port 7777
NetworkManager: Player registered - Peer ID: 1
NetworkManager: Player connected - Peer ID: 2
NetworkManager: Player registered - Peer ID: 2
Level_Mine: Configured PlayerController and Ship for peer 1 at dock ShipDock1
Level_Mine: Configured PlayerController and Ship for peer 2 at dock ShipDock2
```

### When moving your ship:
```
(Your client processes input because is_multiplayer_authority() returns true)
(Other clients receive position updates via MultiplayerSynchronizer)
```

## Performance Notes
- Each ship syncs at ~60Hz (every frame)
- Movement should feel smooth and responsive
- Minimal lag on local network (127.0.0.1)
- Some lag expected over internet

## Next Steps After Testing
1. If singleplayer works: ✅ Authority checks didn't break existing gameplay
2. If multiplayer works: ✅ The fix is complete!
3. If issues remain: Check the console logs and report what you see

## Advanced Debugging
Add these debug prints if needed:

### In player_ship.gd _physics_process():
```gdscript
if Input.is_action_pressed("move_up"):
    print("Ship %d processing input, authority: %s" % [ship_id, is_multiplayer_authority()])
```

### In weapon_manager.gd _process():
```gdscript
print("WeaponManager processing, owner_ship authority: %s" % owner_ship.is_multiplayer_authority())
```

These will help identify if authority checks are working correctly.
