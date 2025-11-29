extends Node
class_name PickupComponent

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

	_update_pickup_range()

func _update_pickup_range() -> void:
	var multiplier: float = 1.0
	if GameState and GameState.has_method("get_pickup_range_multiplier"):
		multiplier = GameState.get_pickup_range_multiplier()

	_current_magnet_speed = base_magnet_speed * multiplier
	_current_collection_distance = base_collection_distance * multiplier


func _physics_process(delta: float) -> void:
	if not _is_being_collected or not is_instance_valid(_target) or not _area_2d:
		return

	var direction := _area_2d.global_position.direction_to(_target.global_position)
	_area_2d.global_position += direction * _current_magnet_speed * delta

	if _area_2d.global_position.distance_to(_target.global_position) < _current_collection_distance:
		_collect()

func _on_body_entered(body: Node2D) -> void:
	if _can_pick_up(body):
		_target = body
		_is_being_collected = true

func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent and _can_pick_up(parent):
		_target = parent
		_is_being_collected = true

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
	collected.emit(_target)
	_play_pickup_sound()

func _play_pickup_sound() -> void:
	if not _area_2d or not _audio_player or not pickup_sound:
		if _area_2d:
			_area_2d.queue_free()
		return

	# hide and disable collision now
	_area_2d.hide()
	_area_2d.collision_layer = 0
	_area_2d.collision_mask = 0
	_is_being_collected = false

	_audio_player.play()
	await _audio_player.finished

	if is_instance_valid(_area_2d):
		_area_2d.queue_free()
