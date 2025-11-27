extends Node

signal level_up(new_level: int)
signal experience_gained(amount: int, total: int)

@export var base_scroll_speed: float = 40.0
@export var base_laser_dps: float = 20.0
@export var base_enemy_speed: float = 60.0
@export var base_trawler_speed: float = 5.0

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

# Save/load system
var save_data: Dictionary = {}
const SAVE_FILE_PATH: String = "user://savegame.save"  

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

## Save game state to file
func save_game() -> bool:
	if RunManager == null:
		push_warning("GameState: RunManager not available for saving")
		return false
	
	# Collect save data
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
			"xp_to_next_level": xp_to_next_level
		}
	}
	
	# Save to file
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: Failed to open save file for writing")
		return false
	
	var json_string := JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()
	
	print("GameState: Game saved successfully")
	return true

## Load game state from file
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		push_warning("GameState: No save file found")
		return false
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
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
		spawn_rate_multiplier = gs.get("spawn_rate_multiplier", 200.0)
		current_level = gs.get("current_level", 1)
		current_xp = gs.get("current_xp", 0)
		xp_to_next_level = gs.get("xp_to_next_level", 30)
	
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
	return FileAccess.file_exists(SAVE_FILE_PATH)

## Delete save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE_PATH))
		print("GameState: Save file deleted")
