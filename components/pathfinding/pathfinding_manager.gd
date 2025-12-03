extends Node
class_name PathfindingManager

## Manages multiple PathfindingGrid instances around different targets
## Creates grids around trawler and player ships for distributed pathfinding

signal grids_updated()

@export var grid_chunk_size: int = 500  # Size of each grid window
@export var grid_tile_size: int = 16  # Tile size in pixels
@export var update_frequency: float = 0.5  # Grid update rate
@export var player_grid_distance: float = 300.0  # Min distance from trawler to create player grid

var wall_layer: TileMapLayer = null
var grids: Dictionary = {}  # target_id -> PathfindingGrid
var update_timer: float = 0.0

# Track which entities should have grids
var tracked_targets: Dictionary = {}  # Node -> String (display name)

func _ready() -> void:
	add_to_group("pathfinding_manager")
	print("PathfindingManager: Initialized")

func setup(tilemap: TileMapLayer, initial_world_pos: Vector2 = Vector2.ZERO) -> void:
	"""Initialize the manager with the wall tilemap"""
	wall_layer = tilemap
	print("PathfindingManager: Setup with tilemap")
	
	# Create initial grids for existing targets
	_update_tracked_targets()
	_update_grids()

func _process(delta: float) -> void:
	update_timer += delta
	
	if update_timer >= update_frequency:
		update_timer = 0.0
		_update_tracked_targets()
		_update_grids()

func _update_tracked_targets() -> void:
	"""Update the list of entities that should have pathfinding grids"""
	var new_targets: Dictionary = {}
	
	# Always track trawler
	var trawler = get_tree().get_first_node_in_group("trawler")
	if trawler:
		new_targets[trawler] = "trawler"
	
	# Track player ships if they're far from trawler
	var player_ships = get_tree().get_nodes_in_group("player_ship")
	for ship in player_ships:
		if not is_instance_valid(ship):
			continue
		
		var ship_node := ship as Node2D
		if not ship_node:
			continue
		
		# Check distance from trawler
		if trawler:
			var distance := ship_node.global_position.distance_to(trawler.global_position)
			if distance > player_grid_distance:
				new_targets[ship_node] = "player_ship_%d" % ship_node.get_instance_id()
	
	# Remove grids for targets that no longer exist
	for target in tracked_targets.keys():
		if not new_targets.has(target):
			_remove_grid(target)
	
	tracked_targets = new_targets

func _update_grids() -> void:
	"""Create or update grids for all tracked targets"""
	if not wall_layer:
		return
	
	for target in tracked_targets.keys():
		if not is_instance_valid(target):
			continue
		
		var target_node := target as Node2D
		if not target_node:
			continue
		
		# Create grid if it doesn't exist
		if not grids.has(target):
			_create_grid_for_target(target_node, tracked_targets[target])
		else:
			# Update existing grid center
			var grid: PathfindingGrid = grids[target]
			if grid:
				grid._update_center(target_node.global_position)

func _create_grid_for_target(target: Node2D, target_name: String) -> void:
	"""Create a new pathfinding grid centered on a target"""
	var grid := PathfindingGrid.new()
	grid.name = "Grid_%s" % target_name
	grid.chunk_size = grid_chunk_size
	grid.tile_size = grid_tile_size
	grid.update_frequency = update_frequency
	
	add_child(grid)
	# Pass the initial position to properly seed the center
	grid.setup(wall_layer, target.global_position)
	
	grids[target] = grid
	var target_local := wall_layer.to_local(target.global_position)
	var target_tile := wall_layer.local_to_map(target_local)
	print("PathfindingManager: Created grid for %s at tile %s" % [target_name, target_tile])

func _remove_grid(target: Node) -> void:
	"""Remove a pathfinding grid"""
	if grids.has(target):
		var grid: PathfindingGrid = grids[target]
		if is_instance_valid(grid):
			grid.queue_free()
		grids.erase(target)
		tracked_targets.erase(target)

func update_tile(tile_pos: Vector2i, solid: bool) -> void:
	"""Update a tile in all relevant grids (solid=true blocks, solid=false allows movement)"""
	for grid in grids.values():
		if is_instance_valid(grid):
			grid.update_tile(tile_pos, solid)

func find_path(from_world: Vector2, to_world: Vector2, use_cache: bool = true) -> Array[Vector2]:
	"""Find a path using the most appropriate grid"""
	if not wall_layer:
		return []
	
	# Convert positions to tiles
	var from_local := wall_layer.to_local(from_world)
	var from_tile := wall_layer.local_to_map(from_local)
	
	# Find the grid that contains the start position
	var best_grid: PathfindingGrid = null
	var best_distance := INF
	
	for target in grids.keys():
		var grid: PathfindingGrid = grids[target]
		if not is_instance_valid(grid):
			continue
		
		# Check if this grid contains the start position
		var grid_pos := from_tile - grid.grid_offset
		var in_grid := grid._is_in_grid(grid_pos)
		
		if in_grid:
			# Prefer grids where the start is closer to center
			var distance_from_center := from_tile.distance_to(grid.current_center)
			if distance_from_center < best_distance:
				best_distance = distance_from_center
				best_grid = grid
	
	# Use the best grid to calculate path
	if best_grid:
		return best_grid.find_path(from_world, to_world, use_cache)
	
	# No suitable grid found
	return []

func is_position_walkable(world_pos: Vector2) -> bool:
	"""Check if a position is walkable using any available grid"""
	for grid in grids.values():
		if is_instance_valid(grid):
			if grid.is_position_walkable(world_pos):
				return true
	return false

func get_grid_count() -> int:
	"""Get the number of active grids"""
	return grids.size()

func get_debug_info() -> Dictionary:
	"""Get debug info about all grids"""
	var info := {
		"grid_count": grids.size(),
		"tracked_targets": tracked_targets.size(),
		"grids": []
	}
	
	for target in tracked_targets.keys():
		if grids.has(target):
			var grid: PathfindingGrid = grids[target]
			if is_instance_valid(grid):
				info["grids"].append({
					"name": tracked_targets[target],
					"center": grid.current_center,
					"cached_paths": grid.path_cache.size()
				})
	
	return info
