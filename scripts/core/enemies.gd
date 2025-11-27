extends CharacterBody2D

## Base enemy script with component-based systems

@export var damage_per_second: float = 10.0
@export var exp_crystal_scene: PackedScene = preload("res://scenes/gameplay/items/exp_crystal.tscn")

var _target: Node2D = null
var _health_component: HealthComponent = null
var _speed_component: SpeedComponent = null

func _ready() -> void:
	add_to_group("enemy")
	
	# Get components
	_health_component = get_node_or_null("HealthComponent")
	_speed_component = get_node_or_null("SpeedComponent")
	
	# Connect health component if it exists
	if _health_component:
		_health_component.died.connect(_on_death)
	
	# Find initial target (prefer player ship, fall back to trawler)
	_update_target()

func _physics_process(delta: float) -> void:
	# Update target if we don't have one
	if _target == null or not is_instance_valid(_target):
		_update_target()
	
	if _target == null:
		return
	
	# Move towards target
	var dir := (global_position.direction_to(_target.global_position))
	var current_speed := _speed_component.get_current_speed() if _speed_component else 60.0
	velocity = dir * current_speed
	move_and_slide()
	
	# Check for collision damage
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		
		# Damage player ship or trawler on collision
		if collider.is_in_group("player_ship") or collider.is_in_group("trawler"):
			_deal_damage_to(collider, delta)

func _update_target() -> void:
	# Prefer player ship as target
	var player_ships := get_tree().get_nodes_in_group("player_ship")
	if not player_ships.is_empty():
		_target = player_ships[0] as Node2D
		return
	
	# Fall back to trawler
	_target = get_tree().get_first_node_in_group("trawler") as Node2D

func _deal_damage_to(target: Node, delta: float) -> void:
	# Look for HealthComponent on target
	var health_comp = target.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage_per_second * delta)

func _on_death() -> void:
	# Spawn exp crystal
	if exp_crystal_scene:
		var crystal := exp_crystal_scene.instantiate() as Node2D
		if crystal:
			get_parent().add_child(crystal)
			crystal.global_position = global_position
	
	queue_free()

func take_damage(amount: float) -> void:
	if _health_component:
		_health_component.take_damage(amount)
	else:
		# No health component, die immediately
		_on_death()
