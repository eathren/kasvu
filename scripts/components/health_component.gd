extends Node
class_name HealthComponent

@export var max_health: int = 100
var current_health: int

signal health_changed(current: int, max: int)
signal died

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health -= amount
	if current_health < 0:
		current_health = 0

	health_changed.emit(current_health, max_health)

	if current_health == 0:
		died.emit()

## Alias for compatibility
func take_damage(amount: float) -> void:
	apply_damage(int(amount))

func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health += amount
	if current_health > max_health:
		current_health = max_health

	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0
