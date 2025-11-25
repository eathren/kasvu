extends CharacterBody2D

@export var speed: float = 30.0
@export var max_speed_for_line: float = 600.0
@export var max_line_length: float = 64.0
@export var line_lerp_speed: float = 10.0

@onready var direction_line: Line2D = $DirectionLine

var current_line_length: float = 0.0

func _ready() -> void:
	add_to_group("trawler")
	speed = GameState.get_trawler_speed()

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_direction_line(delta)

func _update_direction_line(delta: float) -> void:
	var v_len := velocity.length()

	if v_len < 1.0:
		current_line_length = lerp(current_line_length, 0.0, line_lerp_speed * delta)
		if current_line_length < 0.5:
			direction_line.visible = false
			return
	else:
		var speed_ratio = clamp(v_len / max_speed_for_line, 0.0, 1.0)
		var target_length = max_line_length * speed_ratio
		current_line_length = lerp(current_line_length, target_length, line_lerp_speed * delta)
		direction_line.visible = true

	if current_line_length <= 0.0:
		return

	var dir := velocity.normalized()
	var start := Vector2.ZERO
	var end := dir * current_line_length

	var pts := PackedVector2Array()
	pts.push_back(start)
	pts.push_back(end)
	direction_line.points = pts
