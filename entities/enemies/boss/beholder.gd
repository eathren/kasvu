extends CharacterBody2D
class_name Beholder

## Beholder Boss - Floating eye with radial bullet attacks

enum BossState {
	IDLE,
	CHASE,
	ATTACK,
	RADIAL_ATTACK,
	RETREAT
}

@export var bullet_scene: PackedScene = preload("res://entities/projectiles/bullet/bullet.tscn")
@export var hover_speed: float = 100.0
@export var detection_range: float = 400.0
@export var attack_range: float = 250.0
@export var retreat_range: float = 100.0

# Attack patterns
@export_group("Radial Attack")
@export var radial_bullet_count: int = 12
@export var radial_attack_cooldown: float = 3.0
@export var radial_bullet_speed: float = 200.0
@export var radial_bullet_damage: int = 15

@export_group("Single Attack")
@export var single_attack_cooldown: float = 0.5
@export var single_bullet_speed: float = 300.0
@export var single_bullet_damage: int = 10

@onready var health_component: HealthComponent = $HealthComponent
@onready var faction_component: FactionComponent = $FactionComponent
@onready var pathfinding: PathfindingComponent = $PathfindingComponent
@onready var sprite: Sprite2D = $Sprite2D

var current_state: BossState = BossState.IDLE
var target: Node2D = null
var radial_attack_timer: float = 0.0
var single_attack_timer: float = 0.0
var hover_offset: float = 0.0
var hover_time: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	
	# Connect health signals
	if health_component:
		health_component.died.connect(_on_death)
	
	# Start idle
	current_state = BossState.IDLE

func _physics_process(delta: float) -> void:
	hover_time += delta
	hover_offset = sin(hover_time * 2.0) * 10.0  # Gentle hover motion
	
	# Update timers
	radial_attack_timer -= delta
	single_attack_timer -= delta
	
	# Find target if we don't have one
	if not target or not is_instance_valid(target):
		_find_target()
	
	# State machine
	match current_state:
		BossState.IDLE:
			_state_idle(delta)
		BossState.CHASE:
			_state_chase(delta)
		BossState.ATTACK:
			_state_attack(delta)
		BossState.RADIAL_ATTACK:
			_state_radial_attack(delta)
		BossState.RETREAT:
			_state_retreat(delta)
	
	move_and_slide()

func _state_idle(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)
	
	if target:
		var distance := global_position.distance_to(target.global_position)
		if distance <= detection_range:
			current_state = BossState.CHASE

func _state_chase(delta: float) -> void:
	if not target:
		current_state = BossState.IDLE
		return
	
	var distance := global_position.distance_to(target.global_position)
	
	if distance <= retreat_range:
		current_state = BossState.RETREAT
	elif distance <= attack_range:
		current_state = BossState.ATTACK
	else:
		# Move toward target using pathfinding
		if pathfinding:
			pathfinding.set_destination(target.global_position)
			if pathfinding.has_path():
				var direction = pathfinding.get_move_direction()
				velocity = direction * hover_speed
			else:
				# Fallback to direct movement
				var direction := global_position.direction_to(target.global_position)
				velocity = direction * hover_speed
		else:
			# Fallback when no pathfinding
			var direction := global_position.direction_to(target.global_position)
			velocity = direction * hover_speed
		# Apply hover effect
		velocity.y += hover_offset * 0.1

func _state_attack(delta: float) -> void:
	if not target:
		current_state = BossState.IDLE
		return
	
	var distance := global_position.distance_to(target.global_position)
	
	# Maintain distance
	if distance < retreat_range:
		current_state = BossState.RETREAT
		return
	elif distance > attack_range * 1.5:
		current_state = BossState.CHASE
		return
	
	# Slow down while attacking
	velocity = velocity.lerp(Vector2.ZERO, 3.0 * delta)
	
	# Perform radial attack periodically
	if radial_attack_timer <= 0.0:
		_fire_radial_attack()
		radial_attack_timer = radial_attack_cooldown
	
	# Fire single shots between radial attacks
	elif single_attack_timer <= 0.0:
		_fire_single_shot()
		single_attack_timer = single_attack_cooldown

func _state_radial_attack(delta: float) -> void:
	# Transition back to attack after firing
	current_state = BossState.ATTACK

func _state_retreat(delta: float) -> void:
	if not target:
		current_state = BossState.IDLE
		return
	
	var distance := global_position.distance_to(target.global_position)
	
	if distance >= attack_range:
		current_state = BossState.ATTACK
	else:
		# Move away from target using pathfinding
		var retreat_direction := target.global_position.direction_to(global_position)
		var retreat_point := global_position + retreat_direction * 200.0
		
		if pathfinding:
			pathfinding.set_destination(retreat_point)
			if pathfinding.has_path():
				var direction = pathfinding.get_move_direction()
				velocity = direction * hover_speed
			else:
				# Fallback to direct retreat
				velocity = retreat_direction * hover_speed
		else:
			# Fallback when no pathfinding
			velocity = retreat_direction * hover_speed
		# Apply hover effect
		velocity.y += hover_offset * 0.1
		
		# Still attack while retreating
		if single_attack_timer <= 0.0:
			_fire_single_shot()
			single_attack_timer = single_attack_cooldown * 1.5

func _find_target() -> void:
	# Find player ships or crew
	var potential_targets := get_tree().get_nodes_in_group("player_ship")
	potential_targets.append_array(get_tree().get_nodes_in_group("crew"))
	
	var closest_distance := INF
	var closest_target: Node2D = null
	
	for potential in potential_targets:
		if not is_instance_valid(potential):
			continue
		var node := potential as Node2D
		if not node:
			continue
		
		var distance := global_position.distance_to(node.global_position)
		if distance < closest_distance and distance <= detection_range:
			closest_distance = distance
			closest_target = node
	
	target = closest_target

func _fire_radial_attack() -> void:
	if not bullet_scene:
		return
	
	print("Beholder: Firing radial attack with %d bullets" % radial_bullet_count)
	
	var angle_step := TAU / radial_bullet_count
	
	for i in range(radial_bullet_count):
		var angle := angle_step * i
		var direction := Vector2.RIGHT.rotated(angle)
		
		var bullet := bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.global_rotation = direction.angle()
		
		if "speed" in bullet:
			bullet.speed = radial_bullet_speed
		if "damage" in bullet:
			bullet.damage = radial_bullet_damage
		if "faction" in bullet:
			bullet.faction = FactionComponent.Faction.ENEMY

func _fire_single_shot() -> void:
	if not bullet_scene or not target:
		return
	
	var direction := global_position.direction_to(target.global_position)
	
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.global_rotation = direction.angle()
	
	if "speed" in bullet:
		bullet.speed = single_bullet_speed
	if "damage" in bullet:
		bullet.damage = single_bullet_damage
	if "faction" in bullet:
		bullet.faction = FactionComponent.Faction.ENEMY

func _on_death() -> void:
	print("Beholder: Boss defeated!")
	# TODO: Drop loot, play death animation, etc.
	queue_free()
