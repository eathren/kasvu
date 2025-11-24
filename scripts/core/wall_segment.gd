extends Area2D

signal destroyed(cell: Vector2i)

@export var max_health: int = 100

var health: int
var cell: Vector2i

func _ready() -> void:
	health = max_health
	input_pickable = true

func setup(cell_position: Vector2i) -> void:
	cell = cell_position

func apply_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_do_destroy()

func _input_event(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		_do_destroy()

func _do_destroy() -> void:
	destroyed.emit(cell)
	queue_free()
