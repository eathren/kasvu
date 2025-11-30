extends Area2D

## Drill component for the Borer
## Uses Area2D collision to detect and damage wall tiles

@export var damage_per_second: float = 1000.0  # Very high to instantly clear tiles

var is_active: bool = false
var trawler: Node = null
var is_digging: bool = false  # Track if actively hitting tiles

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ambient_rumble: AudioStreamPlayer2D = $DrillSound

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
	
	print("Drill: Initialized, is_active=", is_active, " trawler=", trawler)

func _on_movement_state_changed(new_state) -> void:
	# Auto-enable drill when moving
	var was_active = is_active
	is_active = (new_state != trawler.MovementState.STOP)
	
	if was_active != is_active:
		_update_animation()
		_update_audio()

func _on_drill_toggled(enabled: bool) -> void:
	is_active = enabled
	_update_animation()
	_update_audio()

func _update_animation() -> void:
	if not animated_sprite:
		return
	
	if is_active:
		animated_sprite.play("drilling")
	else:
		animated_sprite.stop()
		animated_sprite.frame = 0

func _update_audio() -> void:

	
	# Ambient rumble plays continuously when active
	if ambient_rumble:
		if is_active and not ambient_rumble.playing:
			ambient_rumble.play()
		elif not is_active and ambient_rumble.playing:
			ambient_rumble.stop()

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	if not trawler:
		return
	
	# Get mining speed multiplier from GameState
	var mining_speed = 1.0
	if GameState.has_method("get_mining_speed_multiplier"):
		mining_speed = GameState.get_mining_speed_multiplier()
	
	var damage = damage_per_second * mining_speed * delta
	
	# Use Area2D collision to find wall tiles
	_damage_overlapping_tiles(damage)

func _damage_overlapping_tiles(damage: float) -> void:
	# Find the Wall TileMapLayer in the scene
	var wall_layer = get_tree().get_first_node_in_group("wall") as TileMapLayer
	if not wall_layer:
		return
	
	# Get all overlapping bodies (should include the wall TileMapLayer)
	var overlapping = get_overlapping_bodies()
	
	# Check if we're overlapping with the wall layer
	if not wall_layer in overlapping:
		return
	
	# Get the drill's collision shape to determine area
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	# Get the area covered by the drill
	var drill_rect = Rect2(
		global_position - shape.size / 2,
		shape.size
	)
	
	# Convert to tile coordinates and damage all tiles in the drill area
	var tile_size = 16  # Assuming 16x16 tisles
	var min_tile = wall_layer.local_to_map(wall_layer.to_local(drill_rect.position))
	var max_tile = wall_layer.local_to_map(wall_layer.to_local(drill_rect.end))
	
	var tiles_damaged = 0
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			var tile_coord = Vector2i(x, y)
			var source_id = wall_layer.get_cell_source_id(tile_coord)
			
			if source_id != -1:
				if wall_layer.has_method("damage_cell"):
					wall_layer.damage_cell(tile_coord, damage)
					tiles_damaged += 1
	
	if tiles_damaged > 0:
		print("Drill: Damaged ", tiles_damaged, " tiles with ", damage, " damage each")
		
