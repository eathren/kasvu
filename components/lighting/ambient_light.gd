extends PointLight2D
class_name AmbientLight

## Small ambient glow around entities

@export var glow_radius: float = 1.5  # Multiplier for texture_scale
@export var glow_color: Color = Color(0.9, 0.9, 1, 1)  # Soft blue-white
@export var glow_intensity: float = 0.6

func _ready() -> void:
	energy = glow_intensity
	texture_scale = glow_radius
	color = glow_color
	shadow_enabled = false
	blend_mode = 0
	range_z_min = -100
	range_z_max = 100

