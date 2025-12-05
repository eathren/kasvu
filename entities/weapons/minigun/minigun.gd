extends Node2D
class_name Minigun

## Minigun weapon - fires continuous stream with minimal spread

@export var bullet_scene: PackedScene = preload("res://entities/projectiles/bullet/bullet.tscn")
@export var spread_angle: float = 1.0  # degrees - very minimal
@export var bullet_speed: float = 500.0
@export var damage: float = 8.0
@export var fire_rate: float = 0.25  # seconds between shots 

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Marker2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var cooldown_timer: float = 0.0
var aim_direction: Vector2 = Vector2.UP
var is_firing: bool = false

func _ready() -> void:
	add_to_group("weapon")

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	# Continuous fire while aiming
	if is_firing and can_fire():
		_fire_bullet()

func can_fire() -> bool:
	return cooldown_timer <= 0.0

func _fire_bullet() -> void:
	"""Fire a single bullet"""
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# Minimal random spread
	var spread_offset := randf_range(-spread_angle / 2.0, spread_angle / 2.0)
	var fire_direction := aim_direction.rotated(deg_to_rad(spread_offset))
	
	# Position bullet at muzzle
	var spawn_pos := global_position
	if muzzle:
		spawn_pos = muzzle.global_position
	
	bullet.global_position = spawn_pos
	bullet.global_rotation = fire_direction.angle()
	
	# Set bullet properties
	if "base_damage" in bullet:
		bullet.base_damage = int(damage)
	if "speed" in bullet:
		bullet.speed = bullet_speed
	if "faction" in bullet:
		bullet.faction = 0  # Player factionas
	
	# Play firing sound
	if audio_player:
		audio_player.play()
	
	cooldown_timer = fire_rate

func fire(direction: Vector2, owner_faction: int = 0) -> void:
	"""Start firing"""
	aim_direction = direction.normalized()
	is_firing = true

func stop_firing() -> void:
	"""Stop firing"""
	is_firing = false

func update_aim(direction: Vector2) -> void:
	"""Update aim direction and rotate hands"""
	aim_direction = direction.normalized()
	
	# Rotate minigun hands to point in aim direction
	rotation = aim_direction.angle()
	
	# Flip sprite if aiming left
	if aim_direction.x < 0:
		sprite.flip_v = true
	else:
		sprite.flip_v = false
