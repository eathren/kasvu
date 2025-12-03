extends Node2D

## Level_Mine - Contains the mine level with walls, trawler, and enemies
## Uses MineGenerator to build the level data, then applies it to TileMaps

const RoomConstants = preload("res://rooms/room_constants.gd")

@onready var ground: TileMapLayer = $WorldRoot/Floor
@onready var wall: TileMapLayer = $WorldRoot/Wall
@onready var trawler: CharacterBody2D = $Trawler
@onready var enemy_root: Node2D = $WorldRoot/EnemyRoot
@onready var room_root: Node2D = $WorldRoot/RoomRoot
@onready var pathfinding_manager: PathfindingManager = $PathfindingManager
@export var enemy_scene: PackedScene = preload("res://entities/enemies/imp/imp.tscn")
@export var crew_scene: PackedScene = preload("res://entities/player/crew/player.tscn")
@export var spawns_per_second: float = 1.0
@export var rooms_per_chunk: int = 3  # Number of rooms to spawn per chunk
@export var chunk_spacing: float = 800.0  # Distance between room chunks

var _spawn_timer: float = 0.0
var _player_controllers: Dictionary = {}  # peer_id -> PlayerController
var _spawned_chunks: Dictionary = {}  # Vector2i -> bool (tracks spawned room chunks)
var _active_rooms: Array[RoomTemplate] = []

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
	
	# Setup pathfinding manager with trawler position
	if pathfinding_manager:
		pathfinding_manager.setup(wall, trawler.global_position)
	
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
	
	# Spawn initial rooms near the trawler
	_spawn_initial_rooms()

func _process(delta: float) -> void:
	# Spawn enemies at the specified rate
	_spawn_timer += delta
	var spawn_interval := 1.0 / spawns_per_second
	
	while _spawn_timer >= spawn_interval:
		_spawn_timer -= spawn_interval
		_spawn_enemy()
	
	# Check for new room chunks to spawn based on trawler position
	if multiplayer.is_server():
		_check_and_spawn_rooms()

func _spawn_player_controllers() -> void:
	if not multiplayer.is_server():
		return
	
	var net_manager = get_node_or_null("/root/NetworkManager")
	if not net_manager:
		push_error("Level_Mine: NetworkManager not found")
		return
	
	for peer_id in net_manager.players.keys():
		_spawn_player_controller(peer_id)

