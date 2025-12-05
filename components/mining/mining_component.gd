extends Node2D
class_name MiningComponent

## Component for mining/digging walls with a laser beam

@export var mining_range: float = 100.0  # Max distance to mine
@export var mining_damage: float = 50.0  # Damage per second to walls
@export var laser_width: float = 2.0
@export var laser_color: Color = Color(1.0, 0.8, 0.2, 0.8)  # Orange laser

var is_mining: bool = false
var target_wall_cell: Vector2i = Vector2i.MAX
var mining_direction: Vector2 = Vector2.ZERO
var wall_tilemap: TileMapLayer = null

@onready var laser_line: Line2D = $LaserLine

func _ready() -> void:
	# Create laser line if it doesn't exist
	if not laser_line:
		laser_line = Line2D.new()
		laser_line.name = "LaserLine"
		laser_line.width = laser_width
		laser_line.default_color = laser_color
		laser_line.z_index = 10
		add_child(laser_line)
	
	laser_line.visible = false
	
	# Find wall tilemap
	var level = get_tree().get_first_node_in_group("level")
	if level:
		wall_tilemap = level.get_node_or_null("WorldRoot/Wall")

func _physics_process(delta: float) -> void:
	if not is_mining:
		laser_line.visible = false
		return
	
	if not wall_tilemap:
		return
	
	# Cast ray to find wall
	var owner_node = get_parent()
	if not owner_node:
		return
	
	var start_pos = owner_node.global_position
	var end_pos = start_pos + mining_direction * mining_range
	
	# Raycast to find collision
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.collision_mask = 8  # Wall layer
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result := space_state.intersect_ray(query)
	
	if result.is_empty():
		laser_line.visible = false
		return
	
	# Found a wall - draw laser to hit point
	var hit_point: Vector2 = result.position
	var local_start := to_local(start_pos)
	var local_end := to_local(hit_point)
	
	laser_line.clear_points()
	laser_line.add_point(local_start)
	laser_line.add_point(local_end)
	laser_line.visible = true
	
	# Get cell at hit point
	var wall_local := wall_tilemap.to_local(hit_point)
	var cell := wall_tilemap.local_to_map(wall_local)
	
	# Check if cell has a wall tile
	var tile_data := wall_tilemap.get_cell_tile_data(cell)
	if not tile_data:
		return
	
	# Apply damage to wall
	if wall_tilemap.has_method("damage_cell"):
		wall_tilemap.damage_cell(cell, mining_damage * delta)

func start_mining(direction: Vector2) -> void:
	"""Start mining in the given direction"""
	if direction.length() < 0.1:
		return
	
	is_mining = true
	mining_direction = direction.normalized()

func stop_mining() -> void:
	"""Stop mining"""
	is_mining = false
	laser_line.visible = false
