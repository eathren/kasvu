extends Node

signal level_up(new_level: int)
signal experience_gained(amount: int, total: int)

@export var base_scroll_speed: float = 40.0
@export var base_laser_dps: float = 20.0
@export var base_enemy_speed: float = 60.0
@export var base_trawler_speed: float = 5.0
@export var tile_size: int = 16
# how many tiles wide we mine in front of the ship
@export var base_mine_width_tiles: int = 8

var scroll_multiplier: float = 1.0
var laser_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0
var trawler_speed_multiplier: float = 1.0
var mine_width_multiplier: float = 1.0
var spawn_rate_multiplier: float = 200.0

# XP and Level system
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 30  # Level 1 requires 30 XP

# Weapon and Upgrade system
var unlocked_weapons: Array[int] = [0]  # Start with LASER (0)
var weapon_levels: Dictionary = {0: 1}  # Weapon type -> level
var fire_rate_multiplier: float = 1.0
var weapon_damage_multiplier: float = 1.0
var ship_speed_multiplier: float = 1.0
var pickup_range_multiplier: float = 1.0  # Affects how far pickups are attracted from

# Resource tracking
var kills: int = 0
var gold: int = 0
var scrap: int = 0

# Resource signals
signal kills_changed(new_count: int)
signal gold_changed(new_count: int)
signal scrap_changed(new_count: int)

# Ship spawning lock (prevent multiple spawns)
var is_spawning_player_ship: bool = false

# Save/load system
var save_data: Dictionary = {}
var current_save_slot: int = 1  # 1-3
const SAVE_FILE_PATH_TEMPLATE: String = "user://savegame_slot_%d.save"

func get_save_file_path(slot: int = -1) -> String:
	"""Get the save file path for a specific slot"""
	var save_slot := slot if slot > 0 else current_save_slot
	return SAVE_FILE_PATH_TEMPLATE % save_slot

func save_slot_exists(slot: int) -> bool:
	"""Check if a save slot has data"""
	return FileAccess.file_exists(get_save_file_path(slot))

func get_save_slot_info(slot: int) -> Dictionary:
	"""Get info about a save slot without fully loading it"""
	if not save_slot_exists(slot):
		return {"exists": false}
	
	var file := FileAccess.open(get_save_file_path(slot), FileAccess.READ)
	if file == null:
		return {"exists": false}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {"exists": false}
	
	var data := json.data as Dictionary
	return {
		"exists": true,
		"level": data.get("level", 1),
		"kills": data.get("game_state", {}).get("kills", 0),
		"playtime": data.get("level_start_time", 0.0)
	}

func reset_run() -> void:
	"""Reset all run-specific stats for a new game"""
	current_level = 1
	current_xp = 0
	xp_to_next_level = 30
	kills = 0
	gold = 0
	scrap = 0
	
	# Reset multipliers to base
	scroll_multiplier = 1.0
	laser_multiplier = 1.0
	enemy_speed_multiplier = 1.0
	trawler_speed_multiplier = 1.0
	mine_width_multiplier = 1.0
	
	# Reset weapons (keep base weapon)
	unlocked_weapons = [0]
	weapon_levels = {0: 1}
	fire_rate_multiplier = 1.0
	weapon_damage_multiplier = 1.0
	ship_speed_multiplier = 1.0
	pickup_range_multiplier = 1.0
	
	print("GameState: Run reset to defaults")  

func get_scroll_speed() -> float:
	return base_scroll_speed * scroll_multiplier

func get_laser_dps() -> float:
	return base_laser_dps * laser_multiplier

func get_enemy_speed() -> float:
	return base_enemy_speed * enemy_speed_multiplier

func get_trawler_speed() -> float:
	return base_trawler_speed * trawler_speed_multiplier

func get_mine_width_tiles() -> int:
	return int(round(base_mine_width_tiles * mine_width_multiplier))

func get_spawn_rate_multiplier() -> float:
	return spawn_rate_multiplier

## Add experience and handle level ups
func add_experience(amount: int) -> void:
	current_xp += amount
	experience_gained.emit(amount, current_xp)
	
	# Check for level up
	while current_xp >= xp_to_next_level:
		_level_up()

func _level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	
	# Lockstep scaling: Level n requires 30 * n XP
	xp_to_next_level = 30 * current_level
	
	# Slow down time to 5% speed (95% slowdown)
	Engine.time_scale = 0.05
	
	level_up.emit(current_level)
	print("GameState: Level up! Now level ", current_level, " (need ", xp_to_next_level, " XP for next level)")

func get_level() -> int:
	return current_level

func get_xp() -> int:
	return current_xp

func get_xp_to_next_level() -> int:
	return xp_to_next_level

func get_xp_progress() -> float:
	if xp_to_next_level <= 0:
		return 0.0
	return float(current_xp) / float(xp_to_next_level)

## Weapon and upgrade system
func get_unlocked_weapons() -> Array[int]:
	return unlocked_weapons

func unlock_weapon(weapon_type: int) -> void:
	if weapon_type not in unlocked_weapons:
		unlocked_weapons.append(weapon_type)
		weapon_levels[weapon_type] = 1
		print("GameState: Unlocked weapon type ", weapon_type)

func upgrade_weapon(weapon_type: int) -> void:
	if weapon_type in weapon_levels:
		weapon_levels[weapon_type] += 1
		print("GameState: Upgraded weapon ", weapon_type, " to level ", weapon_levels[weapon_type])

func get_weapon_level(weapon_type: int) -> int:
	return weapon_levels.get(weapon_type, 0)

func get_fire_rate_multiplier() -> float:
	return fire_rate_multiplier

func set_fire_rate_multiplier(value: float) -> void:
	fire_rate_multiplier = value
	print("GameState: Fire rate multiplier set to ", value)

