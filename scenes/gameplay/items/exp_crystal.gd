extends Area2D
class_name ExpCrystal

## Experience crystal that can be picked up by player

@export var xp_value: int = 10
@export var pickup_range: float = 32.0
@export var magnet_speed: float = 200.0

var _target: Node2D = null
var _is_being_collected: bool = false

func _ready() -> void:
	collision_layer = 256  # Pickup layer (bit 8)
	collision_mask = 4  # Player layer (bit 3)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _is_being_collected and is_instance_valid(_target):
		# Move towards target
		var direction := global_position.direction_to(_target.global_position)
		global_position += direction * magnet_speed * delta
		
		# Check if close enough to collect
		if global_position.distance_to(_target.global_position) < 10.0:
			_collect()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("player_ship"):
		_target = body
		_is_being_collected = true

func _on_area_entered(area: Area2D) -> void:
	# Check if it's a player ship's pickup area
	var parent = area.get_parent()
	if parent and (parent.is_in_group("player") or parent.is_in_group("player_ship")):
		_target = parent
		_is_being_collected = true

func _collect() -> void:
	if GameState.has_method("add_experience"):
		GameState.add_experience(xp_value)
	queue_free()
