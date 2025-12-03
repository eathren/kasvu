extends Resource
class_name TechItem

## Represents a tech/item that can be picked during level-ups

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum Category {
	OFFENSE,
	DEFENSE,
	UTILITY,
	SUPPORT
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var stack_description: String = ""
@export var icon: Texture2D = null
@export var rarity: Rarity = Rarity.COMMON
@export var category: Category = Category.OFFENSE
@export var max_stacks: int = 10  # -1 for unlimited

## Returns the full description based on stack count
func get_description(stack_count: int = 1) -> String:
	if stack_count <= 1:
		return description
	else:
		return description + "\n\n[Stack x%d] %s" % [stack_count, stack_description]

## Get color based on rarity
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color.LIME_GREEN
		Rarity.RARE:
			return Color.CYAN
		Rarity.EPIC:
			return Color.MAGENTA
		Rarity.LEGENDARY:
			return Color.ORANGE
		_:
			return Color.WHITE

## Get rarity name
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"
