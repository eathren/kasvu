extends Area2D
class_name HurtboxComponent

## Detects incoming damage from enemy attacks and touch damage
## Decoupled: emits signals instead of directly modifying health or visuals

signal hit_received(damage: int, attacker: Node, attacker_id: int)
signal invulnerability_started()
signal invulnerability_ended()

@export var health_component_path: NodePath = NodePath("../HealthComponent")
@export var invulnerability_time: float = 0.5  # Time between damage instances

var health_component: HealthComponent = null
var invulnerable: bool = false
var invulnerable_timer: float = 0.0

func _ready() -> void:
	# Set collision layers
	collision_layer = 0  # Don't be detected by others
	collision_mask = 8  # Detect enemy damage areas (layer 8)
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	
	# Find health component
	if has_node(health_component_path):
		health_component = get_node(health_component_path) as HealthComponent

func _process(delta: float) -> void:
	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false
			invulnerability_ended.emit()

func _on_area_entered(area: Area2D) -> void:
	"""Handle damage from enemy damage areas"""
	if invulnerable:
		return
	
	# Check if it's an enemy damage area
	var attacker = area.get_parent()
	var damage_component = attacker.get_node_or_null("TouchDamageComponent")
	
	if damage_component and damage_component.has_method("can_damage_target"):
		var parent_node = get_parent()
		if damage_component.can_damage_target(parent_node):
			var damage = damage_component.get_damage()
			damage_component.record_damage(parent_node)
			
			# Get attacker ID if it's a multiplayer entity
			var attacker_id := -1
			if attacker.has_method("get_multiplayer_authority"):
				attacker_id = attacker.get_multiplayer_authority()
			
			take_damage(damage, attacker, attacker_id)

func take_damage(amount: int, attacker: Node = null, attacker_id: int = -1) -> void:
	"""Process incoming damage"""
	if invulnerable:
		return
	
	# Apply damage to health component
	if health_component:
		health_component.take_damage(amount, false, false, attacker_id)
	
	# Emit signal for visual/audio feedback
	hit_received.emit(amount, attacker, attacker_id)
	
	# Start invulnerability
	if invulnerability_time > 0:
		invulnerable = true
		invulnerable_timer = invulnerability_time
		invulnerability_started.emit()

func set_invulnerable(value: bool) -> void:
	"""Manually set invulnerability state"""
	invulnerable = value
	if not value:
		invulnerability_ended.emit()

func get_is_invulnerable() -> bool:
	return invulnerable
