extends Node2D

## Level_Mine - Contains the mine level with walls, trawler, and enemies
## Uses MineGenerator to build the level data, then applies it to TileMaps

@onready var wall: TileMapLayer = $WorldRoot/Wall
@onready var trawler: CharacterBody2D = $Trawler
@onready var enemy_root: Node2D = $WorldRoot/EnemyRoot
@export var enemy_scene: PackedScene = preload("res://entities/enemies/imp/imp.tscn")
@export var crew_scene: PackedScene = preload("res://entities/player/crew/player.tscn")
@export var spawns_per_second: float = 1.0

var _spawn_timer: float = 0.0
var _player_controllers: Dictionary = {}  # peer_id -> PlayerController

func _ready() -> void:
	if RunManager == null:
		push_error("Level_Mine: RunManager not found")
		return
	
	# Get trawler position for generation
	var trawler_pos := trawler.global_position
	var trawler_local := wall.to_local(trawler_pos)
	var trawler_cell := wall.local_to_map(trawler_local)
	
	# Only host generates the world
	if multiplayer.is_server():
		# Create generator with config from RunManager
		var gen := MineGenerator.new(RunManager.get_generator_config())
		
		# Generate level data
		var level_data := gen.build_level(RunManager.current_seed, trawler_cell)
		
		# Apply tiles to TileMap
		_apply_tiles(level_data)
		
		print("Level_Mine: Level generated with %d wall cells" % level_data["wall_cells"].size())
	else:
		# Clients wait for world sync from host
		print("Level_Mine: Client waiting for world sync from host")
	
	# Setup SpawnManager
	if SpawnManager != null:
		SpawnManager.setup(wall)
	
	# Load enemy scene if not set
	if enemy_scene == null:
		enemy_scene = load("res://entities/enemies/imp/imp.tscn") as PackedScene
	
	# Spawn player controllers for all connected players
	_spawn_player_controllers()
	
	# Connect to network signals for late joiners
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _process(delta: float) -> void:
	# Spawn enemies at the specified rate
	_spawn_timer += delta
	var spawn_interval := 1.0 / spawns_per_second
	
	while _spawn_timer >= spawn_interval:
		_spawn_timer -= spawn_interval
		_spawn_enemy()

func _spawn_player_controllers() -> void:
	"""Spawn a PlayerController for each connected player"""
	if not NetworkManager:
		# Singleplayer - spawn one controller for local player
		_spawn_player_controller(1)
		return
	
	# Multiplayer - spawn controller for each peer
	for peer_id in NetworkManager.players.keys():
		_spawn_player_controller(peer_id)

func _spawn_player_controller(peer_id: int) -> void:
	"""Spawn a PlayerController for a specific peer"""
	if _player_controllers.has(peer_id):
		print("Level_Mine: PlayerController already exists for peer ", peer_id)
		return
	
	# Spawn crew avatar
	var crew := crew_scene.instantiate() as CharacterBody2D
	if not crew:
		push_error("Level_Mine: Failed to instantiate crew scene")
		return
	
	# Add crew to trawler interior
	trawler.get_node("InteriorRoot").add_child(crew)
	crew.position = Vector2(0, 30)  # Starting position in trawler
	
	# Create camera
	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	crew.add_child(camera)
	
	# Create PlayerController
	var controller_script := load("res://entities/player/player_controller.gd")
	var controller := Node.new()
	controller.set_script(controller_script)
	controller.name = "PlayerController_%d" % peer_id
	
	add_child(controller)
	
	# Set multiplayer authority
	controller.set_multiplayer_authority(peer_id)
	crew.set_multiplayer_authority(peer_id)
	
	# Configure controller
	controller.set("crew_avatar", crew)
	controller.set("camera", camera)
	controller.set("player_id", peer_id)
	
	# Store reference
	_player_controllers[peer_id] = controller
	
	# Call ready manually
	if controller.has_method("control_crew"):
		controller.call("control_crew")
	
	print("Level_Mine: Spawned PlayerController for peer ", peer_id)

func _on_player_connected(peer_id: int) -> void:
	"""Called when a new player joins mid-game"""
	print("Level_Mine: Player ", peer_id, " connected, spawning controller")
	_spawn_player_controller.call_deferred(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	"""Called when a player disconnects"""
	print("Level_Mine: Player ", peer_id, " disconnected, cleaning up")
	if _player_controllers.has(peer_id):
		var controller = _player_controllers[peer_id]
		if is_instance_valid(controller):
			controller.queue_free()
		_player_controllers.erase(peer_id)

func _spawn_enemy() -> void:
	# Only host/server spawns enemies
	if not multiplayer.is_server():
		return
	
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
	
	# Sync tiles to clients in chunks (to avoid huge RPC)
	if multiplayer.is_server() and multiplayer.get_peers().size() > 0:
		_sync_tiles_to_clients(wall_cells, tile_source_id, wall_atlas_coord)

func _sync_tiles_to_clients(wall_cells: Array, source_id: int, atlas_coord: Vector2i) -> void:
	"""Send tiles to clients in chunks to avoid overwhelming the network"""
	var chunk_size := 1000
	var cell_count := wall_cells.size()
	var total_chunks := ceili(float(cell_count) / float(chunk_size))
	
	for i in range(total_chunks):
		var start := i * chunk_size
		var end := mini(start + chunk_size, cell_count)
		var chunk := wall_cells.slice(start, end)
		_apply_tile_chunk.rpc(chunk, source_id, atlas_coord)
	
	print("Level_Mine: Synced %d tiles to clients in %d chunks" % [cell_count, total_chunks])

@rpc("authority", "call_remote")
func _apply_tile_chunk(chunk: Array, source_id: int, atlas_coord: Vector2i) -> void:
	"""Clients receive and apply a chunk of tiles"""
	if not wall:
		return
	
	for cell in chunk:
		wall.set_cell(cell, source_id, atlas_coord)
