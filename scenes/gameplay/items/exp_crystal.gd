extends Area2D
class_name ExpCrystal

## Experience crystal that can be picked up by player or trawler

@export var xp_value: int = 10

@onready var pickup_component: PickupComponent = $PickupComponent

func _ready() -> void:
	collision_layer = 256  # Pickup layer (bit 9)
	collision_mask = 4  # Player layer (bit 3)
	
	# Connect to pickup component
	if pickup_component:
		pickup_component.collected.connect(_on_collected)

func _on_collected(_collector: Node2D) -> void:
	if GameState.has_method("add_experience"):
		GameState.add_experience(xp_value)
