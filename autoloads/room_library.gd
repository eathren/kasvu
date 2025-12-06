extends Node

## Room Library - indexes all room templates by door mask
## Autoload this as "RoomLibrary"

var rooms_by_mask: Dictionary = {}  # int (door_mask) -> Array[PackedScene]
var rooms_by_type: Dictionary = {}  # String (room_type) -> Array[PackedScene]

func _ready() -> void:
	_register_rooms()

func _register_rooms() -> void:
	## Register all your room template scenes here
	## Add more as you create them
	pass


func _register(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Room template not found: %s" % path)
		return
	
	var scene: PackedScene = load(path)
	var inst: RoomTemplate = scene.instantiate()
	
	if not inst:
		push_error("Failed to instantiate room template: %s" % path)
		return
	
	var mask = inst.door_mask
	var type = inst.room_type
	
	# Index by door mask
	if not rooms_by_mask.has(mask):
		rooms_by_mask[mask] = []
	rooms_by_mask[mask].append(scene)
	
	# Index by room type
	if not rooms_by_type.has(type):
		rooms_by_type[type] = []
	rooms_by_type[type].append(scene)
	
	inst.queue_free()

## Get a random room template with the specified door mask
func get_random_by_mask(mask: int) -> PackedScene:
	var list: Array = rooms_by_mask.get(mask, [])
	if list.is_empty():
		push_error("No room template found with door mask: %d" % mask)
		return null
	return list.pick_random()

## Get a random room template of the specified type
func get_random_by_type(type: String) -> PackedScene:
	var list: Array = rooms_by_type.get(type, [])
	if list.is_empty():
		push_error("No room template found with type: %s" % type)
		return null
	return list.pick_random()

## Get a random room template matching both mask and type
func get_random(mask: int, type: String = "") -> PackedScene:
	if type.is_empty():
		return get_random_by_mask(mask)
	
	# Filter by both mask and type
	var mask_rooms: Array = rooms_by_mask.get(mask, [])
	var matching: Array[PackedScene] = []
	
	for scene in mask_rooms:
		var inst: RoomTemplate = scene.instantiate()
		if inst.room_type == type:
			matching.append(scene)
		inst.queue_free()
	
	if matching.is_empty():
		push_error("No room found with mask %d and type %s" % [mask, type])
		return null
	
	return matching.pick_random()
