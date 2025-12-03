extends Node2D

## Playground scene for testing features
## Press ESC to return to main menu

@onready var camera: Camera2D = $Camera2D
@onready var player_spawner: Node2D = $PlayerSpawner
@onready var player: Node2D = $PlayerSpawner/PlayerShip

func _ready() -> void:
	print("Playground: Scene loaded. Press ESC to return to main menu.")
	
	# Setup player ship
	if player:
		# Get or create PlayerController
		var controller = player.get_node_or_null("PlayerController")
		if controller:
			controller.player_id = 1
			# Get ship's camera
			var ship_camera = player.get_node_or_null("Camera2D")
			if ship_camera:
				controller.camera = ship_camera
				ship_camera.enabled = true
				ship_camera.make_current()
				# Disable playground camera
				if camera:
					camera.enabled = false
			
			# Activate the ship through controller
			if player.has_method("set_owner_controller"):
				player.set_owner_controller(controller)
			if player.has_method("activate"):
				player.activate()
			
		else:
			# Fallback: activate ship directly
			if player.has_method("activate"):
				player.activate()
			if player.has_method("set_owner_controller"):
				player.set_owner_controller(player)
			player.is_active = true

func _process(delta: float) -> void:
	pass  # Ship camera handles itself

func _input(event: InputEvent) -> void:
	# Return to main menu on ESC
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()

func _return_to_menu() -> void:
	if SceneTransition:
		await SceneTransition.fade_in()
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
	if SceneTransition:
		await SceneTransition.fade_out()

## Spawn an entity at a position for testing
func spawn_entity(scene: PackedScene, pos: Vector2) -> Node:
	var entity := scene.instantiate()
	add_child(entity)
	if entity is Node2D:
		entity.position = pos
	return entity

## Clear all spawned entities (keeps player)
func clear_entities() -> void:
	for child in get_children():
		if child != camera and child != player_spawner and child.name != "Ground":
			child.queue_free()
