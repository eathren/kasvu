extends Node
class_name WeaponComponent

## Manages weapons and upgrades for player ships
## Reads weapon data from GameState for consistent upgrades across all ships

signal weapon_fired(weapon_type: String)
signal weapon_upgraded(weapon_type: String, level: int)

@export var weapon_data: WeaponData = preload("res://resources/data/weapons/basic_bullet.tres")
@export var muzzle_paths: PackedStringArray = []

var _fire_timer: float = 0.0
var _current_target: Node2D = null
var _muzzle_nodes: Array[Node2D] = []
var _level_root: Node = null
var _owner_body: Node2D = null
var _player_id: int = -1  # Set by player/ship

# Weapon types available
enum WeaponType {
	LASER,
	BULLET,
	MISSILE,
	BEAM
}

var active_weapons: Array[int] = [WeaponType.LASER]  # Start with laser (stored as int for GameState compatibility)

func _ready() -> void:
	_owner_body = get_parent() as Node2D
	_level_root = get_tree().root.get_node_or_null("Main/CurrentLevel")
	_cache_muzzles()
	# Load weapon configuration from GameState
	_load_weapon_state()

func _process(delta: float) -> void:
	_fire_timer += delta

func _load_weapon_state() -> void:
	"""Load current weapon upgrades from GameState"""
	if not GameState or not weapon_data:
		return
	
	# Get weapon unlocks from GameState
	if GameState.has_method("get_unlocked_weapons"):
		active_weapons = GameState.get_unlocked_weapons()

func can_fire() -> bool:
	"""Check if enough time has passed to fire again"""
	if not weapon_data:
		return false
	
	var fire_rate = weapon_data.fire_rate
	# Apply fire rate multiplier from GameState
	if GameState and GameState.has_method("get_fire_rate_multiplier"):
		var multiplier: float = GameState.get_fire_rate_multiplier()
		fire_rate = fire_rate / multiplier  # Higher multiplier = faster fire rate
	
	return _fire_timer >= fire_rate

func fire_at_target(target: Node2D, origin: Node2D) -> void:
	"""Fire weapons at a target"""
	if not can_fire():
		return
	
	_fire_timer = 0.0
	_current_target = target
	
	# Fire each active weapon type
	for weapon_type in active_weapons:
		_fire_weapon(weapon_type, target, origin)

func fire_in_direction(origin: Node2D, direction: Vector2 = Vector2.ZERO) -> void:
	"""Fire weapons in a specific direction (or forward if zero)"""
	if not can_fire():
		return
	
	_fire_timer = 0.0
	
	# Use ship's forward direction if no direction specified
	var fire_dir := direction
	if fire_dir == Vector2.ZERO and origin:
		fire_dir = Vector2.UP.rotated(origin.global_rotation)
	
	# Fire bullets in that direction
	_fire_bullet_in_direction(origin, fire_dir)

func _fire_weapon(weapon_type: int, target: Node2D, origin: Node2D) -> void:
	"""Fire a specific weapon type"""
	match weapon_type:
		WeaponType.LASER:
			_fire_laser(target, origin)
		WeaponType.BULLET:
			_fire_bullet(target, origin)
		#WeaponType.MISSILE:
			#_fire_missile(target, origin)
		#WeaponType.BEAM:
			#_fire_beam(target, origin)
	
	weapon_fired.emit(str(weapon_type))

func _fire_laser(target: Node2D, origin: Node2D) -> void:
	"""Laser is handled by Laser nodes on the ship"""
	pass  # Lasers are always-on beams, handled separately

