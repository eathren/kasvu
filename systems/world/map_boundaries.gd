extends Node2D

## Map boundaries - creates collision boxes around the map edges

@onready var top_boundary: StaticBody2D = $TopBoundary
@onready var bottom_boundary: StaticBody2D = $BottomBoundary
@onready var left_boundary: StaticBody2D = $LeftBoundary
@onready var right_boundary: StaticBody2D = $RightBoundary

func setup_boundaries(min_x: int, max_x: int, min_y: int, max_y: int, tile_size: int = 16) -> void:
	"""Create collision boundaries around the map edges"""
	var thickness := 100.0  # Thickness of boundary walls
	
	# Convert tile coords to world coords
	var world_min_x := min_x * tile_size
	var world_max_x := (max_x + 1) * tile_size
	var world_min_y := min_y * tile_size
	var world_max_y := (max_y + 1) * tile_size
	
	var width := world_max_x - world_min_x
	var height := world_max_y - world_min_y
	
	# Top boundary
	if top_boundary:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width + thickness * 2, thickness)
		top_boundary.position = Vector2((world_min_x + world_max_x) / 2, world_min_y - thickness / 2)
		var collision := top_boundary.get_node("CollisionShape2D")
		if collision:
			collision.shape = shape
	
	# Bottom boundary
	if bottom_boundary:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width + thickness * 2, thickness)
		bottom_boundary.position = Vector2((world_min_x + world_max_x) / 2, world_max_y + thickness / 2)
		var collision := bottom_boundary.get_node("CollisionShape2D")
		if collision:
			collision.shape = shape
	
	# Left boundary
	if left_boundary:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(thickness, height + thickness * 2)
		left_boundary.position = Vector2(world_min_x - thickness / 2, (world_min_y + world_max_y) / 2)
		var collision := left_boundary.get_node("CollisionShape2D")
		if collision:
			collision.shape = shape
	
	# Right boundary
	if right_boundary:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(thickness, height + thickness * 2)
		right_boundary.position = Vector2(world_max_x + thickness / 2, (world_min_y + world_max_y) / 2)
		var collision := right_boundary.get_node("CollisionShape2D")
		if collision:
			collision.shape = shape
	
	print("MapBoundaries: Set up boundaries from (", min_x, ",", min_y, ") to (", max_x, ",", max_y, ")")
