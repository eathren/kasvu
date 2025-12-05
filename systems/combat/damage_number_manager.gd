extends Node
class_name DamageNumberManager

## Spawns damage numbers above entities when they take damage
## Listens to damaged signals from HealthComponents

var damage_number_scene: PackedScene = preload("res://ui/damage_numbers/damage_number.tscn")

func _ready() -> void:
	# Connect to all existing health components
	_connect_to_health_components()
	
	# Connect to new health components as they're added
	get_tree().node_added.connect(_on_node_added)

func _connect_to_health_components() -> void:
	"""Find and connect to all HealthComponents in the scene"""
	var health_components = get_tree().get_nodes_in_group("health_component")
	for comp in health_components:
		if comp is HealthComponent:
			_connect_health_component(comp)

func _on_node_added(node: Node) -> void:
	"""Connect to HealthComponents as they're added to the tree"""
	if node is HealthComponent:
		_connect_health_component(node)

func _connect_health_component(health_comp: HealthComponent) -> void:
	"""Connect to a health component's damaged signal"""
	if not health_comp.damaged.is_connected(_on_entity_damaged):
		health_comp.damaged.connect(_on_entity_damaged.bind(health_comp))

func _on_entity_damaged(amount: int, is_crit: bool, is_megacrit: bool, attacker_id: int, health_comp: HealthComponent) -> void:
	"""Spawn a damage number when an entity takes damage"""
	if not damage_number_scene:
		return
	
	var parent = health_comp.get_parent()
	if not parent or not parent is Node2D:
		return
	
	var damage_num = damage_number_scene.instantiate() as Node2D
	if not damage_num:
		return
	
	# Determine damage type
	var damage_type = DamageNumber.DamageType.NORMAL
	if is_megacrit:
		damage_type = DamageNumber.DamageType.MEGACRIT
	elif is_crit:
		damage_type = DamageNumber.DamageType.CRIT
	
	damage_num.setup(amount, damage_type)
	damage_num.global_position = parent.global_position + Vector2(0, -16)
	
	# Add to root to persist after entity dies
	add_child(damage_num)
