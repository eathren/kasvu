extends Node2D

## Level_Mine - Contains the mine level with walls, trawler, and enemies
## Uses MineGenerator to build the level data, then applies it to TileMaps

@onready var ground: TileMapLayer = $WorldRoot/Floor
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
	
	# Both host and clients generate the world using the same seed
	# This ensures deterministic generation - no need to sync tiles!
	var gen := MineGenerator.new(RunManager.get_generator_config())
	
	# Generate level data using shared seed
	var level_data := gen.build_level(RunManager.current_seed, trawler_cell)
	
	# Apply tiles to TileMap
	_apply_tiles(level_data)
	
	print("Level_Mine: Level generated with %d wall cells (seed: %d)" % [level_data["wall_cells"].size(), RunManager.current_seed])
	
	# Setup SpawnManager
	if SpawnManager != null:
		SpawnManager.setup(wall)
	
	# Load enemy scene if not set
	if enemy_scene == null:
		enemy_scene = load("res://entities/enemies/imp/imp.tscn") as PackedScene
	
	# Clear any existing player controllers (in case of reload)
	for controller in _player_controllers.values():
		if is_instance_valid(controller):
			controller.queue_free()
	_player_controllers.clear()
	
	# Spawn player controllers for all connected players
	_spawn_player_controllers()
	
	# Connect to network signals for late joiners
	var net_manager = get_node_or_null("/root/NetworkManager")
	if net_manager:
		if not net_manager.player_connected.is_connected(_on_player_connected):
			net_manager.player_connected.connect(_on_player_connected)
		if not net_manager.player_disconnected.is_connected(_on_player_disconnected):
			net_manager.player_disconnected.connect(_on_player_disconnected)

func _process(delta: float) -> void:
	# Spawn enemies at the specified rate
	_spawn_timer += delta
	var spawn_interval := 1.0 / spawns_per_second
	
	while _spawn_timer >= spawn_interval:
		_spawn_timer -= spawn_interval
		_spawn_enemy()

func _spawn_player_controllers() -> void:
	"""Spawn a PlayerController for each connected player"""
	var net_manager = get_node_or_null("/root/NetworkManager")
	if not net_manager or not net_manager.is_multiplayer():
		# Singleplayer - spawn one controller for local player
		_spawn_player_controller(1)
		return
	
	# Multiplayer - spawn controller for each peer
	for peer_id in net_manager.players.keys():
		_spawn_player_controller(peer_id)

func _spawn_player_controller(peer_id: int) -> void:
	"""Spawn a PlayerController for a specific peer"""
	if _player_controllers.has(peer_id):
		print("Level_Mine: PlayerController already exists for peer ", peer_id)
		return
	
	# Clean up any existing crew avatars in trawler (prevents duplicates on reload)
	var interior := trawler.get_node_or_null("InteriorRoot")
	if interior:
		for child in interior.get_children():
			if child.is_in_group("player"):
				child.queue_free()
	
	# Spawn crew avatar
	var crew := crew_scene.instantiate() as CharacterBody2D
	if not crew:
		push_error("Level_Mine: Failed to instantiate crew scene")
		return
	
	# Add crew to trawler interior
	if not interior:
		push_error("Level_Mine: Trawler InteriorRoot not found")
		return
	
	interior.add_child(crew)
	crew.position = Vector2(0, 30)  # Starting position in trawler
	
	# Create camera
	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position = Vector2.ZERO
	camera.enabled = true
	crew.add_child(camera)
	
	# Make it current after adding to tree
	await get_tree().process_frame
	camera.make_current()
	
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

## Sync a tile deletion to all clients (called when mining/destroying tiles)
func sync_tile_deletion(cell: Vector2i) -> void:
	"""Called by host when a tile is destroyed - syncs to clients"""
	if multiplayer.is_server():
		_delete_tile_on_clients.rpc(cell)

@rpc("authority", "call_remote")
func _delete_tile_on_clients(cell: Vector2i) -> void:
	"""Clients receive and delete a tile"""
	if wall:
		wall.erase_cell(cell)

## Apply generated tile data to the TileMap
func _apply_tiles(level_data: Dictionary) -> void:
	if wall == null:
		push_error("Level_Mine: Wall TileMapLayer not found")
		return
	if ground == null:
		push_error("Level_Mine: Ground TileMapLayer not found")
		return
	
	# Get tile coordinates from wall script
	var tile_source_id: int = wall.tile_source_id
	var ground_coord: Vector2i = wall.ground_coord
	var wall_center_coord: Vector2i = wall.wall_center_coord
	var wall_edge_coords: Array = wall.wall_edge_coords
	var wall_face_coords: Array = wall.wall_face_coords
	
	print("Level_Mine: Using tile_source_id=", tile_source_id)
	print("Level_Mine: ground_coord=", ground_coord)
	print("Level_Mine: wall_center_coord=", wall_center_coord)
	print("Level_Mine: wall_edge_coords=", wall_edge_coords)
	print("Level_Mine: wall_face_coords=", wall_face_coords)
	
	# Get wall cells from level data
	var wall_cells: Array = level_data.get("wall_cells", [])
	
	# Build a set for O(1) neighbor lookups
	var wall_set := {}
	for cell in wall_cells:
		wall_set[cell] = true
	
	# Calculate map bounds from wall cells
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999
	for cell in wall_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	
	# Fill entire map area with floor tiles
	print("Level_Mine: Filling floor from (", min_x, ",", min_y, ") to (", max_x, ",", max_y, ")")
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			ground.set_cell(cell, tile_source_id, ground_coord)
	
	# Place wall tiles on Wall layer based on neighbors
	for cell in wall_cells:
		var has_neighbor_above = wall_set.has(cell + Vector2i(0, -1))
		var has_neighbor_below = wall_set.has(cell + Vector2i(0, 1))
		
		if not has_neighbor_below:
			# Bottom edge - use wall face (exposed from bottom)
			var variant = randi() % wall_face_coords.size()
			wall.set_cell(cell, tile_source_id, wall_face_coords[variant])
		elif not has_neighbor_above:
			# Top edge - use edge lip
			var variant = randi() % wall_edge_coords.size()
			wall.set_cell(cell, tile_source_id, wall_edge_coords[variant])
		else:
			# Interior tile - use center
			wall.set_cell(cell, tile_source_id, wall_center_coord)
	
	# Setup map boundaries
	var boundaries = $WorldRoot/MapBoundaries
	if boundaries and boundaries.has_method("setup_boundaries"):
		boundaries.setup_boundaries(min_x, max_x, min_y, max_y)
	
	print("Level_Mine: Applied %d tiles to TileMap" % wall_cells.size())
