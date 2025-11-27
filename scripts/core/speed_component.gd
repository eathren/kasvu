extends Node
class_name SpeedComponent

## Reusable speed component with modifiers

signal speed_changed(new_speed: float)

@export var base_speed: float = 100.0

var _speed_multipliers: Dictionary = {}  # Key: source name, Value: multiplier

func get_current_speed() -> float:
	var total_multiplier := 1.0
	for multiplier in _speed_multipliers.values():
		total_multiplier *= multiplier
	return base_speed * total_multiplier

func add_speed_modifier(source: String, multiplier: float) -> void:
	_speed_multipliers[source] = multiplier
	speed_changed.emit(get_current_speed())

func remove_speed_modifier(source: String) -> void:
	if source in _speed_multipliers:
		_speed_multipliers.erase(source)
		speed_changed.emit(get_current_speed())

func clear_modifiers() -> void:
	_speed_multipliers.clear()
	speed_changed.emit(get_current_speed())

func set_base_speed(new_speed: float) -> void:
	base_speed = new_speed
	speed_changed.emit(get_current_speed())

