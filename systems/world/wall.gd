extends TileMapLayer


@export var wall_height_cells: int = 200
@export var nose_gap_tiles: int = 6
@export var tile_source_id: int = 6  # WFC tileset source

# Tile atlas coordinates (based on new expanded tileset)
# Row 0: Ceiling tiles (decorative)
@export var ceiling_coords: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]

# Row 1: Wall centers (solid interior)
@export var wall_center_coord: Vector2i = Vector2i(1, 1)  # Interior wall
@export var wall_center_coords: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]

# Row 2: Wall edges (top lip)
@export_group("Wall Edge Variants")
@export var wall_edge_coords: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]  # Top edge

# Row 3: Wall faces (visible front)
@export var wall_face_coords: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]  # Vertical face

# Row 4: Reinforced walls
@export var reinforced_coords: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]

# Row 5: Ground tiles
@export var ground_coord: Vector2i = Vector2i(1, 5)  # Ground/floor tile
@export var ground_coords: Array[Vector2i] = [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]

# Row 6: Resources and hazards
@export var ore_coord: Vector2i = Vector2i(0, 6)
@export var ore_coords: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6)]
@export var lava_coord: Vector2i = Vector2i(3, 6)
@export var pit_coord: Vector2i = Vector2i(4, 6)
@export var hazard_stripe_coord: Vector2i = Vector2i(5, 6)

# Row 7: Interactive objects
@export var door_coord: Vector2i = Vector2i(0, 7)
@export var door_coords: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
@export var pillar_coord: Vector2i = Vector2i(2, 7)
@export var treasure_coord: Vector2i = Vector2i(3, 7)
@export var shrine_coord: Vector2i = Vector2i(4, 7)
@export var crate_coord: Vector2i = Vector2i(5, 7)
@export var barrel_coord: Vector2i = Vector2i(6, 7)

@export var fill_radius_world: float = 1000.0
@export var clear_radius_tiles: int = 5

var left_x: int
var right_x: int
var top_y: int

# Track damage per cell
var cell_damage: Dictionary = {}

func _ready() -> void:
	add_to_group("wall")
	
	# Level generation is now handled by LevelManager
	# This script only handles damage and cell management

func damage_cell(cell: Vector2i, damage: float) -> void:
	# Only damage tiles from the wall source
	var src := get_cell_source_id(cell)
	if src == -1:
		return  # Empty cell
	if src != tile_source_id:
		return  # Not from wall tileset
	
	# Track damage for this cell
	var cell_key := "%d,%d" % [cell.x, cell.y]
	if not cell_damage.has(cell_key):
		cell_damage[cell_key] = 0.0
	
	cell_damage[cell_key] += damage
	
	# Remove cell if it takes enough damage (100 HP default)
	var max_health := 100.0
	if cell_damage[cell_key] >= max_health:
		erase_cell(cell)
		cell_damage.erase(cell_key)
		
		# Update neighboring tiles to show proper edges
		_update_neighbor_tiles(cell)

func _update_neighbor_tiles(destroyed_cell: Vector2i) -> void:
	"""Update tiles around a destroyed cell to show proper edges"""
	# Check the 4 cardinal neighbors
	var neighbors = [
		destroyed_cell + Vector2i(0, -1),  # Above
		destroyed_cell + Vector2i(0, 1),   # Below
		destroyed_cell + Vector2i(-1, 0),  # Left
		destroyed_cell + Vector2i(1, 0)    # Right
	]
	
	for neighbor in neighbors:
		var source_id = get_cell_source_id(neighbor)
		if source_id == -1 or source_id != tile_source_id:
			continue  # No tile here or not a wall tile
		
		# Check if this tile needs updating
		var has_above = get_cell_source_id(neighbor + Vector2i(0, -1)) == tile_source_id
		var has_below = get_cell_source_id(neighbor + Vector2i(0, 1)) == tile_source_id
		
		if not has_below:
			# Exposed from bottom - use wall face
			var variant = randi() % wall_face_coords.size()
			set_cell(neighbor, tile_source_id, wall_face_coords[variant])
		elif not has_above:
			# Top edge - use edge lip
			var variant = randi() % wall_edge_coords.size()
			set_cell(neighbor, tile_source_id, wall_edge_coords[variant])
		else:
			# Interior - use center
			set_cell(neighbor, tile_source_id, wall_center_coord)

# _generate_initial() removed - level generation is now handled by LevelManager
