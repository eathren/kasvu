extends Node2D
class_name RoomTemplate

## WFC Template - Paint small tile patterns for Wave Function Collapse generation
## The SampleMap is used to train WFC models for procedural generation

@export_enum("shaft", "room", "side_tunnel", "temple", "big_chamber", "corrupted", "ore_vein", "treasure_vault", "boss_arena", "nest") var template_type: String = "room"
@export var sample_size: Vector2i = Vector2i(12, 12)  ## Recommended size for sample pattern

@onready var sample_map: TileMapLayer = $SampleMap

func _ready() -> void:
	add_to_group("wfc_template")
	print("WFC Template '%s' loaded - Paint a %dx%d pattern in SampleMap" % [template_type, sample_size.x, sample_size.y])

## Get the painted sample for WFC learning
func get_sample_map() -> TileMapLayer:
	return sample_map

## Get all painted cells
func get_sample_cells() -> Array:
	if sample_map:
		return sample_map.get_used_cells()
	return []

## Check if template has been painted
func is_painted() -> bool:
	return sample_map and not sample_map.get_used_cells().is_empty()
