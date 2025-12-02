extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal connection_succeeded()
signal server_created()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_host: bool = false
var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func create_host(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		push_error("Failed to create server: %d" % error)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer
	is_host = true

	var host_id := multiplayer.get_unique_id()
	_register_player(host_id)

	server_created.emit()
	print("NetworkManager: Server created on port ", port, " host id ", host_id)


func join_host(address: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		push_error("Failed to connect to server: %d" % error)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer
	is_host = false

	print("NetworkManager: Attempting to connect to ", address, ":", port)


func start_singleplayer() -> void:
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	is_host = true

	var id := multiplayer.get_unique_id()
	_register_player(id)

	print("NetworkManager: Singleplayer mode, id ", id)


func _register_player(peer_id: int) -> void:
	players[peer_id] = {
		"peer_id": peer_id,
		"controller": null,
		"ready": false
	}
	print("NetworkManager: Player registered - Peer ID: ", peer_id)


func _on_player_connected(peer_id: int) -> void:
	_register_player(peer_id)
	player_connected.emit(peer_id)
	print("NetworkManager: Player connected - Peer ID: ", peer_id)

	if is_host:
		_sync_game_state_to_player.rpc_id(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	player_disconnected.emit(peer_id)
	print("NetworkManager: Player disconnected - Peer ID: ", peer_id)


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	_register_player(my_id)
	connection_succeeded.emit()
	print("NetworkManager: Connected to server - My ID: ", my_id)


func _on_connection_failed() -> void:
	connection_failed.emit()
	print("NetworkManager: Connection failed")


func _on_server_disconnected() -> void:
	print("NetworkManager: Server disconnected")
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")


@rpc("authority")
func _sync_game_state_to_player() -> void:
	pass


func get_player_count() -> int:
	return players.size()


func is_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
