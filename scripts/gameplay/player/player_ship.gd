extends CharacterBody2D

## Player ship with two small lasers and movement
## Lasers toggle on/off with interact button

signal lasers_toggled(is_on: bool)

@export var speed: float = 150.0

@onready var left_laser: Laser = $LeftLaser
@onready var right_laser: Laser = $RightLaser

var lasers_enabled: bool = false
var is_active: bool = false
var player_reference: CharacterBody2D = null  # Reference to the crew member inside trawler
var can_dock: bool = false  # Prevent immediate re-docking
var dock_cooldown: float = 2.0  # Seconds before you can dock again

func _ready() -> void:
	# Start with lasers off
	_update_lasers()
	add_to_group("player_ship")

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	# Handle rotation (face mouse or gamepad right stick)
	_handle_rotation(delta)
	
	# Handle movement (WASD - independent of rotation)
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _handle_rotation(delta: float) -> void:
	# Rotate to face mouse (or gamepad right stick)
	var aim_dir := Vector2.ZERO
	
	# Mouse aiming (primary)
	var mouse_pos := get_global_mouse_position()
	aim_dir = (mouse_pos - global_position).normalized()
	
	# Gamepad right stick override (if being used)
	var gamepad_aim := Vector2.ZERO
	gamepad_aim.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	gamepad_aim.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	if gamepad_aim.length() > 0.2:  # Deadzone
		aim_dir = gamepad_aim.normalized()
	
	# Rotate to face aim direction
	if aim_dir != Vector2.ZERO:
		var target_rotation := aim_dir.angle() + PI / 2.0  # +90 degrees because sprite faces up by default
		rotation = lerp_angle(rotation, target_rotation, 15.0 * delta)  # Smooth rotation

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("interact"):
		lasers_enabled = not lasers_enabled
		_update_lasers()
		lasers_toggled.emit(lasers_enabled)

func _update_lasers() -> void:
	if left_laser:
		left_laser.set_is_casting(lasers_enabled)
	if right_laser:
		right_laser.set_is_casting(lasers_enabled)

func take_control_from_player(player: CharacterBody2D) -> void:
	"""Called when player boards this ship from the trawler"""
	player_reference = player
	is_active = true
	can_dock = false  # Start with docking disabled
	
	print("Ship: Taking control from player")
	
	# Move camera from player to ship
	if player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		player.remove_child(camera)
		add_child(camera)
		camera.position = Vector2.ZERO
		camera.make_current()
		print("Ship: Camera transferred to ship")
	
	# Enable docking after cooldown
	await get_tree().create_timer(dock_cooldown).timeout
	can_dock = true
	print("Ship: Can now dock back at trawler")

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Check for docking back at trawler (only after cooldown)
	if can_dock:
		var trawler := get_tree().get_first_node_in_group("trawler")
		if trawler:
			var distance := global_position.distance_to(trawler.global_position)
			if distance < 100.0:
				# Show UI prompt for docking
				var ui := get_tree().root.get_node_or_null("Main/UI/InteractionPrompt")
				if ui and ui.has_method("show_interaction_prompt"):
					ui.show_interaction_prompt("Press E to dock")
				
				if Input.is_action_just_pressed("interact"):
					return_to_trawler()
			else:
				# Hide prompt when too far
				var ui := get_tree().root.get_node_or_null("Main/UI/InteractionPrompt")
				if ui and ui.has_method("hide_interaction_prompt"):
					ui.hide_interaction_prompt()

func return_to_trawler() -> void:
	"""Called when ship docks back at trawler"""
	if player_reference == null:
		print("Ship: No player reference, cannot return to trawler")
		return
	
	print("Ship: Returning to trawler")
	
	# Disable ship immediately to prevent double-docking
	is_active = false
	can_dock = false
	
	# Hide dock prompt
	var ui := get_tree().root.get_node_or_null("Main/UI/InteractionPrompt")
	if ui and ui.has_method("hide_interaction_prompt"):
		ui.hide_interaction_prompt()
	
	# Move camera back to player
	if has_node("Camera2D"):
		var camera = get_node("Camera2D")
		remove_child(camera)  # Remove from ship (self)
		player_reference.add_child(camera)
		camera.position = Vector2.ZERO
		camera.make_current()
		print("Ship: Camera transferred back to player")
	
	# Reactivate the crew member
	player_reference.activate()
	print("Ship: Player reactivated")
	
	# Remove this ship immediately
	print("Ship: Freeing ship node")
	queue_free()
