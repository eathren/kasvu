extends Node2D

@export var base_scroll_speed: float = GameState.get_trawler_speed()

var depth: float = 0.0
var dig_multiplier: float = 1.0

func _physics_process(delta: float) -> void:
	var scroll_speed := base_scroll_speed * dig_multiplier
	var dy := -scroll_speed * delta
	position.y += dy
	depth += scroll_speed * delta
