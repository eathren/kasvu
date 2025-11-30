extends CharacterBody2D

enum MovementState {
	STOP,
	GO,
	BURST
}

signal movement_state_changed(new_state: MovementState)
signal drill_toggled(is_on: bool)

@export var ship_stats: ShipStats = preload("res://resources/config/ships/trawler_base.tres")
@export var burst_multiplier: float = 2.0
@export var max_speed_for_line: float = 600.0
@export var max_line_length: float = 64.0
@export var line_lerp_speed: float = 10.0

var base_speed: float = 10.0  # Set from ship_stats in _ready()

@onready var enemy_detector: Area2D = $EnemyDetector

var current_state: MovementState = MovementState.GO
var current_line_length: float = 0.0
var current_speed: float = 0.0

func _ready() -> void:
	add_to_group("trawler")
	
	# Apply stats from ship_stats resource
	if ship_stats:
		base_speed = ship_stats.base_speed
		
		# Apply to HealthComponent
		var health_component := get_node_or_null("HealthComponent") as HealthComponent
		if health_component:
			health_component.max_health = ship_stats.max_health
			health_component.current_health = ship_stats.max_health
		
		# Apply to SpeedComponent
		var speed_component := get_node_or_null("SpeedComponent") as SpeedComponent
		if speed_component:
			speed_component.base_speed = ship_stats.base_speed
		
		# Apply pickup range to PickupArea
		var pickup_area := get_node_or_null("PickupArea") as Area2D
		if pickup_area:
			var collision_shape := pickup_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision_shape and collision_shape.shape is CircleShape2D:
				var circle := collision_shape.shape as CircleShape2D
				circle.radius = ship_stats.pickup_range * GameState.get_pickup_range_multiplier()
	
	# Apply GameState speed multiplier
	base_speed *= GameState.get_ship_speed_multiplier()
	_update_speed_from_state()
	
	
	
	# Connect enemy damage detection
	if enemy_detector:
		enemy_detector.body_entered.connect(_on_enemy_entered)

func _on_enemy_entered(body: Node) -> void:
	"""Handle damage when enemy touches trawler"""
	if body.is_in_group("enemy"):
		print("Trawler: Enemy collision detected - ", body.name)
		# TODO: Apply damage to trawler health system

func _physics_process(delta: float) -> void:
	# Move forward only based on current state
	match current_state:
		MovementState.STOP:
			velocity = Vector2.ZERO
		MovementState.GO:
			velocity = Vector2.UP.rotated(rotation) * current_speed
		MovementState.BURST:
			velocity = Vector2.UP.rotated(rotation) * current_speed * 4

	move_and_slide()

func set_movement_state(new_state: MovementState) -> void:
	if current_state != new_state:
		current_state = new_state
		_update_speed_from_state()
		movement_state_changed.emit(new_state)

func _update_speed_from_state() -> void:
	match current_state:
		MovementState.STOP:
			current_speed = 0.0
		MovementState.GO:
			current_speed = base_speed
		MovementState.BURST:
			current_speed = base_speed * burst_multiplier
