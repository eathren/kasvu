# Eraser attached to the trawler
extends Area2D

@export var erase_radius_tiles: int = 7

var walls: TileMapLayer

func _ready() -> void:
	# Wait a frame to ensure wall is initialized and added to group
	await get_tree().process_frame
	# Find the wall TileMapLayer from the group
	walls = get_tree().get_first_node_in_group("wall") as TileMapLayer
	if walls == null:
		push_error("WallCollider: No wall TileMapLayer found in group 'wall'")

func _physics_process(delta: float) -> void:
	if walls == null:
		return

	var local: Vector2 = walls.to_local(global_position)
	var center_cell: Vector2i = walls.local_to_map(local)

	var r: int = erase_radius_tiles
	var r_sq: int = r * r

	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var off := Vector2i(x, y)
			if off.x * off.x + off.y * off.y > r_sq:
				continue
			var cell := center_cell + off
			
			# Only erase if there's actually a tile there
			if walls.get_cell_source_id(cell) != -1:
				walls.erase_cell(cell)   # removes that 16×16 tile and its collider
