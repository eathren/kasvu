extends Node

var ground_tilemap: TileMapLayer
var wall_tilemap: TileMapLayer

var _spawn_cells: Array[Vector2i] = []
var _wall_cells: Dictionary = {}

# Spawn preferences
@export var prefer_wall_edges: bool = true
@export var prefer_open_areas: bool = true
@export var min_distance_from_player: float = 200.0  # pixels
@export var open_area_radius: int = 3  # tiles - how many tiles should be clear around spawn point


func setup(ground: TileMapLayer, walls: TileMapLayer) -> void:
	ground_tilemap = ground
	wall_tilemap = walls
	_rebuild_spawn_cells()


func _rebuild_spawn_cells() -> void:
	_spawn_cells.clear()
	_wall_cells.clear()
	
	if ground_tilemap == null or wall_tilemap == null:
		push_error("SpawnManager.setup was not called correctly")
		return

	# Build a fast lookup of wall cells
	# If ground and wall are the same TileMapLayer, check atlas coordinates
	var is_same_tilemap := (ground_tilemap == wall_tilemap)
	
	if is_same_tilemap:
		# Same tilemap - distinguish by atlas coordinates
		# Wall tiles are typically at (0, 0), ground at (0, 1) based on wall.gd
		for cell in wall_tilemap.get_used_cells():
			var atlas_coord := wall_tilemap.get_cell_atlas_coords(cell)
			# Assume wall_atlas_coord is (0, 0) - adjust if needed
			if atlas_coord == Vector2i(0, 0):
				_wall_cells[cell] = true
	else:
		# Different tilemaps - all cells in wall_tilemap are walls
		for cell in wall_tilemap.get_used_cells():
			_wall_cells[cell] = true

	# Get all ground cells (cells that exist but aren't walls)
	var ground_cells := {}
	for cell in ground_tilemap.get_used_cells():
		if not _wall_cells.has(cell):
			ground_cells[cell] = true

	# Find valid spawn locations
	var wall_edge_cells: Array[Vector2i] = []
	var open_area_cells: Array[Vector2i] = []
	
	for cell in ground_cells.keys():
		var is_wall_edge := _is_adjacent_to_wall(cell)
		var is_open_area := _is_open_area(cell, ground_cells)
		
		if prefer_wall_edges and is_wall_edge:
			wall_edge_cells.append(cell)
		elif prefer_open_areas and is_open_area:
			open_area_cells.append(cell)
		elif not prefer_wall_edges and not prefer_open_areas:
			# Fallback: any ground cell
			_spawn_cells.append(cell)
	
	# Combine spawn cells, prioritizing wall edges
	if prefer_wall_edges:
		_spawn_cells.append_array(wall_edge_cells)
	if prefer_open_areas:
		_spawn_cells.append_array(open_area_cells)
	
	# Remove duplicates
	var unique_cells := {}
	for cell in _spawn_cells:
		unique_cells[cell] = true
	_spawn_cells = unique_cells.keys()
	
	print("SpawnManager: Found %d valid spawn cells (%d wall edges, %d open areas)" % [_spawn_cells.size(), wall_edge_cells.size(), open_area_cells.size()])


func _is_adjacent_to_wall(cell: Vector2i) -> bool:
	# Check if this cell is adjacent to at least one wall cell
	var neighbors := [
		Vector2i(cell.x + 1, cell.y),  # Right
		Vector2i(cell.x - 1, cell.y),  # Left
		Vector2i(cell.x, cell.y + 1),  # Down
		Vector2i(cell.x, cell.y - 1),   # Up
	]
	
	for neighbor in neighbors:
		if _wall_cells.has(neighbor):
			return true
	
	return false


func _is_open_area(cell: Vector2i, ground_cells: Dictionary) -> bool:
	# Check if there's enough open space around this cell
	var open_count := 0
	var total_checked := 0
	
	for x in range(-open_area_radius, open_area_radius + 1):
		for y in range(-open_area_radius, open_area_radius + 1):
			var check_cell := Vector2i(cell.x + x, cell.y + y)
			total_checked += 1
			
			# Count as open if it's a ground cell (exists in ground and not a wall)
			if ground_cells.has(check_cell):
				open_count += 1
	
	# Consider it an open area if at least 70% of the area is clear
	var open_ratio := float(open_count) / float(total_checked)
	return open_ratio >= 0.7


func get_spawn_position() -> Vector2:
	if _spawn_cells.is_empty():
		push_warning("SpawnManager has no spawn cells")
		return Vector2.ZERO

	# Try to find a position away from player
	var trawler := get_tree().get_first_node_in_group("trawler") as Node2D
	var attempts := 0
	var max_attempts := 20
	
	while attempts < max_attempts:
		var idx := randi() % _spawn_cells.size()
		var cell: Vector2i = _spawn_cells[idx]
		
		# Tile coords -> global coordinates
		var local_pos := ground_tilemap.map_to_local(cell)
		var global_pos := ground_tilemap.to_global(local_pos)
		
		# Check distance from player if specified
		if trawler != null and min_distance_from_player > 0.0:
			var distance := global_pos.distance_to(trawler.global_position)
			if distance >= min_distance_from_player:
				return global_pos
		else:
			# No distance requirement, return immediately
			return global_pos
		
		attempts += 1
	
	# Fallback: return random position even if too close
	var idx := randi() % _spawn_cells.size()
	var cell: Vector2i = _spawn_cells[idx]
	var local_pos := ground_tilemap.map_to_local(cell)
	return ground_tilemap.to_global(local_pos)


func spawn(scene: PackedScene, parent: Node = null) -> Node2D:
	var pos := get_spawn_position()
	var inst := scene.instantiate() as Node2D

	if parent == null:
		parent = get_tree().current_scene

	parent.add_child(inst)
	inst.global_position = pos
	return inst


# Call this when walls are destroyed/updated to refresh spawn cells
func refresh_spawn_cells() -> void:
	_rebuild_spawn_cells()
