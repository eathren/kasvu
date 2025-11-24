extends Node2D

@onready var ground: TileMapLayer = $Ground
@onready var walls_root: Node2D = $Walls

const SOURCE_ID := 0
const TILE_ATLAS_COORDS := Vector2i(0, 0)

const HALF_WIDTH_CELLS := 50
const HALF_HEIGHT_CELLS := 50

const WALL_SEGMENT_SCENE := preload("res://scenes/core/wall_segment.tscn")
const HELL_PORTAL_SCENE := preload("res://scenes/core/hell_portal.tscn")
const IMP_SCENE := preload("res://scenes/gameplay/enemies/imp.tscn")
const LIEUTENANT_SCENE := preload("res://scenes/gameplay/enemies/lieutenant.tscn")

const WALL_BAND_HEIGHT := 5
const MAP_TOP_Y := -HALF_HEIGHT_CELLS
const HALF_WALL_WIDTH := HALF_WIDTH_CELLS

const NEIGHBORS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var hole_cells: Dictionary = {}
var cell_to_portal: Dictionary = {}

func _ready() -> void:
	fill_ground()
	create_wall()

func fill_ground() -> void:
	for x in range(-HALF_WIDTH_CELLS, HALF_WIDTH_CELLS + 1):
		for y in range(-HALF_HEIGHT_CELLS, HALF_HEIGHT_CELLS + 1):
			ground.set_cell(Vector2i(x, y), SOURCE_ID, TILE_ATLAS_COORDS)

func create_wall() -> void:
	for x in range(-HALF_WALL_WIDTH, HALF_WALL_WIDTH + 1):
		for offset_y in range(WALL_BAND_HEIGHT):
			var y := MAP_TOP_Y + offset_y
			var cell := Vector2i(x, y)
			create_wall_segment(cell)

func create_wall_segment(cell: Vector2i) -> void:
	var local_pos: Vector2 = ground.map_to_local(cell)
	var world_pos: Vector2 = ground.to_global(local_pos)

	var segment = WALL_SEGMENT_SCENE.instantiate()
	segment.setup(cell)
	segment.add_to_group("wall")
	segment.global_position = world_pos
	segment.destroyed.connect(_on_wall_segment_destroyed)
	walls_root.add_child(segment)

func _on_wall_segment_destroyed(cell: Vector2i) -> void:
	hole_cells[cell] = true
	_rebuild_portal_for_cluster(cell)

func _get_cluster(start: Vector2i) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {}

	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if visited.has(c):
			continue
		if not hole_cells.has(c):
			continue
		visited[c] = true
		cluster.append(c)
		for d in NEIGHBORS:
			queue.append(c + d)

	return cluster

func _choose_primary_cell(cluster: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cluster[0]
	for c in cluster:
		if c.y > best.y:
			best = c
		elif c.y == best.y and c.x < best.x:
			best = c
	return best

func _pick_spawn_profile(cluster: Array[Vector2i], primary_y: int) -> Dictionary:
	var size := cluster.size()
	var profile: Dictionary = {}

	if size <= 1:
		profile["scene"] = IMP_SCENE
		profile["interval"] = 4.0
		profile["max_alive"] = 5
	elif size == 2:
		profile["scene"] = LIEUTENANT_SCENE
		profile["interval"] = 7.0
		profile["max_alive"] = 2
	else:
		profile["scene"] = LIEUTENANT_SCENE
		profile["interval"] = 5.0
		profile["max_alive"] = 4

	var height_factor := MAP_TOP_Y + WALL_BAND_HEIGHT - 1 - primary_y
	if height_factor < 0:
		height_factor = 0
	if height_factor > 0:
		profile["interval"] = max(profile["interval"] * 0.75, 0.5)
		profile["max_alive"] = profile["max_alive"] + 1

	return profile

func _rebuild_portal_for_cluster(start: Vector2i) -> void:
	var cluster := _get_cluster(start)
	if cluster.is_empty():
		return

	var existing_portal: Node2D = null
	for c in cluster:
		if cell_to_portal.has(c):
			existing_portal = cell_to_portal[c]
			break

	if existing_portal == null:
		existing_portal = HELL_PORTAL_SCENE.instantiate()
		walls_root.add_child(existing_portal)

	var primary_cell := _choose_primary_cell(cluster)
	var profile := _pick_spawn_profile(cluster, primary_cell.y)

	var local_pos: Vector2 = ground.map_to_local(primary_cell)
	existing_portal.global_position = ground.to_global(local_pos)

	if existing_portal.has_method("set_spawn_profile"):
		existing_portal.set_spawn_profile(profile)

	for c in cluster:
		cell_to_portal[c] = existing_portal