func _spawn_player_controller(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	if _player_controllers.has(peer_id):
		print("Level_Mine: PlayerController already exists for peer ", peer_id)
		return
	
	var docks = get_tree().get_nodes_in_group("ship_dock")
	if docks.is_empty():
		push_error("Level_Mine: No ShipDocks found for player spawn")
		return
	
	var available_dock: Node2D = null
	for dock in docks:
		if dock.has_method("is_occupied") and not dock.is_occupied():
			available_dock = dock
			break
	
	if not available_dock:
		var dock_index = _player_controllers.size() % docks.size()
		available_dock = docks[dock_index]
	
	var ship_scene = preload("res://entities/player/ships/player_ship/player_ship.tscn")
	var ship = available_dock.spawn_ship(ship_scene)
	
	if not ship:
		push_error("Level_Mine: Failed to spawn ship for peer ", peer_id)
		return
	
	ship.name = "PlayerShip_%d" % peer_id
	ship.set_multiplayer_authority(peer_id)
	
	var controller = ship.get_node_or_null("PlayerController")
	if controller:
		controller.name = "PlayerController_%d" % peer_id
		controller.set_multiplayer_authority(peer_id)
		controller.player_id = peer_id
		_player_controllers[peer_id] = controller
		
		if ship.has_method("set_owner_controller"):
			ship.set_owner_controller(controller)
	
	if ship.has_method("set_ship_id"):
		ship.set_ship_id(peer_id)
	
	if ship.has_method("activate"):
		ship.activate()
	
	print("Level_Mine: Spawned ship for peer ", peer_id, " at dock ", available_dock.name)

func _on_player_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("Level_Mine: Player ", peer_id, " connected, spawning ship")
	_spawn_player_controller.call_deferred(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("Level_Mine: Player ", peer_id, " disconnected, cleaning up")
	if _player_controllers.has(peer_id):
		var controller = _player_controllers[peer_id]
		if is_instance_valid(controller):
			var ship = controller.get_parent()
			if ship:
				ship.queue_free()
			else:
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
		
		# Update pathfinding grids (solid=false means walkable)
		if pathfinding_manager:
			pathfinding_manager.update_tile(cell, false)

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

## Spawn initial rooms near the trawler
func _spawn_initial_rooms() -> void:
	if not multiplayer.is_server():
		return
	
	if not trawler:
		return
	
	# Spawn rooms in front and around the trawler
	var trawler_pos := trawler.global_position
	var forward_offset := Vector2.DOWN * chunk_spacing  # Down is forward in the mine
	
	# Spawn 3 chunks ahead
	for i in range(3):
		var chunk_pos := trawler_pos + forward_offset * (i + 1)
		_spawn_room_chunk(chunk_pos)

## Check trawler position and spawn rooms ahead
func _check_and_spawn_rooms() -> void:
	if not trawler:
		return
	
	var trawler_pos := trawler.global_position
	var chunk_id := _get_chunk_id(trawler_pos)
	
	# Spawn chunks ahead of the trawler (down direction)
	for offset_y in range(1, 4):  # 3 chunks ahead
		var check_chunk := chunk_id + Vector2i(0, offset_y)
		if not _spawned_chunks.has(check_chunk):
			var chunk_world_pos := _chunk_id_to_position(check_chunk)
			_spawn_room_chunk(chunk_world_pos)
			_spawned_chunks[check_chunk] = true

## Get chunk ID from world position
func _get_chunk_id(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / chunk_spacing),
		floori(world_pos.y / chunk_spacing)
	)

## Convert chunk ID to world position
func _chunk_id_to_position(chunk_id: Vector2i) -> Vector2:
	return Vector2(chunk_id) * chunk_spacing

## Spawn a cluster of rooms at the given position
func _spawn_room_chunk(chunk_center: Vector2) -> void:
	if not room_root:
		push_error("Level_Mine: RoomRoot node not found!")
		return
	
	# Generate a small dungeon layout for this chunk
	var layout := DungeonLayout.generate_layout(rooms_per_chunk, randi())
	
	if layout.is_empty():
		return
	
	print("Level_Mine: Spawning %d rooms at chunk %s" % [layout.size(), chunk_center])
	
	# Spawn each room
	for room_node in layout:
		_create_room_at_chunk(room_node, chunk_center)

## Create a single room at the chunk position
func _create_room_at_chunk(room_node: DungeonLayout.RoomNode, chunk_center: Vector2) -> void:
	# Get matching room template
	var scene: PackedScene = RoomLibrary.get_random(room_node.mask, room_node.room_type)
	
	if scene == null:
		push_warning("Level_Mine: No template for mask=%d type=%s" % [room_node.mask, room_node.room_type])
		return
	
	# Instantiate room
	var room_inst: RoomTemplate = scene.instantiate()
	room_root.add_child(room_inst)
	
	# Position relative to chunk center
	var room_offset := Vector2(room_node.grid_pos) * Vector2(RoomConstants.ROOM_SIZE_PX)
	room_inst.global_position = chunk_center + room_offset
	
	# Store reference
	_active_rooms.append(room_inst)
	
	# Populate room with enemies and loot
	_populate_room(room_inst)

## Populate a room with enemies and loot based on markers
func _populate_room(room: RoomTemplate) -> void:
	# Spawn enemies at each enemy marker
	for marker in room.get_enemy_markers():
		_spawn_enemy_at_position(marker.global_position)
	
	# Spawn loot at 40% of loot markers
	for marker in room.get_loot_markers():
		if randf() < 0.4:
			_spawn_loot_at_position(marker.global_position)

## Spawn an enemy at a specific position (for rooms)
func _spawn_enemy_at_position(pos: Vector2) -> void:
	if enemy_scene == null:
		return
	
	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	
	var parent := enemy_root if enemy_root != null else get_tree().current_scene
	parent.add_child(enemy)
	enemy.global_position = pos

## Spawn loot at a specific position (placeholder)
func _spawn_loot_at_position(pos: Vector2) -> void:
	# TODO: Replace with actual loot spawning
	print("Level_Mine: Loot spawn at ", pos)
	# Example:
	# var loot = preload("res://entities/items/health_pickup.tscn").instantiate()
	# get_tree().current_scene.add_child(loot)
	# loot.global_position = pos
