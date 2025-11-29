extends Node
class_name PlayerController

## Per-player controller that manages crew/ship switching and camera

@export var player_id: int = 0
@export var crew_avatar: CharacterBody2D
@export var camera: Camera2D
@export var ship_scene: PackedScene = preload("res://entities/player/ships/player_ship/player_ship.tscn")

var current_ship: Node2D = null

func _ready() -> void:
	add_to_group("player_controller")
	# Start controlling crew
	control_crew()

func control_crew() -> void:
	"""Switch control to crew avatar"""
	current_ship = null
	
	if crew_avatar:
		crew_avatar.set_process(true)
		crew_avatar.set_physics_process(true)
		crew_avatar.set_process_input(true)
		crew_avatar.visible = true
		
		if crew_avatar.has_method("activate"):
			crew_avatar.activate()
	
	_update_camera()

func control_ship(dock: Node2D) -> void:
	"""Undock and control a ship from a dock"""
	if current_ship:
		print("PlayerController: Already controlling a ship")
		return
	
	if not dock:
		push_error("PlayerController: No dock provided")
		return
	
	# Get or spawn ship at dock
	var ship = dock.get_or_spawn_ship(ship_scene) if dock.has_method("get_or_spawn_ship") else null
	if not ship:
		push_error("PlayerController: Failed to get ship from dock")
		return
	
	current_ship = ship
	
	# Set ship references
	if ship.has_method("set_owner_controller"):
		ship.set_owner_controller(self)
	if ship.has_method("set_current_dock"):
		ship.set_current_dock(dock)
	if ship.has_method("set_ship_id"):
		ship.set_ship_id(player_id)
	
	# Activate ship
	ship.set_process(true)
	ship.set_physics_process(true)
	ship.set_process_input(true)
	ship.visible = true
	
	if ship.has_method("activate"):
		ship.activate()
	
	# Deactivate crew
	if crew_avatar:
		crew_avatar.set_process(false)
		crew_avatar.set_physics_process(false)
		crew_avatar.set_process_input(false)
		crew_avatar.visible = false
		
		if crew_avatar.has_method("deactivate"):
			crew_avatar.deactivate()
	
	# Offset ship slightly from dock so it doesn't clip
	ship.global_position = dock.global_position + Vector2(0, -20)
	
	_update_camera()
	
	print("PlayerController: Controlling ship from dock ", dock.name)

func request_dock(ship: Node2D, dock: Node2D) -> void:
	"""Ship requests to dock"""
	if ship != current_ship:
		print("PlayerController: Ship is not owned by this controller")
		return
	
	# Deactivate ship
	ship.set_process(false)
	ship.set_physics_process(false)
	ship.set_process_input(false)
	
	if ship.has_method("deactivate"):
		ship.deactivate()
	
	# Dock receives ship
	if dock and dock.has_method("receive_ship"):
		dock.receive_ship(ship)
	
	# Spawn crew near dock
	if crew_avatar and dock and dock.has_method("get_crew_spawn_position"):
		crew_avatar.global_position = dock.get_crew_spawn_position()
	
	# Switch back to crew control
	control_crew()
	
	print("PlayerController: Ship docked at ", dock.name)

func _update_camera() -> void:
	"""Update camera to follow current control target"""
	if not camera:
		return
	
	var target := current_ship if current_ship else crew_avatar
	if not target:
		return
	
	# Reparent camera to target
	if camera.get_parent() != target:
		if camera.get_parent():
			camera.get_parent().remove_child(camera)
		
		target.add_child(camera)
		camera.position = Vector2.ZERO
	
	# Make this camera current
	camera.enabled = true
	camera.make_current()

func is_controlling_ship() -> bool:
	return current_ship != null
