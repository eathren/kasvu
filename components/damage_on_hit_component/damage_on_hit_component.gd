extends Area2D
class_name DamageOnHit

## Deals damage to targets with HealthComponent on collision, then destroys itself
## Decoupled: uses flexible health component lookup

signal target_hit(target: Node, damage_dealt: int)

@export var damage: int = 10
@export var health_component_name: String = "HealthComponent"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	var health_component = _find_health_component(body)
	if health_component:
		health_component.apply_damage(damage)
		target_hit.emit(body, damage)
	queue_free()

func _find_health_component(target: Node) -> HealthComponent:
	"""Flexible health component lookup"""
	# Try exported name first
	var health = target.get_node_or_null(health_component_name)
	if health and health is HealthComponent:
		return health
	
	# Fallback: search children for HealthComponent
	for child in target.get_children():
		if child is HealthComponent:
			return child
	
	return null
