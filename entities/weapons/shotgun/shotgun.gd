extends Node2D
class_name Shotgun

## Shotgun weapon - fires 5 bullets in a spread pattern

@export var bullet_scene: PackedScene = preload("res://entities/projectiles/bullet/bullet.tscn")
@export var bullet_count: int = 5
@export var spread_angle: float = 30.0  # degrees
@export var bullet_speed: float = 400.0
@export var damage: float = 8.0
@export var fire_rate: float = 0.8  # seconds between shots

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var cooldown_timer: float = 0.0
var aim_direction: Vector2 = Vector2.UP

func _ready() -> void:
	add_to_group("weapon")

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

func can_fire() -> bool:
	return cooldown_timer <= 0.0

func fire(direction: Vector2, owner_faction: int = 0) -> void:
	if not can_fire():
		return
	
	aim_direction = direction.normalized()
	
	# Play gunshot sound
	if audio_player:
		audio_player.play()
	
	# Fire multiple bullets in a spread
	for i in range(bullet_count):
		var bullet := bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		
		# Calculate spread offset
		var angle_offset := 0.0
		if bullet_count > 1:
			angle_offset = lerp(-spread_angle / 2.0, spread_angle / 2.0, float(i) / (bullet_count - 1))
		
		var fire_direction := aim_direction.rotated(deg_to_rad(angle_offset))
		
		# Position bullet at muzzle
		var spawn_pos := global_position
		if muzzle:
			spawn_pos = muzzle.global_position
		
		bullet.global_position = spawn_pos
		bullet.global_rotation = fire_direction.angle()
		
		# Set bullet properties
		if "damage" in bullet:
			bullet.damage = damage
		if "speed" in bullet:
			bullet.speed = bullet_speed
		if "faction" in bullet:
			bullet.faction = owner_faction
	
	cooldown_timer = fire_rate

func update_aim(direction: Vector2) -> void:
	aim_direction = direction.normalized()
	
	# Rotate sprite to face aim direction
	rotation = aim_direction.angle()
	
	# Flip sprite vertically if aiming left
	if aim_direction.x < 0:
		sprite.flip_v = true
	else:
		sprite.flip_v = false
