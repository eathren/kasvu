extends PointLight2D
class_name Flashlight

## Reusable flashlight component with configurable properties

enum FlashlightType {
	SMALL,      # Player/small ship
	MEDIUM,     # Regular ship
	LARGE,      # Trawler/large vehicle
	SPOTLIGHT,  # Focused beam
}

@export var flashlight_type: FlashlightType = FlashlightType.MEDIUM
@export var cast_shadows: bool = true
@export var warm_color: bool = true  # Warm white vs cool white

func _ready() -> void:
	_configure_flashlight()

func _configure_flashlight() -> void:
	# Set shadow properties
	shadow_enabled = cast_shadows
	if cast_shadows:
		shadow_filter = 1  # PCF5 smooth shadows
		shadow_item_cull_mask = 1  # See wall occlusions
	
	# Configure based on type
	match flashlight_type:
		FlashlightType.SMALL:
			energy = 1.2
			texture_scale = 2.0
			color = Color(1, 0.95, 0.85, 1) if warm_color else Color(0.9, 0.95, 1, 1)
		
		FlashlightType.MEDIUM:
			energy = 1.5
			texture_scale = 2.8
			color = Color(1, 0.95, 0.85, 1) if warm_color else Color(0.9, 0.95, 1, 1)
		
		FlashlightType.LARGE:
			energy = 2.5
			texture_scale = 5.0
			color = Color(1, 0.9, 0.7, 1) if warm_color else Color(0.85, 0.9, 1, 1)
		
		FlashlightType.SPOTLIGHT:
			energy = 2.0
			texture_scale = 3.5
			color = Color(1, 1, 0.95, 1) if warm_color else Color(0.95, 0.95, 1, 1)
	
	# Set z-range
	range_z_min = -100
	range_z_max = 100

func set_flashlight_enabled(enabled: bool) -> void:
	"""Toggle flashlight on/off"""
	visible = enabled

func set_intensity(intensity: float) -> void:
	"""Adjust brightness (0.0 to 2.0)"""
	energy = intensity

func set_beam_width(width: float) -> void:
	"""Adjust beam width"""
	texture_scale = width

