extends Node
class_name PathfindingComponent

## Component for entities to use pathfinding
## Attach to enemies or NPCs that need to navigate

signal path_found(path: Array[Vector2])
signal path_failed()
signal destination_reached()

@export var repath_interval: float = 1.0  # How often to recalculate path (seconds)
@export var waypoint_distance: float = 16.0  # How close to get before moving to next waypoint
@export var use_cached_paths: bool = true  # Use path caching for performance

var current_path: Array[Vector2] = []
var current_waypoint_index: int = 0
var destination: Vector2 = Vector2.ZERO
var has_destination: bool = false
var repath_timer: float = 0.0
var pathfinding_grid: PathfindingGrid = null
var owner_entity: Node2D = null

func _ready() -> void:
	owner_entity = get_parent() as Node2D
	if not owner_entity:
		push_error("PathfindingComponent: Must be child of a Node2D entity")
	
	# Find pathfinding grid
	await get_tree().process_frame
	pathfinding_grid = get_tree().get_first_node_in_group("pathfinding_grid")
	
	if not pathfinding_grid:
		push_warning("PathfindingComponent: No PathfindingGrid found in scene")

func _process(delta: float) -> void:
	if not has_destination or not owner_entity:
		return
	
	# Update repath timer
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = repath_interval
		_calculate_path()
	
	# Check if we've reached current waypoint
	if not current_path.is_empty():
		_check_waypoint_reached()

func set_destination(target: Vector2) -> void:
	"""Set a new destination to path to"""
	destination = target
	has_destination = true
	repath_timer = 0.0  # Force immediate path calculation
	_calculate_path()

func set_destination_to_node(target: Node2D) -> void:
	"""Set destination to follow a node"""
	if target:
		set_destination(target.global_position)

func clear_destination() -> void:
	"""Stop pathfinding"""
	has_destination = false
	current_path.clear()
	current_waypoint_index = 0

func _calculate_path() -> void:
	"""Calculate path from current position to destination"""
	if not pathfinding_grid or not owner_entity or not has_destination:
		return
	
	var start_pos := owner_entity.global_position
	var new_path := pathfinding_grid.find_path(start_pos, destination, use_cached_paths)
	
	if new_path.is_empty():
		path_failed.emit()
		return
	
	current_path = new_path
	current_waypoint_index = 0
	path_found.emit(current_path)

func _check_waypoint_reached() -> void:
	"""Check if we've reached the current waypoint"""
	if current_waypoint_index >= current_path.size():
		destination_reached.emit()
		has_destination = false
		return
	
	var current_waypoint := current_path[current_waypoint_index]
	var distance := owner_entity.global_position.distance_to(current_waypoint)
	
	if distance < waypoint_distance:
		current_waypoint_index += 1
		
		if current_waypoint_index >= current_path.size():
			destination_reached.emit()
			has_destination = false

func get_current_waypoint() -> Vector2:
	"""Get the current waypoint to move towards"""
	if current_path.is_empty() or current_waypoint_index >= current_path.size():
		return owner_entity.global_position if owner_entity else Vector2.ZERO
	
	return current_path[current_waypoint_index]

func get_move_direction() -> Vector2:
	"""Get the normalized direction to the current waypoint"""
	if not owner_entity:
		return Vector2.ZERO
	
	var waypoint := get_current_waypoint()
	var direction := owner_entity.global_position.direction_to(waypoint)
	return direction

func has_path() -> bool:
	"""Check if we have a valid path"""
	return not current_path.is_empty() and current_waypoint_index < current_path.size()

func get_remaining_distance() -> float:
	"""Get approximate remaining distance to destination"""
	if not has_path() or not owner_entity:
		return 0.0
	
	var distance := 0.0
	var current_pos := owner_entity.global_position
	
	# Distance to first waypoint
	if current_waypoint_index < current_path.size():
		distance += current_pos.distance_to(current_path[current_waypoint_index])
	
	# Distance between remaining waypoints
	for i in range(current_waypoint_index, current_path.size() - 1):
		distance += current_path[i].distance_to(current_path[i + 1])
	
	return distance

func is_destination_reachable() -> bool:
	"""Check if the current destination is reachable"""
	if not pathfinding_grid or not owner_entity:
		return false
	
	return pathfinding_grid.is_position_walkable(destination)

func draw_debug_path(canvas: CanvasItem) -> void:
	"""Draw the current path for debugging"""
	if current_path.size() < 2:
		return
	
	# Draw path lines
	for i in range(current_path.size() - 1):
		canvas.draw_line(current_path[i], current_path[i + 1], Color.YELLOW, 2.0)
	
	# Draw waypoints
	for i in range(current_path.size()):
		var color := Color.GREEN if i == current_waypoint_index else Color.WHITE
		canvas.draw_circle(current_path[i], 4.0, color)
	
	# Draw destination
	canvas.draw_circle(destination, 8.0, Color.RED)
