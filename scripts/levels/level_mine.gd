extends Node2D

## Level_Mine - Contains the mine level with walls, trawler, and enemies
## Uses MineGenerator to build the level data, then applies it to TileMaps

@onready var wall: TileMapLayer = $WorldRoot/Wall
@onready var trawler: CharacterBody2D = $Trawler
@onready var enemy_root: Node2D = $WorldRoot/EnemyRoot
@export var enemy_scene: PackedScene = preload("res://scenes/gameplay/enemies/imp.tscn")
@export var spawns_per_second: float = 5.0

var _spawn_timer: float = 0.0

func _ready() -> void:
	if RunManager == null:
		push_error("Level_Mine: RunManager not found")
		return
	
	# Get trawler position for generation
	var trawler_pos := trawler.global_position
	var trawler_local := wall.to_local(trawler_pos)
	var trawler_cell := wall.local_to_map(trawler_local)
	
	# Create generator with config from RunManager
	var gen := MineGenerator.new(RunManager.get_generator_config())
	
	# Generate level data
	var level_data := gen.build_level(RunManager.current_seed, trawler_cell)
	
	# Apply tiles to TileMap
	_apply_tiles(level_data)
	
	# Setup SpawnManager
	if SpawnManager != null:
		SpawnManager.setup(wall)
	
	# Load enemy scene if not set
	if enemy_scene == null:
		enemy_scene = load("res://scenes/gameplay/enemies/imp.tscn") as PackedScene
	
	print("Level_Mine: Level generated with %d wall cells" % level_data["wall_cells"].size())

func _process(delta: float) -> void:
	# Spawn enemies at the specified rate
	_spawn_timer += delta
	var spawn_interval := 1.0 / spawns_per_second
	
	while _spawn_timer >= spawn_interval:
		_spawn_timer -= spawn_interval
		_spawn_enemy()

func _spawn_enemy() -> void:
	if enemy_scene == null or SpawnManager == null:
		return
	
	# Use SpawnManager to get a position behind the trawler
	var spawn_pos := SpawnManager.get_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return
	
	# Spawn the enemy
	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	
	# Add to enemy root or current scene
	var parent := enemy_root if enemy_root != null else get_tree().current_scene
	parent.add_child(enemy)
	enemy.global_position = spawn_pos

## Apply generated tile data to the TileMap
func _apply_tiles(level_data: Dictionary) -> void:
	if wall == null:
		push_error("Level_Mine: Wall TileMapLayer not found")
		return
	
	# Get wall generation parameters from wall script
	var tile_source_id: int = 5  # Default
	var wall_atlas_coord: Vector2i = Vector2i(1, 1)  # Default
	
	if "tile_source_id" in wall:
		tile_source_id = wall.get("tile_source_id")
	if "wall_atlas_coord" in wall:
		wall_atlas_coord = wall.get("wall_atlas_coord")
	
	# Apply all wall cells - no yields, just do it all at once
	var wall_cells: Array = level_data.get("wall_cells", [])
	
	for cell in wall_cells:
		wall.set_cell(cell, tile_source_id, wall_atlas_coord)
	
	print("Level_Mine: Applied %d tiles to TileMap" % wall_cells.size())
