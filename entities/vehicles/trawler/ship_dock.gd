extends Node2D
class_name ShipDock

## Ship dock that spawns and holds ships
## Multiple players can use any dock

enum DockPosition {
	LEFT,
	RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT
}

@export var dock_position: DockPosition = DockPosition.LEFT
@export var home_ship_id: int = 0
@export var dock_radius: float = 64.0

var docked_ship: Node2D = null

func _ready() -> void:
	add_to_group("ship_dock")
	
	# Ensure marker exists
	if not has_node("DockMarker"):
		var marker = Marker2D.new()
		marker.name = "DockMarker"
		add_child(marker)

func spawn_ship(ship_scene: PackedScene) -> Node2D:
	if not ship_scene:
		push_error("ShipDock: No ship scene provided")
		return null
	
	if docked_ship and is_instance_valid(docked_ship):
		push_error("ShipDock: Dock already occupied")
		return null
	
	var ship := ship_scene.instantiate()
	get_tree().current_scene.add_child(ship)
	docked_ship = ship
	ship.global_position = global_position
	
	return ship

func receive_ship(ship: Node2D) -> void:
	"""Dock receives a ship and converts it to turret mode"""
	if not ship:
		return
		
	docked_ship = ship
	
	# Reparent ship to this dock so it moves with the Borer
	if ship.get_parent():
		ship.get_parent().remove_child(ship)
	add_child(ship)
	
	# Reset position to local zero (center of dock)
	ship.position = Vector2.ZERO
	ship.rotation = 0
	
	# Keep visible for turret mode
	ship.visible = true
	
	# Notify ship it is docked
	if ship.has_method("set_docked"):
		ship.set_docked(true)
		ship.set_current_dock(self)

func undock_ship(ship: Node2D) -> void:
	"""Release ship from dock"""
	if ship != docked_ship:
		return
	
	# Reparent to world (Grandparent of dock usually, or find WorldRoot)
	# Assuming Dock -> Borer -> WorldRoot
	var world = get_tree().current_scene
	
	remove_child(ship)
	world.add_child(ship)
	
	# Set position to world position of dock
	ship.global_position = global_position
	
	# Notify ship it is undocked
	if ship.has_method("set_docked"):
		ship.set_docked(false)
		# Keep current_dock reference so it can re-dock easily if close
	
	# Ensure ship is active and visible
	ship.visible = true
	ship.rotation = global_rotation # Match dock rotation initially
	
	docked_ship = null

func get_crew_spawn_position() -> Vector2:
	"""Where crew spawns when exiting ship"""
	# Spawn crew inside trawler (parent should be trawler)
	var trawler := get_parent()
	if trawler:
		return trawler.global_position
	return global_position + Vector2(0, 32)

func is_occupied() -> bool:
	return docked_ship != null and is_instance_valid(docked_ship)
