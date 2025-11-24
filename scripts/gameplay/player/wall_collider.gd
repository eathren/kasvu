# Eraser attached to the trawler
extends Area2D

@export var walls: TileMapLayer
@export var erase_radius_tiles: int = 2

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
			walls.erase_cell(cell)   # removes that 16×16 tile and its collider
