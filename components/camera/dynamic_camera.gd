extends Camera2D
class_name DynamicCamera

## Dynamic Camera - Leans towards the mouse cursor for an organic look-ahead effect

@export var max_offset_dist: float = 100.0
@export var lean_factor: float = 0.2
@export var smooth_speed: float = 5.0

func _process(delta: float) -> void:
	var parent = get_parent()
	if not parent:
		return
		
	# Calculate vector from parent (player) to mouse
	var mouse_global := get_global_mouse_position()
	var parent_global = parent.global_position
	var to_mouse = mouse_global - parent_global
	
	# Calculate target offset
	var target_offset = to_mouse * lean_factor
	
	# Clamp offset magnitude
	if target_offset.length() > max_offset_dist:
		target_offset = target_offset.normalized() * max_offset_dist
	
	# Smoothly move camera to target offset
	position = position.lerp(target_offset, smooth_speed * delta)
