extends Node2D

@export var ship_scene: PackedScene      # assign PlayerShip scene in the inspector

@onready var area: Area2D = $Area2D
@onready var dock_marker: Marker2D = $DockMarker

var player_in_zone: CharacterBody2D = null

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	set_process_input(true)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = body as CharacterBody2D
		# Optionally show "Press E to board" UI here

func _on_body_exited(body: Node) -> void:
	if body == player_in_zone:
		player_in_zone = null
		# Hide interact prompt here

func _input(event: InputEvent) -> void:
	if player_in_zone == null:
		return
	if event.is_action_pressed("interact"):
		_board_ship()

func _board_ship() -> void:
	if player_in_zone == null:
		return

	# 1. Deactivate player on foot
	player_in_zone.deactivate()

	# 2. Spawn ship as sibling in the world
	var world := get_tree().current_scene
	var ship := ship_scene.instantiate()
	world.add_child(ship)

	ship.global_position = dock_marker.global_position
	ship.rotation = 0.0    # or match trawler, or whatever you want

	# 3. Give control to the ship (depends on your ship script)
	ship.call_deferred("take_control_from_player", player_in_zone)
