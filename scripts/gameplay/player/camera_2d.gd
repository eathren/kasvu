extends Camera2D

@export var target: Node2D
@export var follow_lerp_speed: float = 8.0
@export var enable_smoothing: bool = false
@export var snap_to_pixels: bool = true

# Optional zoom controls. Change or remove if you already have your own.
@export var enable_zoom_input: bool = true
@export var min_zoom: float = 0.5
@export var max_zoom: float = 4.0
@export var zoom_step: float = 0.1

func _ready() -> void:
	# Always disable built-in smoothing - we handle it manually for better control
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false

	if target == null:
		var t := get_tree().get_first_node_in_group("trawler")
		if t is Node2D:
			target = t

func _process(delta: float) -> void:
	if target == null:
		return
	
	# Use _process for camera updates - this runs at render framerate for smooth visuals
	# Physics runs at fixed timestep, but camera should update smoothly at display rate
	
	# Since camera is a child of target, we want to keep it at a relative position
	# But if we want it to follow smoothly, we need to work in global space
	var target_global_pos: Vector2 = target.global_position
	var current_global_pos: Vector2 = global_position
	var new_global_pos: Vector2

	if enable_smoothing:
		# Use exponential smoothing for frame-rate independent smooth following
		# This creates a smooth interpolation that works consistently regardless of framerate
		var weight: float = 1.0 - exp(-follow_lerp_speed * delta)
		new_global_pos = current_global_pos.lerp(target_global_pos, weight)
	else:
		new_global_pos = target_global_pos

	if snap_to_pixels:
		new_global_pos = new_global_pos.round()

	global_position = new_global_pos

func _unhandled_input(event: InputEvent) -> void:
	if not enable_zoom_input:
		return

	# Replace this whole block with your own zoom logic if you already had one.
	if event is InputEventMouseButton and event.pressed:
		var factor: float = 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			factor = 1.0 - zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			factor = 1.0 + zoom_step
		else:
			return

		var new_zoom: Vector2 = zoom * factor
		var z: float = clamp(new_zoom.x, min_zoom, max_zoom)
		zoom = Vector2(z, z)
