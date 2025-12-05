extends Node
class_name TouchDamageComponent

## Component that handles touch damage for enemies
## Fixed: cleans up stale entries to prevent memory leak

@export var damage: int = 10
@export var damage_cooldown: float = 1.0  # Time between damage ticks
@export var cleanup_threshold: float = 10.0  # Remove entries older than this

var last_damage_time: Dictionary = {}  # target_id (int) -> timestamp
var scaled_damage: int = 0  # Set by parent's apply_level() if needed

func _ready() -> void:
	# Periodic cleanup of stale entries
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = cleanup_threshold
	cleanup_timer.timeout.connect(_cleanup_stale_entries)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

func get_damage() -> int:
	# Use scaled damage if set, otherwise base damage
	return scaled_damage if scaled_damage > 0 else damage

func set_scaled_damage(amount: int) -> void:
	"""Called by enemy when apply_level() bakes in stats"""
	scaled_damage = amount

func can_damage_target(target: Node) -> bool:
	"""Check if enough time has passed to damage this target again"""
	var target_id = target.get_instance_id()
	if not last_damage_time.has(target_id):
		return true
	
	var time_since_last = Time.get_ticks_msec() / 1000.0 - last_damage_time[target_id]
	return time_since_last >= damage_cooldown

func record_damage(target: Node) -> void:
	"""Record that we damaged this target"""
	var target_id = target.get_instance_id()
	last_damage_time[target_id] = Time.get_ticks_msec() / 1000.0

func _cleanup_stale_entries() -> void:
	"""Remove old entries to prevent memory leak"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	
	for target_id in last_damage_time.keys():
		var time_since_last = current_time - last_damage_time[target_id]
		if time_since_last > cleanup_threshold:
			to_remove.append(target_id)
	
	for target_id in to_remove:
		last_damage_time.erase(target_id)
