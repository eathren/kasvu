extends Area2D
class_name ResourcePickup

## Pickup item for gold, scrap, or other resources

enum ResourceType {
	GOLD,
	SCRAP
}

@export var resource_type: ResourceType = ResourceType.GOLD
@export var amount: int = 1

@onready var pickup_component: PickupComponent = $PickupComponent

func _ready() -> void:
	collision_layer = 256  # Pickup layer (bit 9)
	collision_mask = 4  # Player layer (bit 3)
	
	# Connect to pickup component
	if pickup_component:
		pickup_component.collected.connect(_on_collected)

func _on_collected(_collector: Node2D) -> void:
	if not GameState:
		return
	
	match resource_type:
		ResourceType.GOLD:
			GameState.add_gold(amount)
		ResourceType.SCRAP:
			GameState.add_scrap(amount)
