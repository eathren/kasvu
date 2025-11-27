extends Camera2D

## Camera follows its parent automatically (player or player_ship)

func _ready() -> void:
	# Camera is a child of the player, so it automatically follows
	# Disable built-in smoothing since we're a child node
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	
	# Make this the active camera
	make_current()
	
	# Center the camera on the player (no offset needed since we're a child)
	position = Vector2.ZERO
