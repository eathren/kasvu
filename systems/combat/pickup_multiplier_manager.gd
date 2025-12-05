extends Node
class_name PickupMultiplierManager

## Bridges PickupComponent with GameState for pickup multipliers
## Listens to pickup multiplier requests and applies values from GameState

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_to_pickups()
	get_tree().node_added.connect(_on_node_added)

func _connect_to_pickups() -> void:
	"""Connect to existing pickups"""
	for node in get_tree().get_nodes_in_group("pickup"):
		_try_connect_pickup(node)

func _on_node_added(node: Node) -> void:
	"""Connect to newly spawned pickups"""
	if node.is_in_group("pickup"):
		_try_connect_pickup(node)

func _try_connect_pickup(pickup: Node) -> void:
	"""Try to find and connect to pickup component"""
	var pickup_component = pickup.get_node_or_null("PickupComponent")
	if pickup_component and pickup_component is PickupComponent:
		if not pickup_component.needs_pickup_multiplier.is_connected(_on_pickup_needs_multiplier):
			pickup_component.needs_pickup_multiplier.connect(_on_pickup_needs_multiplier)

func _on_pickup_needs_multiplier(pickup_component: PickupComponent) -> void:
	"""Respond to pickup multiplier request"""
	var multiplier: float = 1.0
	
	# Get multiplier from GameState if available
	if GameState and GameState.has_method("get_pickup_range_multiplier"):
		multiplier = GameState.get_pickup_range_multiplier()
	
	# Apply to pickup
	pickup_component.apply_pickup_multiplier(multiplier)
