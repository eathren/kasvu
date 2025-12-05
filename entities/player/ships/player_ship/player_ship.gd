extends CharacterBody2D

## Top-down player character with mouse aim (Enter the Gungeon style)
## Sprite flips based on look direction, weapons render behind/in front based on aim

@export var ship_stats: ShipStats = preload("res://resources/config/ships/player_ship_base.tres")

var ship_id: int = -1
var speed: float = 150.0
var is_active: bool = false
var is_docked: bool = false
var dock_radius: float = 80.0

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_velocity: Vector2 = Vector2.ZERO

const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.2
const DASH_COOLDOWN: float = 1.0

# Collision layers for i-frames
var _original_collision_mask: int = 0

# Look direction
var look_direction: Vector2 = Vector2.UP
var last_move_direction: Vector2 = Vector2.UP

var owner_controller: Node = null
var current_dock: Node2D = null

@onready var left_laser: Laser = $LeftLaser
@onready var right_laser: Laser = $RightLaser
@onready var player_sprite: Sprite2D = $Sprite2D
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var weapon_hand: Node2D = $WeaponHand
@onready var flashlight: PointLight2D = $Flashlight

var lasers_enabled: bool = false
var starting_weapon := preload("res://resources/config/weapons/basic_gun.tres") as WeaponData
var current_weapon: Node2D = null
var is_attacking: bool = false


func _ready() -> void:
	add_to_group("player_ship")
	
	# Lasers always on for mining
	lasers_enabled = true
	_update_lasers()
	
	# Setup weapon manager
	if weapon_manager:
		weapon_manager.owner_ship = self
		# Add starting weapon
		if starting_weapon:
			weapon_manager.add_weapon(starting_weapon)
	
	# Equip minigun
	var minigun_scene = preload("res://entities/weapons/minigun/minigun.tscn")
	if minigun_scene and weapon_hand:
		current_weapon = minigun_scene.instantiate()
		weapon_hand.add_child(current_weapon)
	
	# Apply stats from ship_stats resource
	if ship_stats:
		speed = ship_stats.base_speed
		
		var health_component := get_node_or_null("HealthComponent")
		if health_component:
			health_component.max_health = ship_stats.max_health
			health_component.current_health = ship_stats.max_health
			# Connect death signal
			health_component.died.connect(_on_died)
		
		var speed_component := get_node_or_null("SpeedComponent")
		if speed_component:
			speed_component.base_speed = ship_stats.base_speed
		
		if left_laser:
			left_laser.color = ship_stats.laser_color
			left_laser.width = ship_stats.laser_width
		if right_laser:
			right_laser.color = ship_stats.laser_color
			right_laser.width = ship_stats.laser_width

func _physics_process(delta: float) -> void:
	if not is_active or not owner_controller:
		return
	
	# Only process input for local authority
	if not is_multiplayer_authority():
		return
	
	# Handle Dash Cooldown
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	# Update look direction from mouse or right stick
	var right_stick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var right_stick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_input := Vector2(right_stick_x, right_stick_y)
	
	if stick_input.length() > 0.3:  # Deadzone
		look_direction = stick_input.normalized()
	else:
		var mouse_pos := get_global_mouse_position()
		look_direction = (mouse_pos - global_position).normalized()
	
	# Update sprite flip and weapon positioning
	_update_sprite_and_weapons()
	
	# Handle continuous firing for minigun
	if is_attacking and current_weapon:
		if current_weapon.has_method("fire"):
			current_weapon.fire(look_direction, 0)
	
	# Handle Dash State
	if is_dashing:
		dash_timer -= delta
		velocity = dash_velocity
		move_and_slide()
		
		if dash_timer <= 0.0:
			_end_dash()
		return

	if is_docked:
		velocity = Vector2.ZERO
		return
	
	# Handle movement (WASD) - no rotation
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		last_move_direction = input_dir
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _update_sprite_and_weapons() -> void:
	# Flip sprite based on look direction (left/right)
	if look_direction.x < 0:
		player_sprite.flip_h = true
		# Move weapon to left side
		if weapon_hand:
			weapon_hand.position.x = -8
	elif look_direction.x > 0:
		player_sprite.flip_h = false
		# Move weapon to right side
		if weapon_hand:
			weapon_hand.position.x = 8
	
	# Position lasers based on aim direction
	if left_laser and right_laser:
		# Update laser direction to match look direction
		left_laser.direction = look_direction
		right_laser.direction = look_direction
		
		# Calculate perpendicular offset for left/right lasers
		var perpendicular = Vector2(-look_direction.y, look_direction.x)
		left_laser.position = perpendicular * -6.0
		right_laser.position = perpendicular * 6.0
	
	# Rotate flashlight to point in look_direction
	if flashlight:
		flashlight.rotation = look_direction.angle()
	
	# Update weapon aim and position
	if current_weapon and current_weapon.has_method("update_aim"):
		current_weapon.update_aim(look_direction)
	
	# Weapon and manager render behind player when aiming up/away
	var target_z = -1 if look_direction.y < -0.3 else 1
	
	if weapon_hand:
		weapon_hand.z_index = target_z
	
	if weapon_manager:
		for child in weapon_manager.get_children():
			if child is Node2D:
				child.z_index = target_z

