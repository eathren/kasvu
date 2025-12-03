extends CharacterBody2D

@export var speed: float = 60.0

@onready var health: HealthComponent = $HealthComponent
@onready var pathfinding: PathfindingComponent = $PathfindingComponent
@onready var exp_crystal: PackedScene 
var target: Node2D

func _ready() -> void:
	add_to_group("enemy")

	# Set collision layer to Enemy (layer 1 = 2^0 = 1)
	# This allows Area2D bullets to detect us via their collision_mask
	collision_layer = 1

	target = get_tree().get_first_node_in_group("trawler") as Node2D
	if health != null:
		health.died.connect(_on_died)
	
	# Connect pathfinding signals
	if pathfinding:
		pathfinding.path_failed.connect(_on_path_failed)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	# Update destination to follow target
	if pathfinding:
		pathfinding.set_destination(target.global_position)
		
		# Use pathfinding direction if we have a path
		if pathfinding.has_path():
			var direction = pathfinding.get_move_direction()
			velocity = direction * speed
		else:
			# Fallback to direct movement if no path available
			var dir = (target.global_position - global_position).normalized()
			velocity = dir * speed
	else:
		# Fallback when pathfinding is not available
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
	
	move_and_slide()

func _on_path_failed() -> void:
	# Try to find a new target if current path fails
	var ships = get_tree().get_nodes_in_group("player_ship")
	if not ships.is_empty():
		target = ships[0]
	else:
		target = get_tree().get_first_node_in_group("trawler")

func _on_died() -> void:
	queue_free()
	exp_crystal.instantiate()
