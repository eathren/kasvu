extends Node
class_name PickupComponent

## Reusable component for pickup magnetism and collection
## Attach to any Area2D pickup item

signal collected(collector: Node2D)

@export var base_magnet_speed: float = 200.0
@export var base_collection_distance: float = 10.0
@export var can_be_picked_by_trawler: bool = true
@export var can_be_picked_by_player: bool = true
@export var can_be_picked_by_ship: bool = true
@export var pickup_sound: AudioStream = preload("res://assets/audio/pickup.wav")

var _target: Node2D = null
var _is_being_collected: bool = false
var _area_2d: Area2D = null
var _current_magnet_speed: float = 200.0
var _current_collection_distance: float = 10.0
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	# Get the parent Area2D
	if get_parent() is Area2D:
		_area_2d = get_parent() as Area2D
		_area_2d.body_entered.connect(_on_body_entered)
		_area_2d.area_entered.connect(_on_area_entered)
	else:
		push_error("PickupComponent: Parent must be an Area2D!")
	
	# Setup audio player
	_setup_audio_player()
	
	# Apply pickup range multiplier from GameState
	_update_pickup_range()

func _physics_process(delta: float) -> void:
	if not _is_being_collected or not is_instance_valid(_target):
		return
	
	if not _area_2d:
		return
	
	# Move towards target
	var direction := _area_2d.global_position.direction_to(_target.global_position)
	_area_2d.global_position += direction * _current_magnet_speed * delta
	
	# Check if close enough to collect
	if _area_2d.global_position.distance_to(_target.global_position) < _current_collection_distance:
		_collect()

func _on_body_entered(body: Node2D) -> void:
	if not _can_pick_up(body):
		return
	
	_target = body
	_is_being_collected = true

func _on_area_entered(area: Area2D) -> void:
	# Check if it's a pickup area from player/ship
	var parent = area.get_parent()
	if parent and _can_pick_up(parent):
		_target = parent
		_is_being_collected = true

func _can_pick_up(node: Node2D) -> bool:
	"""Check if this node is allowed to pick up this item"""
	if not node:
		return false
	
	if node.is_in_group("trawler") and can_be_picked_by_trawler:
		return true
	
	if node.is_in_group("player") and can_be_picked_by_player:
		return true
	
	if node.is_in_group("player_ship") and can_be_picked_by_ship:
		return true
	
	return false

func _collect() -> void:
	"""Called when pickup is collected - emits signal and queues parent for deletion"""
	collected.emit(_target)
	
	# Play pickup sound and delete after it finishes
	_play_pickup_sound()

func stop_collection() -> void:
	"""Stop the magnet effect"""
	_is_being_collected = false
	_target = null

func start_collection(target: Node2D) -> void:
	"""Manually start collecting toward a target"""
	_target = target
	_is_being_collected = true

func _update_pickup_range() -> void:
	"""Update pickup range based on GameState multiplier"""
	var multiplier: float = 1.0
	if GameState and GameState.has_method("get_pickup_range_multiplier"):
		multiplier = GameState.get_pickup_range_multiplier()
	
	_current_magnet_speed = base_magnet_speed * multiplier
	_current_collection_distance = base_collection_distance * multiplier

func _setup_audio_player() -> void:
	"""Setup audio player for pickup sound"""
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "SFX"  # Use SFX bus if it exists, otherwise Master
	add_child(_audio_player)
	
	if pickup_sound:
		_audio_player.stream = pickup_sound

func _play_pickup_sound() -> void:
	"""Play pickup sound effect"""
	if not _audio_player or not pickup_sound or not _area_2d:
		if _area_2d:
			_area_2d.queue_free()
		return
	
	# Hide the pickup visually and disable collision immediately
	_area_2d.hide()
	_area_2d.collision_layer = 0
	_area_2d.collision_mask = 0
	_is_being_collected = false  # Stop magnet effect
	
	# Reparent audio player to level root so it survives deletion
	var level_root = _area_2d.get_parent()
	if level_root:
		remove_child(_audio_player)
		level_root.add_child(_audio_player)
	
	# Play sound
	_audio_player.play()
	
	# Wait for sound to finish then delete both
	await _audio_player.finished
	_audio_player.queue_free()
	
	if is_instance_valid(_area_2d):
		_area_2d.queue_free()
