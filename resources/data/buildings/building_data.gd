extends Resource
class_name BuildingData

@export var name: String
@export var scene: PackedScene
@export var cost: int = 100
@export var footprint_size: Vector2i = Vector2i.ONE       # in tiles
@export var requires_tech: Array[StringName] = []         # ["tower_tech_1"]
@export var can_place_on: Array[int] = []                 # tile IDs or terrain types