func _fire_bullet(target: Node2D, origin: Node2D) -> void:
	"""Fire a bullet projectile"""
	if not weapon_data or not weapon_data.projectile_scene or not is_instance_valid(target):
		return
	
	var spawn_nodes := _muzzle_nodes
	if spawn_nodes.is_empty():
		spawn_nodes = [origin]
	
	for muzzle in spawn_nodes:
		if muzzle == null:
			continue
		
		var bullet := weapon_data.projectile_scene.instantiate()
		if bullet == null:
			continue
		
		var parent := _level_root if _level_root else get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		
		parent.add_child(bullet)
		
		# Apply weapon data properties
		var bullet_speed = weapon_data.projectile_speed
		var bullet_base_damage := weapon_data.base_damage
		var bullet_variance := weapon_data.damage_variance
		var bullet_pierce := weapon_data.base_pierce
		
		# Apply player item modifiers
		var damage_mod := get_player_modifier("damage")
		var crit_mod := get_player_modifier("crit_chance")
		var pierce_mod := get_player_modifier("pierce")
		var elite_damage_mod := get_player_modifier("elite_damage")
		
		# Apply damage modifiers (additive from items + multiplicative from GameState)
		bullet_base_damage *= (1.0 + damage_mod)
		if GameState and GameState.has_method("get_weapon_damage_multiplier"):
			bullet_base_damage *= GameState.get_weapon_damage_multiplier()
		
		# Apply pierce modifier
		bullet_pierce += int(pierce_mod)
		
		if "speed" in bullet:
			bullet.speed = bullet_speed
		if "base_damage" in bullet:
			bullet.base_damage = int(bullet_base_damage)
		if "damage_variance" in bullet:
			bullet.damage_variance = bullet_variance
		if "pierce" in bullet:
			bullet.pierce = bullet_pierce
		
		# Apply crit chances from GameState + player items
		if "crit_chance" in bullet:
			var base_crit = GameState.get_crit_chance() if GameState else 0.0
			bullet.crit_chance = base_crit + crit_mod
		if "megacrit_chance" in bullet and GameState:
			bullet.megacrit_chance = GameState.get_megacrit_chance()
		if "elite_damage_bonus" in bullet:
			bullet.elite_damage_bonus = elite_damage_mod
		
		# Set position & rotation
		var spawn_pos := muzzle.global_position
		bullet.global_position = spawn_pos
		
		var dir := spawn_pos.direction_to(target.global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var spread := deg_to_rad(randf_range(-weapon_data.spread_angle, weapon_data.spread_angle))
		var final_angle := dir.angle() + spread
		bullet.global_rotation = final_angle
		
		# Assign faction if available
		if "faction" in bullet and _owner_body and _owner_body.has_method("get_node_or_null"):
			var faction_component := _owner_body.get_node_or_null("FactionComponent")
			if faction_component:
				bullet.faction = faction_component.faction
		
		# Set shooter ID for kill credit
		if "shooter_id" in bullet:
			bullet.shooter_id = _player_id
#
#func _fire_missile(target: Node2D, origin: Node2D) -> void:
	#"""Fire a homing missile"""
	## TODO: Implement missile spawning when missile scene exists
	#pass
#
#func _fire_beam(target: Node2D, origin: Node2D) -> void:
	#"""Fire a continuous beam weapon"""
	## TODO: Implement beam weapon
	#pass

func get_weapon_damage() -> float:
	"""Get total weapon damage from GameState"""
	var base_damage = weapon_data.damage if weapon_data else 10.0
	if GameState and GameState.has_method("get_weapon_damage_multiplier"):
		return base_damage * GameState.get_weapon_damage_multiplier()
	return base_damage

func upgrade_weapon(weapon_type: int) -> void:
	"""Called when a weapon is upgraded"""
	_load_weapon_state()  # Reload from GameState
	weapon_upgraded.emit(str(weapon_type), 1)

func _cache_muzzles() -> void:
	"""Resolve muzzle node paths"""
	_muzzle_nodes.clear()
	for path in muzzle_paths:
		var node := get_node_or_null(path)
		if node and node is Node2D:
			_muzzle_nodes.append(node)

func set_player_id(player_id: int) -> void:
	"""Set the player ID for this weapon to read their modifiers"""
	_player_id = player_id

func get_player_modifier(modifier_name: String) -> float:
	"""Get modifier value from player's items"""
	if _player_id < 0 or not TechManager:
		return 0.0
	return TechManager.get_player_modifier(_player_id, modifier_name)

func _fire_bullet_in_direction(origin: Node2D, direction: Vector2) -> void:
	"""Fire a bullet in a specific direction"""
	if not weapon_data or not weapon_data.projectile_scene or not is_instance_valid(origin):
		return
	
	var spawn_nodes := _muzzle_nodes
	if spawn_nodes.is_empty():
		spawn_nodes = [origin]
	
	for muzzle in spawn_nodes:
		if muzzle == null:
			continue
		
		var bullet := weapon_data.projectile_scene.instantiate()
		if bullet == null:
			continue
		
		var parent := _level_root if _level_root else get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		
		parent.add_child(bullet)
		
		# Apply weapon data properties
		var bullet_speed = weapon_data.projectile_speed
		var bullet_base_damage = weapon_data.base_damage
		var bullet_variance = weapon_data.damage_variance
		var bullet_pierce = weapon_data.base_pierce
		
		# Apply player item modifiers
		var damage_mod := get_player_modifier("damage")
		var crit_mod := get_player_modifier("crit_chance")
		var pierce_mod := get_player_modifier("pierce")
		var elite_damage_mod := get_player_modifier("elite_damage")
		
		# Apply damage modifiers (additive from items + multiplicative from GameState)
		bullet_base_damage *= (1.0 + damage_mod)
		if GameState and GameState.has_method("get_weapon_damage_multiplier"):
			bullet_base_damage *= GameState.get_weapon_damage_multiplier()
		
		# Apply pierce modifier
		bullet_pierce += int(pierce_mod)
		
		if "speed" in bullet:
			bullet.speed = bullet_speed
		if "base_damage" in bullet:
			bullet.base_damage = int(bullet_base_damage)
		if "damage_variance" in bullet:
			bullet.damage_variance = bullet_variance
		if "pierce" in bullet:
			bullet.pierce = bullet_pierce
		
		# Apply crit chances from GameState + player items
		if "crit_chance" in bullet:
			var base_crit = GameState.get_crit_chance() if GameState else 0.0
			bullet.crit_chance = base_crit + crit_mod
		if "megacrit_chance" in bullet and GameState:
			bullet.megacrit_chance = GameState.get_megacrit_chance()
		if "elite_damage_bonus" in bullet:
			bullet.elite_damage_bonus = elite_damage_mod
		
		# Set position & rotation
		var spawn_pos := muzzle.global_position
		bullet.global_position = spawn_pos
		
		# Apply spread to the direction
		var spread := deg_to_rad(randf_range(-weapon_data.spread_angle, weapon_data.spread_angle))
		var final_angle := direction.angle() + spread
		bullet.global_rotation = final_angle
		
		# Assign faction if available
		if "faction" in bullet and _owner_body and _owner_body.has_method("get_node_or_null"):
			var faction_component := _owner_body.get_node_or_null("FactionComponent")
			if faction_component:
				bullet.faction = faction_component.faction
		
		# Set shooter ID for kill credit
		if "shooter_id" in bullet:
			bullet.shooter_id = _player_id
