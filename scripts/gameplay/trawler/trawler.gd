extends CharacterBody2D

enum MovementState {
	STOP,
	GO,
	BURST
}

@export var base_speed: float = 10.0
@export var burst_multiplier: float = 2.0
@export var max_speed_for_line: float = 600.0
@export var max_line_length: float = 64.0
@export var line_lerp_speed: float = 10.0

@onready var direction_line: Line2D = $DirectionLine
@onready var front_laser: Laser = $FrontLaser

var current_state: MovementState = MovementState.GO
var current_line_length: float = 0.0
var current_speed: float = 0.0

func _ready() -> void:
	add_to_group("trawler")
	base_speed = GameState.get_trawler_speed()
	_update_speed_from_state()
	
	# Trawler laser is always on
	if front_laser:
		front_laser.set_is_casting(true)

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
	# Trawler laser is always on, no input needed

func set_movement_state(new_state: MovementState) -> void:
	if current_state != new_state:
		current_state = new_state
		_update_speed_from_state()

func _update_speed_from_state() -> void:
	match current_state:
		MovementState.STOP:
			current_speed = 0.0
		MovementState.GO:
			current_speed = base_speed
		MovementState.BURST:
			current_speed = base_speed * burst_multiplier
