@onready var laser: RayCast2D = get_parent().get_node("LaserRaycast")

func _process(delta: float) -> void:
	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if laser:
		laser.is_casting = firing
