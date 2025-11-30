extends Node2D

## Drill component for the Borer
## Damages wall tiles in front when active

@export var damage_per_second: float = 50.0
@export var drill_width: float = 80.0  # Width of drill area
@export var drill_reach: float = 20.0  # How far ahead to check

var is_active: bool = false
var trawler: Node = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Get parent Trawler/Borer
	trawler = get_parent()
	if not trawler:
		push_error("Drill: No parent Trawler found")
		return
	
	# Connect to Trawler signals
	if trawler.has_signal("movement_state_changed"):
		trawler.movement_state_changed.connect(_on_movement_state_changed)
	if trawler.has_signal("drill_toggled"):
		trawler.drill_toggled.connect(_on_drill_toggled)
	
	# Initialize from GameState
	is_active = GameState.is_drilling if GameState.has_method("is_drilling") else true
	_update_animation()

func _on_movement_state_changed(new_state) -> void:
	# Auto-enable drill when moving
	var was_active = is_active
	is_active = (new_state != trawler.MovementState.STOP)
	
	if was_active != is_active:
		_update_animation()

func _on_drill_toggled(enabled: bool) -> void:
	is_active = enabled
	_update_animation()

func _update_animation() -> void:
	if not animated_sprite:
		return
	
	if is_active:
		animated_sprite.play("drilling")
	else:
		animated_sprite.stop()
		animated_sprite.frame = 0

func _physics_process(delta: float) -> void:
	if not is_active or not trawler:
		return
	
	# Get mining speed multiplier from GameState
	var mining_speed = 1.0
	if GameState.has_method("get_mining_speed_multiplier"):
		mining_speed = GameState.get_mining_speed_multiplier()
	
	var damage = damage_per_second * mining_speed * delta
	
	# Damage tiles in front of the Borer
	_damage_tiles_in_front(damage)

func _damage_tiles_in_front(damage: float) -> void:
	# Find the Wall TileMapLayer in the scene
	var wall_layer = get_tree().get_first_node_in_group("wall") as TileMapLayer
	if not wall_layer:
		return
	
	# Calculate drill area in front of Borer
	# Borer faces UP (negative Y in Godot)
	var borer_pos = trawler.global_position
	var borer_forward = Vector2.UP.rotated(trawler.global_rotation)
	
	# Check tiles in a rectangular area ahead
	var check_distance = drill_reach
	var check_width = drill_width
	
	# Convert to tile coordinates
	var tile_size = 16  # Assuming 16x16 tiles
	var center_ahead = borer_pos + borer_forward * check_distance
	
	# Check tiles in a grid
	var tiles_to_check = []
	for x_offset in range(-int(check_width / tile_size / 2), int(check_width / tile_size / 2) + 1):
		for y_offset in range(-2, 2):  # Check a few tiles ahead
			var check_pos = center_ahead + Vector2(x_offset * tile_size, y_offset * tile_size)
			var tile_coord = wall_layer.local_to_map(wall_layer.to_local(check_pos))
			
			if not tile_coord in tiles_to_check:
				tiles_to_check.append(tile_coord)
	
	# Damage each tile
	for tile_coord in tiles_to_check:
		if wall_layer.has_method("damage_cell"):
			wall_layer.damage_cell(tile_coord, damage)
