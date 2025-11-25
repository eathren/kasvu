extends Node2D

@export var base_scroll_speed: float = GameState.get_trawler_speed()

var depth: float = 0.0
var dig_multiplier: float = 1.0

@onready var wall: TileMapLayer = $Wall

func _ready() -> void:
	# Wait for wall to be initialized
	await get_tree().process_frame
	
	# Setup SpawnManager with ground and wall tilemaps
	# Note: The wall TileMapLayer contains both walls and ground tiles
	# We'll use it for both since they're in the same TileMapLayer
	if wall != null:
		SpawnManager.setup(wall, wall)
	else:
		push_error("WorldRoot: Wall TileMapLayer not found")
