extends Control

## Multiplayer lobby - shows connected players and allows host to start game

@onready var player_list: VBoxContainer = $CenterContainer/LobbyPanel/PlayerList
@onready var start_button: Button = $CenterContainer/LobbyPanel/StartButton
@onready var leave_button: Button = $CenterContainer/LobbyPanel/LeaveButton
@onready var status_label: Label = $CenterContainer/LobbyPanel/StatusLabel

var player_labels: Dictionary = {}  # peer_id -> Label

func _ready() -> void:
	# Only host can start the game
	start_button.visible = NetworkManager.is_host
	
	# Connect signals
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Show current players
	_refresh_player_list()
	
	status_label.text = "Waiting for players..." if NetworkManager.is_host else "Waiting for host to start..."

func _refresh_player_list() -> void:
	"""Refresh the list of connected players"""
	# Clear existing labels
	for label in player_labels.values():
		if is_instance_valid(label):
			label.queue_free()
	player_labels.clear()
	
	# Add labels for each player
	for peer_id in NetworkManager.players.keys():
		_add_player_label(peer_id)

func _add_player_label(peer_id: int) -> void:
	"""Add a label for a connected player"""
	var label := Label.new()
	var is_host := peer_id == 1
	var is_you := peer_id == multiplayer.get_unique_id()
	
	var text := "Player %d" % peer_id
	if is_host:
		text += " (Host)"
	if is_you:
		text += " (You)"
	
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	player_list.add_child(label)
	player_labels[peer_id] = label

func _on_player_connected(peer_id: int) -> void:
	"""Called when a new player connects"""
	_add_player_label(peer_id)
	status_label.text = "Player %d joined!" % peer_id

func _on_player_disconnected(peer_id: int) -> void:
	"""Called when a player disconnects"""
	if player_labels.has(peer_id):
		var label = player_labels[peer_id]
		if is_instance_valid(label):
			label.queue_free()
		player_labels.erase(peer_id)
	
	status_label.text = "Player %d left" % peer_id

func _on_start_button_pressed() -> void:
	"""Host starts the game"""
	if not NetworkManager.is_host:
		return
	
	# Notify all clients to start
	_start_game.rpc()

@rpc("authority", "call_local")
func _start_game() -> void:
	"""Start the game for all players"""
	await SceneTransition.fade_in()
	
	# Reset game state
	GameState.reset_run()
	
	# Start the run
	RunManager.start_run()
	
	await SceneTransition.fade_out()

func _on_leave_button_pressed() -> void:
	"""Leave the lobby"""
	# Disconnect from multiplayer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	
	# Return to main menu
	await SceneTransition.fade_in()
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
	await SceneTransition.fade_out()
