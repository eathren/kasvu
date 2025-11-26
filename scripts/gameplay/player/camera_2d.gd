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
	# Camera is a child of the player, so it automatically follows
	# Disable built-in smoothing since we're a child node
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	
	# Make this the active camera
	make_current()
	
	# Center the camera on the player (no offset needed since we're a child)
	position = Vector2.ZERO

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
