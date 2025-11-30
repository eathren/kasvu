extends Resource
class_name WeaponData

## Defines a weapon type with base stats

enum WeaponType {
	BULLET,      # Standard projectile
	LASER,       # Continuous beam
	SAWBLADE,    # Spinning projectile
	MISSILE,     # Homing projectile
	WAVE,        # Piercing wave
	ORBIT,       # Orbiting protection
}

enum FirePattern {
	FORWARD,     # Straight ahead
	SPREAD,      # Multiple directions
	SPIRAL,      # Rotating pattern
	BURST,       # Multiple shots at once
	STREAM,      # Continuous fire
	ORBIT,       # Circles the ship
}

@export var weapon_name: String = "Basic Gun"
@export var weapon_type: WeaponType = WeaponType.BULLET
@export var fire_pattern: FirePattern = FirePattern.FORWARD

# Base stats (level 1)
@export var base_damage: float = 10.0
@export var base_fire_rate: float = 1.0  # Shots per second
@export var base_projectile_count: int = 1
@export var base_projectile_speed: float = 400.0
@export var base_pierce: int = 0  # How many enemies it can pierce
@export var base_range: float = 500.0
@export var base_spread_angle: float = 0.0  # In degrees

# Per-level scaling
@export var damage_per_level: float = 5.0
@export var fire_rate_per_level: float = 0.1
@export var projectile_count_per_level: int = 0  # Add 1 projectile every N levels

# Visuals
@export var projectile_scene: PackedScene
@export var projectile_color: Color = Color.WHITE
@export var projectile_scale: float = 1.0

# Special properties
@export var can_crit: bool = true
@export var can_pierce: bool = false
@export var can_chain: bool = false
@export var can_explode: bool = false

# Evolution (upgrade path)
@export var max_level: int = 7
@export var evolution_weapon: WeaponData = null  # What this evolves into at max level
@export var evolution_requirements: Array[String] = []  # Required items for evolution
