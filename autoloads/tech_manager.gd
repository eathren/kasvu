extends Node

## Manages tech items and their stacks for each player

signal item_acquired(player_id: int, item: TechItem, stack_count: int)

var unlocked := {}

# Player item stacks: player_id -> { item_id -> stack_count }
var player_items: Dictionary = {}

# Item pool - preload all items
var item_pool: Array[TechItem] = []

func _ready() -> void:
	_load_item_pool()

func _load_item_pool() -> void:
	"""Load all tech items from resources"""
	item_pool.clear()
	
	# Load items
	var neon_halo = load("res://resources/data/items/neon_halo_cartridge.tres") as TechItem
	var gilded_barrel = load("res://resources/data/items/gilded_barrel_shroud.tres") as TechItem
	var saintbreaker = load("res://resources/data/items/saintbreaker_rounds.tres") as TechItem
	
	if neon_halo:
		item_pool.append(neon_halo)
	if gilded_barrel:
		item_pool.append(gilded_barrel)
	if saintbreaker:
		item_pool.append(saintbreaker)
	
	print("TechManager: Loaded %d items" % item_pool.size())

func has_tech(t: StringName) -> bool:
	return unlocked.get(t, false)
	
func unlock(t: StringName) -> void:
	unlocked[t] = true

## Get player's item stack count
func get_item_stack(player_id: int, item_id: String) -> int:
	if not player_items.has(player_id):
		return 0
	return player_items[player_id].get(item_id, 0)

## Add item stack for player
func add_item_stack(player_id: int, item: TechItem) -> int:
	if not player_items.has(player_id):
		player_items[player_id] = {}
	
	var current_stack = player_items[player_id].get(item.id, 0)
	
	# Check max stacks
	if item.max_stacks > 0 and current_stack >= item.max_stacks:
		print("TechManager: Player %d already has max stacks of %s" % [player_id, item.display_name])
		return current_stack
	
	current_stack += 1
	player_items[player_id][item.id] = current_stack
	
	item_acquired.emit(player_id, item, current_stack)
	print("TechManager: Player %d acquired %s (stack %d)" % [player_id, item.display_name, current_stack])
	
	return current_stack

## Get all items for a player
func get_player_items(player_id: int) -> Dictionary:
	return player_items.get(player_id, {})

## Generate item choices for level up (can include duplicates)
func generate_item_choices(player_id: int, count: int = 4, force_rarity: TechItem.Rarity = -1) -> Array[TechItem]:
	var choices: Array[TechItem] = []
	var available_items = item_pool.duplicate()
	
	# Filter by rarity if specified
	if force_rarity >= 0:
		available_items = available_items.filter(func(item): return item.rarity == force_rarity)
	
	# Remove items at max stacks
	available_items = available_items.filter(func(item):
		var stack = get_item_stack(player_id, item.id)
		return item.max_stacks < 0 or stack < item.max_stacks
	)
	
	# If no items available, return empty
	if available_items.is_empty():
		return choices
	
	# Randomly select items (WITH replacement - items can appear multiple times)
	for i in range(count):
		var random_item = available_items[randi() % available_items.size()]
		choices.append(random_item)
	
	return choices

## Determine rarity for level up based on level
func get_level_up_rarity(level: int) -> TechItem.Rarity:
	# Simple rarity scaling
	var roll = randf()
	
	if level < 5:
		# Early game: mostly common
		if roll < 0.7:
			return TechItem.Rarity.COMMON
		else:
			return TechItem.Rarity.UNCOMMON
	elif level < 10:
		# Mid game: mix of common and uncommon
		if roll < 0.4:
			return TechItem.Rarity.COMMON
		elif roll < 0.85:
			return TechItem.Rarity.UNCOMMON
		else:
			return TechItem.Rarity.RARE
	else:
		# Late game: higher rarities
		if roll < 0.2:
			return TechItem.Rarity.COMMON
		elif roll < 0.5:
			return TechItem.Rarity.UNCOMMON
		elif roll < 0.8:
			return TechItem.Rarity.RARE
		elif roll < 0.95:
			return TechItem.Rarity.EPIC
		else:
			return TechItem.Rarity.LEGENDARY
	
	return TechItem.Rarity.COMMON

## Reset player items (for new run)
func reset_player_items(player_id: int = -1) -> void:
	if player_id >= 0:
		player_items.erase(player_id)
	else:
		player_items.clear()
	print("TechManager: Reset items for player %d" % player_id)
