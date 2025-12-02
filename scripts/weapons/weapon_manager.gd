extends Node
class_name WeaponManager

## Manages all active weapons and modifiers for a ship

signal weapon_added(weapon_name: String)
signal weapon_leveled_up(weapon_name: String, new_level: int)
signal weapon_evolved(old_weapon: String, new_weapon: String)
signal modifier_added(modifier_name: String)
signal synergy_activated(synergy_name: String)

@export var max_weapons: int = 6
@export var owner_ship: Node2D

var active_weapons: Array[WeaponInstance] = []
var active_modifiers: Array[ModifierData] = []
var active_synergies: Array[SynergyData] = []

func _process(delta: float) -> void:
	# Only fire weapons if we have authority (this is the local player's ship)
	if owner_ship and not owner_ship.is_multiplayer_authority():
		return
	
	# Update all weapon cooldowns
	for weapon in active_weapons:
		weapon.update_cooldown(delta)
		
		# Auto-fire weapons that are ready
		if weapon.can_fire():
			_fire_weapon(weapon)

func add_weapon(weapon_data: WeaponData) -> bool:
	"""Add a new weapon or level up existing one"""
	if not weapon_data:
		return false
	
	# Check if we already have this weapon
	for weapon in active_weapons:
		if weapon.weapon_data == weapon_data:
			weapon.level_up()
			weapon.apply_modifiers(active_modifiers)
			weapon_leveled_up.emit(weapon_data.weapon_name, weapon.current_level)
			_check_synergies()
			return true
	
	# Add new weapon
	if active_weapons.size() >= max_weapons:
		return false
	
	var instance := WeaponInstance.new(weapon_data)
	instance.apply_modifiers(active_modifiers)
	active_weapons.append(instance)
	weapon_added.emit(weapon_data.weapon_name)
	_check_synergies()
	return true

func add_modifier(modifier_data: ModifierData) -> void:
	"""Add a passive modifier"""
	if not modifier_data:
		return
	
	active_modifiers.append(modifier_data)
	
	# Recalculate all weapon stats
	for weapon in active_weapons:
		weapon.apply_modifiers(active_modifiers)
	
	modifier_added.emit(modifier_data.modifier_name)
	_check_synergies()

func _fire_weapon(weapon: WeaponInstance) -> void:
	"""Fire a weapon instance"""
	if not weapon.weapon_data or not weapon.weapon_data.projectile_scene:
		return
	
	if not owner_ship or not is_instance_valid(owner_ship):
		return
	
	# Fire based on fire pattern
	match weapon.weapon_data.fire_pattern:
		WeaponData.FirePattern.FORWARD:
			_fire_forward(weapon)
		WeaponData.FirePattern.SPREAD:
			_fire_spread(weapon)
		WeaponData.FirePattern.SPIRAL:
			_fire_spiral(weapon)
		WeaponData.FirePattern.BURST:
			_fire_burst(weapon)
	
	weapon.fire()

func _fire_forward(weapon: WeaponInstance) -> void:
	"""Fire projectiles at nearest enemy"""
	# Find nearest enemy
	var target := _find_nearest_enemy()
	var direction := Vector2.ZERO
	
	if target and is_instance_valid(target):
		# Aim at enemy
		direction = owner_ship.global_position.direction_to(target.global_position)
	else:
		# No enemy, fire in facing direction
		direction = Vector2.UP.rotated(owner_ship.global_rotation)
	
	for i in range(weapon.current_projectile_count):
		var projectile := weapon.weapon_data.projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = owner_ship.global_position
		projectile.global_rotation = direction.angle()
		
		# Set projectile properties
		if "damage" in projectile:
			projectile.damage = weapon.current_damage
		if "speed" in projectile:
			projectile.speed = weapon.current_projectile_speed
		if "pierce" in projectile:
			projectile.pierce = weapon.current_pierce
		if "lifetime" in projectile:
			projectile.lifetime = weapon.current_range / weapon.current_projectile_speed
		if "faction" in projectile:
			projectile.faction = FactionComponent.Faction.PLAYER

func _find_nearest_enemy() -> Node2D:
	"""Find the nearest enemy to the ship"""
	if not owner_ship:
		return null
	
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var nearest_dist := INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var dist := owner_ship.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	
	return nearest

func _fire_spread(weapon: WeaponInstance) -> void:
	"""Fire projectiles in a spread pattern toward nearest enemy"""
	# Find nearest enemy for base direction
	var target := _find_nearest_enemy()
	var base_direction := Vector2.ZERO
	
	if target and is_instance_valid(target):
		base_direction = owner_ship.global_position.direction_to(target.global_position)
	else:
		base_direction = Vector2.UP.rotated(owner_ship.global_rotation)
	
	var count := weapon.current_projectile_count
	var spread := weapon.current_spread_angle
	
	for i in range(count):
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / (count - 1))
		
		var direction := base_direction.rotated(deg_to_rad(angle_offset))
		
		var projectile := weapon.weapon_data.projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = owner_ship.global_position
		projectile.global_rotation = direction.angle()
		
		if "damage" in projectile:
			projectile.damage = weapon.current_damage
		if "speed" in projectile:
			projectile.speed = weapon.current_projectile_speed
		if "pierce" in projectile:
			projectile.pierce = weapon.current_pierce
		if "lifetime" in projectile:
			projectile.lifetime = weapon.current_range / weapon.current_projectile_speed
		if "faction" in projectile:
			projectile.faction = FactionComponent.Faction.PLAYER

func _fire_spiral(weapon: WeaponInstance) -> void:
	"""Fire projectiles in a rotating spiral"""
	# TODO: Implement spiral pattern
	pass

func _fire_burst(weapon: WeaponInstance) -> void:
	"""Fire multiple projectiles simultaneously"""
	_fire_forward(weapon)

func _check_synergies() -> void:
	"""Check if any synergies should activate"""
	# TODO: Implement synergy checking
	pass

func get_weapon_names() -> Array[String]:
	var names: Array[String] = []
	for weapon in active_weapons:
		if weapon.weapon_data:
			names.append(weapon.weapon_data.weapon_name)
	return names

func get_modifier_names() -> Array[String]:
	var names: Array[String] = []
	for modifier in active_modifiers:
		if modifier:
			names.append(modifier.modifier_name)
	return names
