extends CharacterBody2D

@export var crew_stats: CrewStats = preload("res://resources/config/crew/default_crew.tres")

var speed: float = 200.0  # Set from crew_stats in _ready()
var is_active: bool = true
var health_bar: ProgressBar = null
var look_direction: Vector2 = Vector2.UP  # Track aim direction

func _ready() -> void:
	add_to_group("player")
	
	# Set player ID on weapon component so it can read modifiers
	var weapon_component = get_node_or_null("WeaponComponent") as WeaponComponent
	if weapon_component and weapon_component.has_method("set_player_id"):
		weapon_component.set_player_id(multiplayer.get_unique_id())
	
	# Connect to hurtbox component signals
	var hurtbox = get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox:
		hurtbox.hit_received.connect(_on_hit_received)
	
	# Connect to health component death signal
	var health_component = get_node_or_null("HealthComponent") as HealthComponent
	if health_component:
		health_component.died.connect(_on_died)
	
	# Apply stats from crew_stats resource
	if crew_stats:
		speed = crew_stats.move_speed
		
		# Apply to HealthComponent (scaled by team level)
		if health_component:
			health_component.max_health = GameState.get_base_max_health()
			health_component.current_health = health_component.max_health
		
		# Apply to SpeedComponent
		var speed_component := get_node_or_null("SpeedComponent") as SpeedComponent
		if speed_component:
			speed_component.base_speed = crew_stats.move_speed
		
		# Apply to HealthRegenComponent (scaled by team level)
		var health_regen := get_node_or_null("HealthRegenComponent") as HealthRegenComponent
		if health_regen:
			health_regen.base_regen_per_second = GameState.get_base_health_regen()
			health_regen.current_regen_rate = GameState.get_base_health_regen()
		
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
	
	# Movement (left stick / WASD)
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	
	# Firing (right stick / mouse aim) - Twin-stick shooter style
	_handle_firing()
	
	# Update halo glow based on zeal
	_update_halo_glow()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)

func activate() -> void:
	is_active = true
	visible = true
	set_physics_process(true)

func _on_hit_received(damage: int, attacker: Node) -> void:
	"""Called when HurtboxComponent receives damage"""
	# Show/update health bar
	if not health_bar:
		_spawn_health_bar()
	
	if health_bar:
		var health_component = get_node_or_null("HealthComponent") as HealthComponent
		if health_component:
			health_bar.max_value = health_component.max_health
			health_bar.value = health_component.current_health
			health_bar.visible = true

func take_damage(amount: int) -> void:
	"""Deprecated - damage is now handled by HurtboxComponent"""
	pass

func _handle_firing() -> void:
	"""Twin-stick shooter firing - aim with right stick or mouse"""
	var weapon_component = get_node_or_null("WeaponComponent") as WeaponComponent
	var mining_component = get_node_or_null("MiningComponent") as Node2D
	
	# Get aim direction from right stick or mouse
	var aim_dir := Vector2.ZERO
	
	# Controller right stick (aim_right/aim_left/aim_up/aim_down)
	var aim_x := Input.get_action_strength("aim_right") - Input.get_action_strength("aim_left")
	var aim_y := Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")
	aim_dir = Vector2(aim_x, aim_y)
	
	# Fallback to mouse aiming if no controller input
	if aim_dir.length() < 0.1:
		# Check if fire button is held (for mouse/keyboard)
		if Input.is_action_pressed("fire"):
			var mouse_pos := get_global_mouse_position()
			aim_dir = global_position.direction_to(mouse_pos)
	
	# Check if mining key is held (secondary action)
	var is_mining_pressed := Input.is_action_pressed("interact") or Input.is_action_pressed("ui_accept")
	
	if is_mining_pressed and aim_dir.length() > 0.1:
		# Mining mode - dig in aim direction
		aim_dir = aim_dir.normalized()
		look_direction = aim_dir
		
		if mining_component and mining_component.has_method("start_mining"):
			mining_component.start_mining(aim_dir)
		
		# Don't fire weapon while mining
		return
	else:
		# Stop mining when key released
		if mining_component and mining_component.has_method("stop_mining"):
			mining_component.stop_mining()
	
	# Fire weapon continuously while aiming (and not mining)
	if aim_dir.length() > 0.1 and weapon_component:
		aim_dir = aim_dir.normalized()
		look_direction = aim_dir
		weapon_component.fire_in_direction(self, aim_dir)

func _update_halo_glow() -> void:
	"""Update halo glow based on current Zeal"""
	var halo = get_node_or_null("PlayerHalo") as PointLight2D
	if not halo or not ZealManager:
		return
	
	var player_id = multiplayer.get_unique_id()
	var zeal_ratio = ZealManager.get_zeal(player_id)  # 0.0 to 1.0
	
	# Scale energy from 0.5 (no zeal) to 2.5 (full zeal)
	halo.energy = lerp(0.5, 2.5, zeal_ratio)
	
	# Color shifts from cool blue to hot white/yellow as zeal increases
	var cool = Color(0.8, 0.9, 1.0)  # Blue
	var hot = Color(1.0, 0.95, 0.8)  # Warm white
	halo.color = cool.lerp(hot, zeal_ratio)

func _spawn_health_bar() -> void:
	"""Create floating health bar above player"""
	if health_bar:
		return
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -20)
	health_bar.show_percentage = false
	
	# Style the health bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.2, 0.2, 1.0)
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	add_child(health_bar)

func _on_died(last_attacker_id: int = -1) -> void:
	"""Called when player health reaches 0"""
	deactivate()
	
	# Show death screen
	if multiplayer.is_server():
		_show_death_screen()

func _show_death_screen() -> void:
	"""Display death recap with stats and return to menu"""
	# Get game statistics
	var gold = GameState.gold if GameState and GameState.has_method("get_gold") else 0
	var kills = RunManager.total_kills if RunManager and RunManager.has_method("get_total_kills") else 0
	var level = GameState.current_level if GameState else 0
	var time_alive = Time.get_ticks_msec() / 1000.0  # Approximate
	
	# Create a simple death screen overlay
	var death_panel = PanelContainer.new()
	death_panel.anchor_left = 0.0
	death_panel.anchor_top = 0.0
	death_panel.anchor_right = 1.0
	death_panel.anchor_bottom = 1.0
	death_panel.modulate = Color(0, 0, 0, 0.8)
	
	# Create a VBox for the death info
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -100
	vbox.custom_minimum_size = Vector2(300, 200)
	vbox.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Stats
	var stats_text = "Level: %d\nGold: %d\nKills: %d" % [level, gold, kills]
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Return to menu button
	var menu_button = Button.new()
	menu_button.text = "Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 40)
	menu_button.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn"))
	vbox.add_child(menu_button)
	
	death_panel.add_child(vbox)
	
	# Add to scene tree as overlay
	get_tree().root.add_child(death_panel)
