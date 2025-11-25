extends Node

@export var base_scroll_speed: float = 40.0
@export var base_laser_dps: float = 20.0
@export var base_enemy_speed: float = 60.0
@export var base_trawler_speed: float = 30.0

# how many tiles wide we mine in front of the ship
@export var base_mine_width_tiles: int = 8

var scroll_multiplier: float = 1.0
var laser_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0
var trawler_speed_multiplier: float = 1.0
var mine_width_multiplier: float = 1.0

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
