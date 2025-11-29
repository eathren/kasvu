extends Control

## Main menu with singleplayer, multiplayer, and save/load options

@onready var main_panel: VBoxContainer = $CenterContainer/MainPanel
@onready var host_panel: VBoxContainer = $CenterContainer/HostPanel
@onready var join_panel: VBoxContainer = $CenterContainer/JoinPanel
@onready var load_panel: VBoxContainer = $CenterContainer/LoadPanel

@onready var address_input: LineEdit = $CenterContainer/JoinPanel/AddressInput
@onready var port_input: LineEdit = $CenterContainer/JoinPanel/PortInput

func _ready() -> void:
	_show_panel(main_panel)
	
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.server_created.connect(_on_server_created)

func _show_panel(panel: Control) -> void:
	"""Show only one panel at a time"""
	main_panel.visible = (panel == main_panel)
	host_panel.visible = (panel == host_panel)
	join_panel.visible = (panel == join_panel)
	load_panel.visible = (panel == load_panel)

# Main menu buttons
func _on_start_button_pressed() -> void:
	"""Start singleplayer game"""
	NetworkManager.start_singleplayer()
	_start_game()

func _on_host_button_pressed() -> void:
	"""Show host options"""
	_show_panel(host_panel)

func _on_join_button_pressed() -> void:
	"""Show join options"""
	_show_panel(join_panel)

func _on_load_button_pressed() -> void:
	"""Show load game options"""
	_show_panel(load_panel)
	_populate_save_slots()

func _on_quit_button_pressed() -> void:
	"""Quit the game"""
	get_tree().quit()

# Host panel buttons
func _on_create_host_button_pressed() -> void:
	"""Create a multiplayer host"""
	NetworkManager.create_host()

func _on_host_back_button_pressed() -> void:
	_show_panel(main_panel)

# Join panel buttons
func _on_connect_button_pressed() -> void:
	"""Connect to a host"""
	var address := address_input.text if address_input.text else "127.0.0.1"
	var port := int(port_input.text) if port_input.text else 7777
	NetworkManager.join_host(address, port)

func _on_join_back_button_pressed() -> void:
	_show_panel(main_panel)

# Load panel
func _populate_save_slots() -> void:
	"""Populate save slots from disk"""
	var slots := [
		$CenterContainer/LoadPanel/SaveSlots/Slot1,
		$CenterContainer/LoadPanel/SaveSlots/Slot2,
		$CenterContainer/LoadPanel/SaveSlots/Slot3
	]
	
	for i in range(3):
		var slot_num := i + 1
		var info := GameState.get_save_slot_info(slot_num)
		
		if info.get("exists", false):
			var playtime_mins := int(info.get("playtime", 0) / 60.0)
			slots[i].text = "Slot %d - Level %d, %d Kills, %d mins" % [
				slot_num,
				info.get("level", 1),
				info.get("kills", 0),
				playtime_mins
			]
			slots[i].disabled = false
		else:
			slots[i].text = "Slot %d - Empty" % slot_num
			slots[i].disabled = true

func _on_save_slot_pressed(slot: int) -> void:
	"""Load from specific save slot"""
	if GameState.load_game(slot):
		await SceneTransition.fade_in()
		RunManager.start_run()  # Will use loaded state
		await SceneTransition.fade_out()
	else:
		print("MainMenu: Failed to load save slot ", slot)

func _on_load_back_button_pressed() -> void:
	_show_panel(main_panel)

# Network callbacks
func _on_server_created() -> void:
	"""Host created successfully, go to lobby"""
	_go_to_lobby()

func _on_connection_succeeded() -> void:
	"""Client connected successfully, go to lobby"""
	_go_to_lobby()

func _on_connection_failed() -> void:
	"""Failed to connect"""
	print("MainMenu: Connection failed")
	_show_panel(main_panel)

func _go_to_lobby() -> void:
	"""Transition to multiplayer lobby"""
	await SceneTransition.fade_in()
	get_tree().change_scene_to_file("res://ui/menus/lobby.tscn")
	await SceneTransition.fade_out()

func _start_game() -> void:
	"""Transition to game"""
	await SceneTransition.fade_in()
	
	# Reset game state
	GameState.reset_run()
	
	# Start the run
	RunManager.start_run()
	
	await SceneTransition.fade_out()

