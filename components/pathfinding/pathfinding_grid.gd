extends Node
class_name PathfindingGrid

## Grid-based pathfinding system for dynamic tile-based navigation
## Updates as walls are mined, maintains a window around the trawler

signal grid_updated()

@export var chunk_size: int = 500  # Size of the pathfinding window in tiles
@export var tile_size: int = 16  # Size of each tile in pixels
@export var update_frequency: float = 0.5  # How often to shift the window (seconds)
@export var diagonal_cost_multiplier: float = 1.414  # sqrt(2) for diagonal movement

var astar_grid: AStarGrid2D = null
var current_center: Vector2i = Vector2i.ZERO  # Center of the grid in world tile coordinates
var grid_offset: Vector2i = Vector2i.ZERO  # Top-left corner of the grid
var wall_layer: TileMapLayer = null
var update_timer: float = 0.0

# Cache for recently calculated paths
var path_cache: Dictionary = {}  # Key: "start_x,start_y|end_x,end_y" -> Array[Vector2]
var cache_lifetime: float = 2.0  # How long cached paths are valid
var cache_times: Dictionary = {}  # Key -> timestamp

func _ready() -> void:
	add_to_group("pathfinding_grid")
	_initialize_grid()

func setup(tilemap: TileMapLayer) -> void:
	"""Initialize the pathfinding grid with a tilemap reference"""
	wall_layer = tilemap
	if wall_layer:
		print("PathfindingGrid: Setup with tilemap")
		_rebuild_grid()

