extends Node
class_name HurtboxFeedbackManager

## Centralized system for visual feedback when entities take damage
## Listens to HurtboxComponent signals and applies flash effects

const FLASH_COLOR := Color(1, 1, 1, 0.5)
const NORMAL_COLOR := Color.WHITE

var _flash_tracking: Dictionary = {}  # entity_id -> flash_timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_to_hurtbox_components()
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	# Update all active flashes
	for entity_id in _flash_tracking.keys():
		var data = _flash_tracking[entity_id]
		data.timer -= delta
		
		if data.timer <= 0:
			# End flash
			if is_instance_valid(data.entity):
				data.entity.modulate = NORMAL_COLOR
			_flash_tracking.erase(entity_id)
		else:
			# Flash effect (on/off based on timer)
			if is_instance_valid(data.entity):
				if int(data.timer * 10) % 2 == 0:
					data.entity.modulate = FLASH_COLOR
				else:
					data.entity.modulate = NORMAL_COLOR

func _connect_to_hurtbox_components() -> void:
	"""Connect to all existing hurtbox components"""
	for node in get_tree().get_nodes_in_group("entities"):
		_try_connect_hurtbox(node)

func _on_node_added(node: Node) -> void:
	"""Connect to newly added hurtbox components"""
	if node.is_in_group("entities"):
		_try_connect_hurtbox(node)

func _try_connect_hurtbox(entity: Node) -> void:
	"""Try to find and connect to a hurtbox component"""
	var hurtbox = entity.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox is HurtboxComponent:
		if not hurtbox.invulnerability_started.is_connected(_on_hurtbox_invulnerability_started):
			hurtbox.invulnerability_started.connect(_on_hurtbox_invulnerability_started.bind(entity, hurtbox))
		if not hurtbox.invulnerability_ended.is_connected(_on_hurtbox_invulnerability_ended):
			hurtbox.invulnerability_ended.connect(_on_hurtbox_invulnerability_ended.bind(entity))

func _on_hurtbox_invulnerability_started(entity: Node2D, hurtbox: HurtboxComponent) -> void:
	"""Start flash effect when entity becomes invulnerable"""
	var entity_id = entity.get_instance_id()
	_flash_tracking[entity_id] = {
		"entity": entity,
		"timer": hurtbox.invulnerability_time
	}

func _on_hurtbox_invulnerability_ended(entity: Node2D) -> void:
	"""Ensure entity returns to normal color"""
	if is_instance_valid(entity):
		entity.modulate = NORMAL_COLOR
	var entity_id = entity.get_instance_id()
	_flash_tracking.erase(entity_id)
