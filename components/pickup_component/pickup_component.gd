extends Node
class_name PickupComponent

## Handles pickup magnetism and collection
## Decoupled: uses signals for stats, removes hardcoded audio

signal collected(collector: Node2D)
signal needs_pickup_multiplier(component: PickupComponent)

@export var base_magnet_speed: float = 200.0
@export var base_collection_distance: float = 10.0
@export var can_be_picked_by_trawler: bool = true
@export var can_be_picked_by_player: bool = true
@export var can_be_picked_by_ship: bool = true
@export var pickup_sound: AudioStream = null
@export var player_group_name: String = "player_ship"  # Configurable group

var _target: Node2D = null
var _is_being_collected: bool = false
var _is_flying_to_player: bool = false
var _area_2d: Area2D = null
var _current_magnet_speed: float = 200.0
var _current_collection_distance: float = 10.0
var _spawn_time: float = 0.0
var _auto_fly_delay: float = 0.5  # Wait before auto-flying to player

@onready var _audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if get_parent() is Area2D:
		_area_2d = get_parent() as Area2D
		_area_2d.body_entered.connect(_on_body_entered)
		_area_2d.area_entered.connect(_on_area_entered)
	else:
		push_error("PickupComponent parent must be an Area2D")

	# hook up sound
	if pickup_sound:
		_audio_player.stream = pickup_sound

	_spawn_time = Time.get_ticks_msec() / 1000.0
	_update_pickup_range()

func _update_pickup_range() -> void:
	# Request multiplier via signal (systems can respond)
	needs_pickup_multiplier.emit(self)
	
	_current_magnet_speed = base_magnet_speed
	_current_collection_distance = base_collection_distance

func apply_pickup_multiplier(multiplier: float) -> void:
	"""Called by external systems (like GameState) to apply multipliers"""
	_current_magnet_speed = base_magnet_speed * multiplier
	_current_collection_distance = base_collection_distance * multiplier


func _process(delta: float) -> void:
	if not _area_2d:
		return
	
	# Auto-fly to nearest player after delay
	var time_since_spawn = Time.get_ticks_msec() / 1000.0 - _spawn_time
	if not _is_being_collected and not _is_flying_to_player and time_since_spawn > _auto_fly_delay:
		_find_nearest_player()
	
	if not _is_being_collected and not _is_flying_to_player:
		return

	if not is_instance_valid(_target) or not _area_2d:
		return

	# Calculate direction from pickup to target
	var to_target = _target.global_position - _area_2d.global_position
	var direction = to_target.normalized()
	_area_2d.global_position += direction * _current_magnet_speed * delta

	if _area_2d.global_position.distance_to(_target.global_position) < _current_collection_distance:
		_collect()

func _find_nearest_player() -> void:
	"""Find the nearest player and start flying to them"""
	var players = get_tree().get_nodes_in_group(player_group_name) 
	if players.is_empty():
		return
	
	var nearest_player: Node2D = null
	var nearest_distance: float = INF
	
	for player in players:
		if player and player is Node2D:
			var distance = _area_2d.global_position.distance_to(player.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_player = player
	
	if nearest_player:
		_target = nearest_player
		_is_flying_to_player = true

func _on_body_entered(body: Node2D) -> void:
	# Only host/server processes pickups
	if not multiplayer.is_server():
		return
	
	if _can_pick_up(body):
		_target = body
		_collect()

func _on_area_entered(area: Area2D) -> void:
	# Only host/server processes pickups
	if not multiplayer.is_server():
		return
	
	var parent := area.get_parent()
	if parent and _can_pick_up(parent):
		_target = parent
		_collect()

func _can_pick_up(node: Node2D) -> bool:
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
	# Only host/server processes collection
	if not multiplayer.is_server():
		return
	
	# Prevent double-collection
	if _is_being_collected:
		return
	
	_is_being_collected = true
	collected.emit(_target)
	
	# Disable collision immediately to prevent further pickups
	if _area_2d:
		_area_2d.collision_layer = 0
		_area_2d.collision_mask = 0
	
	_play_pickup_sound()
	
	# Notify clients to play sound effect
	if multiplayer.get_peers().size() > 0:
		_play_pickup_sound_on_clients.rpc()

@rpc("authority", "call_remote")
func _play_pickup_sound_on_clients() -> void:
	"""Called on clients to play the pickup sound effect"""
	if _audio_player and pickup_sound:
		_audio_player.play()

func _play_pickup_sound() -> void:
	if not _area_2d or not _audio_player or not pickup_sound:
		if get_parent():
			get_parent().queue_free()
		return

	_audio_player.play()
	await _audio_player.finished

	if get_parent():
		get_parent().queue_free()
