extends Node

## Manages multiplayer connections and player spawning
## Host has authority over game state, saves, and world generation

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal connection_succeeded()
signal server_created()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_host: bool = false
var players: Dictionary = {}  # peer_id -> player_data

func create_host(port: int = DEFAULT_PORT) -> void:
	"""Create a multiplayer host"""
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		push_error("Failed to create server: %s" % error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	# Register host as player 1
	_register_player(1)
	
	# Connect signals
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	server_created.emit()
	print("NetworkManager: Server created on port ", port)

func join_host(address: String, port: int = DEFAULT_PORT) -> void:
	"""Join an existing host"""
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	
	if error != OK:
		push_error("Failed to connect to server: %s" % error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	# Connect signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("NetworkManager: Attempting to connect to ", address, ":", port)

func start_singleplayer() -> void:
	"""Start in singleplayer mode (no network)"""
	is_host = true
	_register_player(1)
	print("NetworkManager: Singleplayer mode")

func _register_player(peer_id: int) -> void:
	"""Register a player"""
	players[peer_id] = {
		"peer_id": peer_id,
		"controller": null,
		"ready": false
	}
	print("NetworkManager: Player registered - Peer ID: ", peer_id)

func _on_player_connected(peer_id: int) -> void:
	"""Called on host when a client connects"""
	_register_player(peer_id)
	player_connected.emit(peer_id)
	print("NetworkManager: Player connected - Peer ID: ", peer_id)
	
	# Sync current game state to new player
	if is_host:
		_sync_game_state_to_player.rpc_id(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	"""Called on host when a client disconnects"""
	players.erase(peer_id)
	player_disconnected.emit(peer_id)
	print("NetworkManager: Player disconnected - Peer ID: ", peer_id)

func _on_connected_to_server() -> void:
	"""Called on client when successfully connected"""
	var my_id := multiplayer.get_unique_id()
	_register_player(my_id)
	connection_succeeded.emit()
	print("NetworkManager: Connected to server - My ID: ", my_id)

func _on_connection_failed() -> void:
	"""Called on client when connection fails"""
	connection_failed.emit()
	print("NetworkManager: Connection failed")

func _on_server_disconnected() -> void:
	"""Called on client when host disconnects"""
	print("NetworkManager: Server disconnected")
	# Return to main menu
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")

@rpc("authority", "call_local")
func _sync_game_state_to_player() -> void:
	"""Host syncs game state to a newly connected client"""
	# This will be called on clients to receive state from host
	pass

func get_player_count() -> int:
	return players.size()

func is_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
