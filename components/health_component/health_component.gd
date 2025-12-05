extends Node
class_name HealthComponent

@export var max_health: int = 100

var current_health: int
var last_attacker_id: int = -1

signal health_changed(current: int, max: int)
signal died(last_attacker_id: int)
signal damaged(amount: int, is_crit: bool, is_megacrit: bool, attacker_id: int)

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _set_health(value: int) -> void:
	var clamped :int = clamp(value, 0, max_health)
	if clamped == current_health:
		return
	
	current_health = clamped
	health_changed.emit(current_health, max_health)
	
	if current_health == 0:
		print("[HealthComponent] ", get_parent().name, " DIED! Emitting died signal with attacker_id: ", last_attacker_id)
		died.emit(last_attacker_id)

func apply_damage(amount: int, is_crit: bool = false, is_megacrit: bool = false, attacker_id: int = -1) -> void:
	if amount <= 0:
		return
	
	if current_health <= 0:
		return
	
	if attacker_id >= 0:
		last_attacker_id = attacker_id
	
	damaged.emit(amount, is_crit, is_megacrit, attacker_id)
	
	var new_health = current_health - amount
	print("[HealthComponent] ", get_parent().name, " taking ", amount, " damage. Health: ", current_health, " -> ", max(0, new_health))
	_set_health(new_health)

func take_damage(amount: float, is_crit: bool = false, is_megacrit: bool = false, attacker_id: int = -1) -> void:
	apply_damage(int(amount), is_crit, is_megacrit, attacker_id)

func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	_set_health(current_health + amount)

func is_dead() -> bool:
	return current_health <= 0

func get_last_attacker_id() -> int:
	return last_attacker_id
