extends CharacterBody2D

@export var speed: float = 200.0

var is_active: bool = true

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	var input_dir := Vector2.ZERO

	# Use your own input actions, not ui_left/right/up/down
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)

func activate() -> void:
	is_active = true
	visible = true
	set_physics_process(true)
