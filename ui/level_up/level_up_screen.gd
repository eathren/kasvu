extends Control

## Level-up screen that shows item choices to players

signal item_chosen(item: TechItem)

@onready var level_label: Label = %LevelLabel
@onready var item_container: HBoxContainer = %ItemContainer
@onready var rarity_label: Label = %RarityLabel

var current_choices: Array[TechItem] = []
var player_id: int = 1
var item_button_scene: PackedScene = preload("res://ui/level_up/item_choice_button.tscn")

func _ready() -> void:
	hide()
	
	# Connect to GameState level up signal
	if GameState:
		GameState.level_up.connect(_on_level_up)

func _on_level_up(new_level: int) -> void:
	"""Show level-up screen for local player"""
	player_id = multiplayer.get_unique_id()
	show_choices(player_id, new_level)

func show_choices(p_id: int, level: int) -> void:
	"""Display item choices for a player"""
	player_id = p_id
	
	# Update labels
	level_label.text = "LEVEL %d" % level
	
	# Determine rarity for this level
	var rarity = TechManager.get_level_up_rarity(level)
	rarity_label.text = TechItem.new().get_rarity_name() if rarity < 0 else _get_rarity_name(rarity)
	rarity_label.modulate = _get_rarity_color(rarity)
	
	# Generate choices (all players get same rarity, different items)
	current_choices = TechManager.generate_item_choices(player_id, 4, rarity)
	
	# Clear existing buttons
	for child in item_container.get_children():
		child.queue_free()
	
	# Create item buttons
	for item in current_choices:
		var button = item_button_scene.instantiate()
		item_container.add_child(button)
		button.setup(item, TechManager.get_item_stack(player_id, item.id))
		button.pressed.connect(_on_item_chosen.bind(item))
	
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continue processing during slowdown

func _on_item_chosen(item: TechItem) -> void:
	"""Player chose an item"""
	# Add item to player
	TechManager.add_item_stack(player_id, item)
	
	# Resume time
	Engine.time_scale = 1.0
	
	# Emit signal and hide
	item_chosen.emit(item)
	hide()

func _get_rarity_name(rarity: TechItem.Rarity) -> String:
	match rarity:
		TechItem.Rarity.COMMON:
			return "COMMON"
		TechItem.Rarity.UNCOMMON:
			return "UNCOMMON"
		TechItem.Rarity.RARE:
			return "RARE"
		TechItem.Rarity.EPIC:
			return "EPIC"
		TechItem.Rarity.LEGENDARY:
			return "LEGENDARY"
		_:
			return "MIXED"

func _get_rarity_color(rarity: TechItem.Rarity) -> Color:
	match rarity:
		TechItem.Rarity.COMMON:
			return Color.WHITE
		TechItem.Rarity.UNCOMMON:
			return Color.LIME_GREEN
		TechItem.Rarity.RARE:
			return Color.CYAN
		TechItem.Rarity.EPIC:
			return Color.MAGENTA
		TechItem.Rarity.LEGENDARY:
			return Color.ORANGE
		_:
			return Color.WHITE