func get_weapon_damage_multiplier() -> float:
	return weapon_damage_multiplier

func set_weapon_damage_multiplier(value: float) -> void:
	weapon_damage_multiplier = value
	print("GameState: Weapon damage multiplier set to ", value)

func get_ship_speed_multiplier() -> float:
	return ship_speed_multiplier

func set_ship_speed_multiplier(value: float) -> void:
	ship_speed_multiplier = value
	print("GameState: Ship speed multiplier set to ", value)

func get_pickup_range_multiplier() -> float:
	return pickup_range_multiplier

func set_pickup_range_multiplier(value: float) -> void:
	pickup_range_multiplier = value
	print("GameState: Pickup range multiplier set to ", value)

## Resource management
func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)

func get_kills() -> int:
	return kills

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)
	print("GameState: +", amount, " gold (total: ", gold, ")")

func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	print("GameState: -", amount, " gold (total: ", gold, ")")
	return true

func get_gold() -> int:
	return gold

func add_scrap(amount: int) -> void:
	if amount <= 0:
		return
	scrap += amount
	scrap_changed.emit(scrap)
	print("GameState: +", amount, " scrap (total: ", scrap, ")")

func spend_scrap(amount: int) -> bool:
	if amount <= 0 or scrap < amount:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	print("GameState: -", amount, " scrap (total: ", scrap, ")")
	return true

func get_scrap() -> int:
	return scrap

## Save game state to file
func save_game(slot: int = -1) -> bool:
	if slot > 0:
		current_save_slot = slot
	
	if RunManager == null:
		push_warning("GameState: RunManager not available for saving")
		return false
	
	save_data = {
		"level": RunManager.current_level_num,
		"level_start_time": RunManager.level_start_time,
		"seed": RunManager.current_seed,
		"game_state": {
			"scroll_multiplier": scroll_multiplier,
			"laser_multiplier": laser_multiplier,
			"enemy_speed_multiplier": enemy_speed_multiplier,
			"trawler_speed_multiplier": trawler_speed_multiplier,
			"mine_width_multiplier": mine_width_multiplier,
			"spawn_rate_multiplier": spawn_rate_multiplier,
			"current_level": current_level,
			"current_xp": current_xp,
			"xp_to_next_level": xp_to_next_level,
			"unlocked_weapons": unlocked_weapons,
			"weapon_levels": weapon_levels,
			"fire_rate_multiplier": fire_rate_multiplier,
			"weapon_damage_multiplier": weapon_damage_multiplier,
			"ship_speed_multiplier": ship_speed_multiplier,
			"pickup_range_multiplier": pickup_range_multiplier,
			"kills": kills,
			"gold": gold,
			"scrap": scrap
		}
	}
	
	# Save to file
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(get_save_file_path(), FileAccess.WRITE)
	if file == null:
		push_error("GameState: Failed to open save file for writing")
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("GameState: Game saved successfully to slot ", current_save_slot)
	return true

## Load game state from file
func load_game(slot: int = -1) -> bool:
	if slot > 0:
		current_save_slot = slot
	
	if not save_slot_exists(current_save_slot):
		push_warning("GameState: No save file found in slot ", current_save_slot)
		return false
	
	var file := FileAccess.open(get_save_file_path(), FileAccess.READ)
	if file == null:
		push_error("GameState: Failed to open save file for reading")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("GameState: Failed to parse save file JSON")
		return false
	
	save_data = json.data as Dictionary
	
	# Restore game state
	if save_data.has("game_state"):
		var gs := save_data["game_state"] as Dictionary
		scroll_multiplier = gs.get("scroll_multiplier", 1.0)
		laser_multiplier = gs.get("laser_multiplier", 1.0)
		enemy_speed_multiplier = gs.get("enemy_speed_multiplier", 1.0)
		trawler_speed_multiplier = gs.get("trawler_speed_multiplier", 1.0)
		mine_width_multiplier = gs.get("mine_width_multiplier", 1.0)
		spawn_rate_multiplier = gs.get("spawn_rate_multiplsaier", 200.0)
		current_level = gs.get("current_level", 1)
		current_xp = gs.get("current_xp", 0)
		xp_to_next_level = gs.get("xp_to_next_level", 30)
		var loaded_weapons: Array = gs.get("unlocked_weapons", [0])
		unlocked_weapons.clear()
		for weapon in loaded_weapons:
			unlocked_weapons.append(weapon as int)
		weapon_levels = gs.get("weapon_levels", {0: 1})
		fire_rate_multiplier = gs.get("fire_rate_multiplier", 1.0)
		weapon_damage_multiplier = gs.get("weapon_damage_multiplier", 1.0)
		ship_speed_multiplier = gs.get("ship_speed_multiplier", 1.0)
		pickup_range_multiplier = gs.get("pickup_range_multiplier", 1.0)
		kills = gs.get("kills", 0)
		gold = gs.get("gold", 0)
		scrap = gs.get("scrap", 0)
	
	# Restore level state
	if RunManager != null and save_data.has("level"):
		var level := save_data.get("level", 1) as int
		var start_time := save_data.get("level_start_time", 0.0) as float
		var seed_val := save_data.get("seed", 0) as int
		
		RunManager.current_level_num = level
		RunManager.level_start_time = start_time
		RunManager.current_seed = seed_val
	
	print("GameState: Game loaded successfully")
	return true

## Check if save file exists
func has_save_file() -> bool:
	return save_slot_exists(current_save_slot)

## Delete save file
func delete_save(slot: int = -1) -> void:
	if slot > 0:
		current_save_slot = slot
	var save_path := get_save_file_path()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		print("GameState: Save file deleted from slot ", current_save_slot)
