extends CharacterBody2D

## Player ship - movement and shooting only
## Docking is handled by PlayerController

signal lasers_toggled(is_on: bool)

@export var ship_stats: ShipStats = preload("res://resources/config/ships/player_ship_base.tres")

var ship_id: int = -1
var speed: float = 150.0
var is_active: bool = false
var dock_radius: float = 80.0

var owner_controller: Node = null
var current_dock: Node2D = null

@onready var left_laser: Laser = $LeftLaser
@onready var right_laser: Laser = $RightLaser
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var frame_sprite: Sprite2D = $Sprite2D
@onready var weapon_component: Node = $WeaponComponent

var lasers_enabled: bool = false

func _ready() -> void:
	add_to_group("player_ship")
	
	# Lasers always on for mining
	lasers_enabled = true
	_update_lasers()
	
	# Apply stats from ship_stats resource
	if ship_stats:
		speed = ship_stats.base_speed
		
		var health_component := get_node_or_null("HealthComponent")
		if health_component:
			health_component.max_health = ship_stats.max_health
			health_component.current_health = ship_stats.max_health
		
		var speed_component := get_node_or_null("SpeedComponent")
		if speed_component:
			speed_component.base_speed = ship_stats.base_speed
		
		if left_laser:
			left_laser.color = ship_stats.laser_color
			left_laser.width = ship_stats.laser_width
			left_laser.direction = Vector2.UP  # Point forward
			left_laser.max_range = 30.0  # Short mining range
		if right_laser:
			right_laser.color = ship_stats.laser_color
			right_laser.width = ship_stats.laser_width
			right_laser.direction = Vector2.UP  # Point forward
			right_laser.max_range = 30.0  # Short mining range

func _physics_process(delta: float) -> void:
	if not is_active or not owner_controller:
		return
	
	# Handle movement (WASD)
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		
		# Rotate to face movement direction
		var target_rotation := input_dir.angle() + PI / 2.0
		rotation = lerp_angle(rotation, target_rotation, 10.0 * delta)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if not is_active or not owner_controller:
		return
	
	# Try to dock (E key)
	if event.is_action_pressed("interact"):
		try_dock()
	
	# Fire weapons (Shoot or Space)
	if event.is_action_pressed("shoot") or event.is_action_pressed("ui_accept"):
		_fire_weapons()

func try_dock() -> void:
	"""Request docking if near current dock"""
	if not current_dock or not owner_controller:
		return
	
	var dist := global_position.distance_to(current_dock.global_position)
	if dist > dock_radius:
		return
	
	if owner_controller.has_method("request_dock"):
		owner_controller.request_dock(self, current_dock)

func _fire_weapons() -> void:
	"""Fire bullets in the direction we're facing"""
	if weapon_component and weapon_component.has_method("fire_in_direction"):
		var fire_dir := Vector2.UP.rotated(rotation)
		weapon_component.fire_in_direction(fire_dir, self)

func _update_lasers() -> void:
	"""Update laser visibility"""
	if left_laser:
		left_laser.set_is_casting(lasers_enabled)
	if right_laser:
		right_laser.set_is_casting(lasers_enabled)

func activate() -> void:
	is_active = true
	visible = true
	# Ensure lasers are on when ship activates
	lasers_enabled = true
	_update_lasers()

func deactivate() -> void:
	is_active = false
	# Turn off lasers when ship deactivates
	lasers_enabled = false
	_update_lasers()

func set_ship_id(id: int) -> void:
	ship_id = id

func set_owner_controller(controller: Node) -> void:
	owner_controller = controller

func set_current_dock(dock: Node2D) -> void:
	current_dock = dock
