extends CharacterBody2D

@export var speed: float = 60.0
@export var trawler_threat: float = 100.0  # Base threat value for trawler
@export var player_proximity_threat_range: float = 150.0  # Range at which players become threatening
@export var player_threat_multiplier: float = 2.0  # How much more threatening a nearby player is

@onready var health: HealthComponent = $HealthComponent
@onready var pathfinding: PathfindingComponent = $PathfindingComponent

var exp_crystal_scene: PackedScene = preload("res://entities/items/pickups/exp_crystal/exp_crystal.tscn")
var target: Node2D
var trawler: Node2D

func _ready() -> void:
	add_to_group("enemy")

	# Collision layer 1 (enemy body) set in scene
	# Collision mask 8 (only walls) set in scene - enemies don't collide with players or each other

	trawler = get_tree().get_first_node_in_group("trawler") as Node2D
	target = trawler
	if health != null:
		print("[Imp] Connecting to health.died signal")
		health.died.connect(_on_died)
		print("[Imp] Connection successful. Signal connections: ", health.died.get_connections())
	else:
		print("[Imp] ERROR: HealthComponent is null!")
	
	# Connect pathfinding signals
	if pathfinding:
		pathfinding.path_failed.connect(_on_path_failed)

func _physics_process(delta: float) -> void:
	# Update target priority each frame using threat system
	_update_target_by_threat()
	
	if target == null:
		return
	
	# Update destination to follow target
	if pathfinding:
		pathfinding.set_destination(target.global_position)
		
		# Use pathfinding direction if we have a path
		if pathfinding.has_path():
			var direction = pathfinding.get_move_direction()
			velocity = direction * speed
			if randf() < 0.01:  # Debug occasionally
				print("[Imp] Moving via pathfinding. Direction: ", direction, " Target: ", target.name, " at ", target.global_position)
		else:
			# Fallback to direct movement if no path available
			var dir = (target.global_position - global_position).normalized()
			velocity = dir * speed
			if randf() < 0.01:  # Debug occasionally
				print("[Imp] No path, direct movement. Direction: ", dir, " Target: ", target.name, " My pos: ", global_position, " Target pos: ", target.global_position)
	else:
		# Fallback when pathfinding is not available
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
	
	move_and_slide()

func _update_target_by_threat() -> void:
	"""Threat system: trawler is default high threat, but very close players are higher threat"""
	if not trawler or not is_instance_valid(trawler):
		trawler = get_tree().get_first_node_in_group("trawler")
		target = trawler
		return
	
	var highest_threat: float = 0.0
	var highest_threat_target: Node2D = null
	
	# Trawler always has base threat
	highest_threat = trawler_threat
	highest_threat_target = trawler
	
	# Check player threats
	var player_ships = get_tree().get_nodes_in_group("player_ship")
	for ship in player_ships:
		if not ship or not is_instance_valid(ship):
			continue
		
		var ship_node := ship as Node2D
		if not ship_node:
			continue
		
		var distance_to_ship := global_position.distance_to(ship_node.global_position)
		
		# Threat decreases with distance
		# At player_proximity_threat_range, threat = trawler_threat * player_threat_multiplier
		# Beyond that, threat drops off
		if distance_to_ship < player_proximity_threat_range:
			var threat := (trawler_threat * player_threat_multiplier) * (1.0 - (distance_to_ship / player_proximity_threat_range))
			
			if threat > highest_threat:
				highest_threat = threat
				highest_threat_target = ship_node
	
	target = highest_threat_target

func _on_path_failed() -> void:
	# Path failed, will recalculate via _update_target_by_threat next frame
	pass

func _on_died(last_attacker_id: int = -1) -> void:
	print("[Imp] _on_died called! attacker_id: ", last_attacker_id)
	
	# Spawn exp crystal
	if exp_crystal_scene:
		var crystal := exp_crystal_scene.instantiate() as Node2D
		if crystal:
			if "xp_value" in crystal:
				crystal.xp_value = 10  # Base XP for imp
			crystal.global_position = global_position
			get_parent().call_deferred("add_child", crystal)
	
	queue_free()
