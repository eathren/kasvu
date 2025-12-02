extends CharacterBody2D

@export var crew_stats: CrewStats = preload("res://resources/config/crew/default_crew.tres")

var speed: float = 200.0  # Set from crew_stats in _ready()
var is_active: bool = true

func _ready() -> void:
	add_to_group("player")
	
	# Apply stats from crew_stats resource
	if crew_stats:
		speed = crew_stats.move_speed
		
		# Apply to HealthComponent
		var health_component := get_node_or_null("HealthComponent") as HealthComponent
		if health_component:
			health_component.max_health = crew_stats.max_health
			health_component.current_health = crew_stats.max_health
		
		# Apply to SpeedComponent
		var speed_component := get_node_or_null("SpeedComponent") as SpeedComponent
		if speed_component:
			speed_component.base_speed = crew_stats.move_speed
		
		# Apply pickup range to PickupArea
		var pickup_area := get_node_or_null("PickupArea") as Area2D
		if pickup_area:
			var collision_shape := pickup_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision_shape and collision_shape.shape is CircleShape2D:
				var circle := collision_shape.shape as CircleShape2D
				circle.radius = crew_stats.pickup_range * GameState.get_pickup_range_multiplier()

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	# Only process input for local authority
	if not is_multiplayer_authority():
		return
	
	var input_dir := Vector2.ZERO

	# Use your own input actions, not ui_left/right/up/down
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)

func activate() -> void:
	is_active = true
	visible = true
	set_physics_process(true)
