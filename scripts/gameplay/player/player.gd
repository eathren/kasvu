extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO

	# Use your own input actions, not ui_left/right/up/down
	input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_dir.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