func _input(event: InputEvent) -> void:
	if not is_active or not owner_controller:
		return
	
	# Only process input for local authority
	if not is_multiplayer_authority():
		return
	
	# Attack (Left Click or Joystick trigger) - start/stop continuous fire
	if event.is_action_pressed("attack"):
		is_attacking = true
	elif event.is_action_released("attack"):
		is_attacking = false
		# Stop firing on minigun
		if current_weapon and current_weapon.has_method("stop_firing"):
			current_weapon.stop_firing()
	
	# Try to dock/undock (E key)
	if event.is_action_pressed("interact"):
		if is_docked:
			request_undock()
		else:
			try_dock()
			
	# Dash (Right Click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_dash()

func try_dock() -> void:
	"""Request docking if near current dock"""
	if not current_dock or not owner_controller:
		return
	
	var dist := global_position.distance_to(current_dock.global_position)
	if dist > dock_radius:
		return
	
	if owner_controller.has_method("request_dock"):
		owner_controller.request_dock(self, current_dock)

# Weapon firing is now automatic via WeaponManager

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

func set_docked(docked: bool) -> void:
	is_docked = docked
	if is_docked:
		velocity = Vector2.ZERO
		# Ensure lasers stay on
		lasers_enabled = true
		_update_lasers()

func request_undock() -> void:
	if not is_docked or not current_dock:
		return
	
	if current_dock.has_method("undock_ship"):
		current_dock.undock_ship(self)

func _try_dash() -> void:
	if is_dashing or dash_cooldown_timer > 0.0 or is_docked:
		return
	
	# Determine dash direction
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_dir == Vector2.ZERO:
		# Dash towards mouse if no movement input
		var mouse_pos := get_global_mouse_position()
		input_dir = (mouse_pos - global_position).normalized()
	else:
		input_dir = input_dir.normalized()
	
	_start_dash(input_dir)

func _start_dash(dir: Vector2) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_velocity = dir * DASH_SPEED
	
	# Enable I-Frames (disable collision with enemies/projectiles)
	_original_collision_mask = collision_mask
	collision_mask = 8 # Only collide with walls (layer 4 = 8)
	
	# Visual feedback (optional: modulate or particles)
	modulate.a = 0.5

func _end_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = DASH_COOLDOWN
	velocity = Vector2.ZERO
	
	# Disable I-Frames
	collision_mask = _original_collision_mask
	
	# Reset visuals
	modulate.a = 1.0

func _on_died(last_attacker_id: int = -1) -> void:
	"""Called when player ship health reaches 0"""
	# Deactivate the ship
	is_active = false
	set_physics_process(false)
	
	# Show death screen
	_show_death_screen()

func _show_death_screen() -> void:
	"""Display death recap with stats and return to menu"""
	# Get game statistics
	var gold = GameState.gold if GameState and GameState.has_method("gold") else 0
	var level = RunManager.current_level_num if RunManager else 0
	
	# Create death panel
	var death_panel = PanelContainer.new()
	death_panel.anchor_left = 0.0
	death_panel.anchor_top = 0.0
	death_panel.anchor_right = 1.0
	death_panel.anchor_bottom = 1.0
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	death_panel.add_theme_stylebox_override("panel", bg)
	
	# Create VBox for death info
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -100
	vbox.custom_minimum_size = Vector2(300, 200)
	vbox.add_theme_constant_override("separation", 20)
	
	# Title
	var title = Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Stats
	var stats_text = "Level: %d\nGold Collected: %d" % [level, gold]
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 24)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)
	
	# Return to menu button
	var menu_button = Button.new()
	menu_button.text = "Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 50)
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.pressed.connect(func(): 
		get_tree().paused = false
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
	)
	vbox.add_child(menu_button)
	
	death_panel.add_child(vbox)
	
	# Add to scene tree as overlay
	get_tree().root.add_child(death_panel)
	get_tree().paused = true
