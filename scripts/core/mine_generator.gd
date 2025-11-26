extends RefCounted
class_name MineGenerator

## Pure generation logic - works on data structures, not nodes
## Given a seed and config, outputs tile data and spawn positions

# Level configuration
var shaft_height_tiles: int = 3000
var shaft_width_tiles: int = 400  # Width on each side of trawler (800 total)
var starter_clearing_width_px: float = 500.0
var starter_clearing_height_px: float = 1000.0
var tile_size: float = 16.0

# Generation result data
var wall_cells: Array[Vector2i] = []
var trawler_start_cell: Vector2i = Vector2i.ZERO

func _init(config: Dictionary = {}) -> void:
	if config.has("shaft_height_tiles"):
		shaft_height_tiles = config["shaft_height_tiles"]
	if config.has("shaft_width_tiles"):
		shaft_width_tiles = config["shaft_width_tiles"]
	if config.has("starter_clearing_width_px"):
		starter_clearing_width_px = config["starter_clearing_width_px"]
	if config.has("starter_clearing_height_px"):
		starter_clearing_height_px = config["starter_clearing_height_px"]

## Generate level data from seed
## Returns a dictionary with wall_cells array and trawler_start_cell
func build_level(seed: int, trawler_start_cell_pos: Vector2i = Vector2i.ZERO) -> Dictionary:
	wall_cells.clear()
	
	# Use seed for random generation if needed (for now, deterministic)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed)
	
	# If no trawler position provided, use origin
	if trawler_start_cell_pos == Vector2i.ZERO:
		trawler_start_cell = Vector2i(0, 0)
	else:
		trawler_start_cell = trawler_start_cell_pos
	
	# Convert pixel clearing to tiles
	var clearing_width_tiles: int = int(ceil(starter_clearing_width_px / tile_size))
	var clearing_height_tiles: int = int(ceil(starter_clearing_height_px / tile_size))
	
	# Calculate shaft boundaries
	var left_x: int = trawler_start_cell.x - shaft_width_tiles
	var right_x: int = trawler_start_cell.x + shaft_width_tiles
	var top_y: int = trawler_start_cell.y - shaft_height_tiles
	var bottom_y: int = trawler_start_cell.y + clearing_height_tiles
	
	# Calculate clearing boundaries (centered on trawler)
	var clearing_left_x: int = trawler_start_cell.x - (clearing_width_tiles / 2)
	var clearing_right_x: int = trawler_start_cell.x + (clearing_width_tiles / 2)
	var clearing_top_y: int = trawler_start_cell.y - clearing_height_tiles
	var clearing_bottom_y: int = trawler_start_cell.y
	
	# Generate walls on left and right sides of shaft (around the clearing)
	for y in range(top_y, bottom_y + 1):
		# Left side of shaft (left of clearing)
		for x in range(left_x, clearing_left_x):
			wall_cells.append(Vector2i(x, y))
		
		# Right side of shaft (right of clearing)
		for x in range(clearing_right_x + 1, right_x + 1):
			wall_cells.append(Vector2i(x, y))
	
	# Generate walls above the clearing (top of shaft - solid wall)
	for y in range(top_y, clearing_top_y + 1):
		for x in range(left_x, right_x + 1):
			wall_cells.append(Vector2i(x, y))
	
	return {
		"wall_cells": wall_cells,
		"trawler_start_cell": trawler_start_cell,
		"clearing_bounds": {
			"left": clearing_left_x,
			"right": clearing_right_x,
			"top": clearing_top_y,
			"bottom": clearing_bottom_y
		}
	}