func _initialize_grid() -> void:
	"""Create the AStarGrid2D instance"""
	astar_grid = AStarGrid2D.new()
	astar_grid.size = Vector2i(chunk_size, chunk_size)
	astar_grid.cell_size = Vector2(tile_size, tile_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	
	# Set all cells to walkable by default
	astar_grid.fill_solid_region(Rect2i(0, 0, chunk_size, chunk_size), false)
	astar_grid.update()
	
	print("PathfindingGrid: Initialized %dx%d grid" % [chunk_size, chunk_size])

func _process(delta: float) -> void:
	update_timer += delta
	
	if update_timer >= update_frequency:
		update_timer = 0.0
		_check_window_shift()
	
	# Clean old cached paths
	_clean_path_cache()

func _check_window_shift() -> void:
	"""Check if the trawler has moved far enough to shift the grid window"""
	var trawler = get_tree().get_first_node_in_group("trawler")
	if not trawler or not wall_layer:
		return
	
	# Get trawler position in tile coordinates
	var trawler_world_pos: Vector2 = trawler.global_position
	var trawler_local := wall_layer.to_local(trawler_world_pos)
	var trawler_tile := wall_layer.local_to_map(trawler_local)
	
	# Check if we need to recenter
	var distance_from_center := trawler_tile.distance_to(current_center)
	var shift_threshold := chunk_size / 4  # Shift when trawler moves 25% away from center
	
	if distance_from_center > shift_threshold:
		current_center = trawler_tile
		_rebuild_grid()

func _rebuild_grid() -> void:
	"""Rebuild the entire pathfinding grid based on current tile state"""
	if not wall_layer or not astar_grid:
		return
	
	# Calculate grid offset (top-left corner)
	grid_offset = current_center - Vector2i(chunk_size / 2, chunk_size / 2)
	
	# Update all cells based on wall tiles
	for y in range(chunk_size):
		for x in range(chunk_size):
			var world_tile := grid_offset + Vector2i(x, y)
			var is_solid := _is_tile_solid(world_tile)
			astar_grid.set_point_solid(Vector2i(x, y), is_solid)
	
	astar_grid.update()
	
	# Clear path cache since grid changed
	path_cache.clear()
	cache_times.clear()
	
	grid_updated.emit()
	print("PathfindingGrid: Rebuilt grid centered at tile %s" % current_center)

func _is_tile_solid(tile_pos: Vector2i) -> bool:
	"""Check if a tile position has a wall (is solid/blocked)"""
	if not wall_layer:
		return false
	
	var source_id := wall_layer.get_cell_source_id(tile_pos)
	return source_id != -1  # -1 means no tile (walkable)

func update_tile(tile_pos: Vector2i, is_solid: bool) -> void:
	"""Update a single tile's walkability (called when tile is mined)"""
	if not astar_grid:
		return
	
	# Convert world tile position to grid position
	var grid_pos := tile_pos - grid_offset
	
	# Check if this tile is within our current window
	if grid_pos.x < 0 or grid_pos.x >= chunk_size or grid_pos.y < 0 or grid_pos.y >= chunk_size:
		return  # Outside our current window
	
	astar_grid.set_point_solid(grid_pos, is_solid)
	astar_grid.update()
	
	# Invalidate cached paths that might be affected
	_invalidate_paths_near(tile_pos)

func find_path(from_world: Vector2, to_world: Vector2, use_cache: bool = true) -> Array[Vector2]:
	"""Get a path from world position to world position"""
	if not wall_layer or not astar_grid:
		return []
	
	# Convert world positions to tile positions
	var from_local := wall_layer.to_local(from_world)
	var to_local := wall_layer.to_local(to_world)
	var from_tile := wall_layer.local_to_map(from_local)
	var to_tile := wall_layer.local_to_map(to_local)
	
	# Check cache
	if use_cache:
		var cache_key := "%d,%d|%d,%d" % [from_tile.x, from_tile.y, to_tile.x, to_tile.y]
		if path_cache.has(cache_key):
			return path_cache[cache_key]
	
	# Convert to grid positions
	var from_grid := from_tile - grid_offset
	var to_grid := to_tile - grid_offset
	
	# Check if positions are within grid
	if not _is_in_grid(from_grid) or not _is_in_grid(to_grid):
		return []
	
	# Calculate path on grid
	var grid_path := astar_grid.get_point_path(from_grid, to_grid)
	
	if grid_path.is_empty():
		return []
	
	# Convert grid path to world positions
	var world_path: Array[Vector2] = []
	for grid_point in grid_path:
		var tile_pos := Vector2i(grid_point) + grid_offset
		var local_pos := wall_layer.map_to_local(tile_pos)
		var world_pos := wall_layer.to_global(local_pos)
		world_path.append(world_pos)
	
	# Smooth path by removing redundant waypoints
	world_path = _smooth_path(world_path)
	
	# Cache the result
	if use_cache:
		var cache_key := "%d,%d|%d,%d" % [from_tile.x, from_tile.y, to_tile.x, to_tile.y]
		path_cache[cache_key] = world_path
		cache_times[cache_key] = Time.get_ticks_msec() / 1000.0
	
	return world_path

func _is_in_grid(grid_pos: Vector2i) -> bool:
	"""Check if a grid position is within bounds"""
	return grid_pos.x >= 0 and grid_pos.x < chunk_size and grid_pos.y >= 0 and grid_pos.y < chunk_size

func _smooth_path(path: Array[Vector2]) -> Array[Vector2]:
	"""Remove redundant waypoints using line-of-sight check"""
	if path.size() <= 2:
		return path
	
	var smoothed: Array[Vector2] = [path[0]]
	var current_idx := 0
	
	while current_idx < path.size() - 1:
		var farthest_visible := current_idx + 1
		
		# Find the farthest point we can see from current
		for i in range(current_idx + 2, path.size()):
			if _has_line_of_sight(path[current_idx], path[i]):
				farthest_visible = i
			else:
				break
		
		smoothed.append(path[farthest_visible])
		current_idx = farthest_visible
	
	return smoothed

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	"""Check if there's a clear line between two points"""
	if not wall_layer:
		return true
	
	var direction := (to - from).normalized()
	var distance := from.distance_to(to)
	var steps := int(distance / (tile_size / 2))  # Check every half-tile
	
	for i in range(1, steps):
		var check_pos := from + direction * (i * tile_size / 2)
		var check_local := wall_layer.to_local(check_pos)
		var check_tile := wall_layer.local_to_map(check_local)
		
		if _is_tile_solid(check_tile):
			return false
	
	return true

func _invalidate_paths_near(tile_pos: Vector2i, radius: int = 5) -> void:
	"""Invalidate cached paths near a changed tile"""
	var keys_to_remove: Array[String] = []
	
	for key in path_cache.keys():
		# Parse the key to get start/end tiles
		var parts = key.split("|")
		if parts.size() != 2:
			continue
		
		var start_parts = parts[0].split(",")
		var end_parts = parts[1].split(",")
		
		if start_parts.size() != 2 or end_parts.size() != 2:
			continue
		
		var start_tile := Vector2i(int(start_parts[0]), int(start_parts[1]))
		var end_tile := Vector2i(int(end_parts[0]), int(end_parts[1]))
		
		# Check if the path might be affected
		if tile_pos.distance_to(start_tile) < radius or tile_pos.distance_to(end_tile) < radius:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		path_cache.erase(key)
		cache_times.erase(key)

func _clean_path_cache() -> void:
	"""Remove expired cached paths"""
	var current_time := Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array[String] = []
	
	for key in cache_times.keys():
		if current_time - cache_times[key] > cache_lifetime:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		path_cache.erase(key)
		cache_times.erase(key)

func is_position_walkable(world_pos: Vector2) -> bool:
	"""Check if a world position is walkable"""
	if not wall_layer or not astar_grid:
		return false
	
	var local_pos := wall_layer.to_local(world_pos)
	var tile_pos := wall_layer.local_to_map(local_pos)
	var grid_pos := tile_pos - grid_offset
	
	if not _is_in_grid(grid_pos):
		return false
	
	return not astar_grid.is_point_solid(grid_pos)

func get_grid_info() -> Dictionary:
	"""Get debug info about the grid"""
	return {
		"center": current_center,
		"offset": grid_offset,
		"size": chunk_size,
		"cached_paths": path_cache.size()
	}
