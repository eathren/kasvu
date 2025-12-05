extends Node2D
class_name HealthBar

## Health bar that displays below an entity, red background with black depleting overlay
## Only shows when entity has taken damage

@export var bar_width: float = 32.0
@export var bar_height: float = 4.0
@export var offset_y: float = 20.0  # Distance below the entity
@export var hide_delay: float = 3.0  # Seconds before hiding after last damage

@onready var health_component: HealthComponent = get_parent().get_node("HealthComponent")

var current_health: float = 1.0
var max_health: float = 1.0
var is_damaged: bool = false
var damage_time: float = 0.0

func _ready() -> void:
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		max_health = health_component.max_health
		current_health = health_component.current_health
	else:
		push_warning("HealthBar: No HealthComponent found in parent")

func _on_health_changed(new_health: int, max_hp: int = 0) -> void:
	current_health = float(new_health)
	if max_hp > 0:
		max_health = float(max_hp)
	# Mark as damaged if not at full health
	if current_health < max_health:
		is_damaged = true
		damage_time = 0.0

func _process(delta: float) -> void:
	# Update damage timer
	if is_damaged:
		damage_time += delta
		if damage_time >= hide_delay:
			is_damaged = false
	
	queue_redraw()

func _draw() -> void:
	# Only draw if damaged
	if not is_damaged:
		return
	
	# Draw red background (full health bar)
	var red_rect = Rect2(-bar_width / 2.0, offset_y, bar_width, bar_height)
	draw_rect(red_rect, Color.RED)
	
	# Draw black overlay that depletes from right to left
	var health_ratio = clamp(current_health / max_health, 0.0, 1.0)
	var black_width = bar_width * (1.0 - health_ratio)
	
	# Only draw black if health is not full
	if black_width > 0.1:  # Small threshold to avoid artifacts
		var black_rect = Rect2(bar_width / 2.0 - black_width, offset_y, black_width, bar_height)
		draw_rect(black_rect, Color.BLACK)
	
	# Draw white border
	var border_rect = Rect2(-bar_width / 2.0, offset_y, bar_width, bar_height)
	draw_rect(border_rect, Color.WHITE, false, 1.0)
