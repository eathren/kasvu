extends RefCounted
class_name SegmentedMineGenerator

## Step 1: Segmentation-based mine generation
## Macro layout -> WFC per segment -> Content placement

# Segment configuration
const SEGMENT_SIZE := 32  # tiles per segment (will be filled from smaller samples)
const SEG_W := 7  # segments wide (224 tiles)
const SEG_H := 20  # segments tall (640 tiles)

# Note: Sample tilemaps should be small (10x10 to 16x16)
# WFC will repeat and vary patterns to fill the full 32x32 segment

enum SegmentType {
	SOLID,
	SHAFT,
	ROOM,
	SIDE_TUNNEL,
	TEMPLE,
	BIG_CHAMBER,
	CORRUPTED,
	ORE
}

# Segmentation data
var segments: Array = []  # 2D array [y][x] of SegmentType
var segment_graph: Dictionary = {}  # segment_pos -> [neighbor_positions]
var reserved_doors: Dictionary = {}  # Vector2i -> true (door positions)

# Layout result
var layout_map: Dictionary = {}  # Vector2i -> tile_id (floor, wall, ore, lava)
var tile_size: float = 16.0

# RNG
var rng: RandomNumberGenerator

func _init():
	rng = RandomNumberGenerator.new()

## Main generation entry point
func generate(world_seed: int) -> Dictionary:
	rng.seed = world_seed
	
	print("[SegGen] === Step 1: Segmentation ===")
	_create_macro_layout()
	
	print("[SegGen] === Step 2: Build connectivity graph ===")
	_build_segment_graph()
	
	print("[SegGen] === Step 3: Reserve door positions ===")
	_reserve_doors()
	
	print("[SegGen] === Step 4: Fill segments with WFC ===")
	_fill_all_segments()
	
	print("[SegGen] === Generation complete ===")
	
	return {
		"layout_map": layout_map,
		"segments": segments,
		"reserved_doors": reserved_doors,
		"bounds": Vector2i(SEG_W * SEGMENT_SIZE, SEG_H * SEGMENT_SIZE)
	}

## Step 1: Create macro layout of segment types
func _create_macro_layout() -> void:
	# Initialize grid to SOLID
	segments = []
	for y in range(SEG_H):
		var row = []
		for x in range(SEG_W):
			row.append(SegmentType.SOLID)
		segments.append(row)
	
	# Random walk for main shaft
	_generate_main_shaft()
	
	# Spawn side branches from shaft segments
	_generate_side_branches()
	
	# Overlay blobby zones on remaining SOLID areas
	_scatter_blobby_zones(SegmentType.ORE, 4, 12)
	_scatter_blobby_zones(SegmentType.CORRUPTED, 3, 10)
	_scatter_blobby_zones(SegmentType.TEMPLE, 2, 6)
	
	# Log segment counts
	var counts = {}
	for seg_y in range(SEG_H):
		for seg_x in range(SEG_W):
			var type = segments[seg_y][seg_x]
			counts[type] = counts.get(type, 0) + 1
	
	print("[SegGen] Segment layout: ", counts)

func _generate_main_shaft() -> void:
	"""Random walk shaft that wiggles left/right as it descends"""
	var x := SEG_W / 2
	var y := 0
	
	# Top 2 as spawn / lobby
	segments[y][x] = SegmentType.ROOM
	if y + 1 < SEG_H:
		segments[y + 1][x] = SegmentType.ROOM
		y += 2
	
	while y < SEG_H:
		segments[y][x] = SegmentType.SHAFT
		
		# Occasionally widen into ROOM or BIG_CHAMBER
		var roll := rng.randf()
		if roll < 0.15:
			segments[y][x] = SegmentType.ROOM
		elif roll < 0.25:
			segments[y][x] = SegmentType.BIG_CHAMBER
		
		# Small horizontal wiggle
		if rng.randf() < 0.35:
			var dx := -1 if rng.randf() < 0.5 else 1
			var nx = clamp(x + dx, 1, SEG_W - 2)
			if segments[y][nx] == SegmentType.SOLID:
				x = nx
				segments[y][x] = SegmentType.SHAFT
		
		y += 1

func _generate_side_branches() -> void:
	"""Spawn branching tunnels from random shaft segments"""
	for y in range(3, SEG_H):
		# Only branch from shaft/room segments occasionally
		var center_x := SEG_W / 2
		for x in range(SEG_W):
			var seg_type = segments[y][x]
			if seg_type in [SegmentType.SHAFT, SegmentType.ROOM, SegmentType.BIG_CHAMBER]:
				if rng.randf() < 0.15:  # 15% chance per eligible segment
					_spawn_side_branch(Vector2i(x, y))

func _spawn_side_branch(start_seg: Vector2i) -> void:
	"""Random walk a side tunnel from start_seg"""
	var steps := rng.randi_range(3, 7)
	var pos := start_seg
	var dir := Vector2i(-1, 0) if rng.randf() < 0.5 else Vector2i(1, 0)
	
	for i in range(steps):
		var next := pos + dir
		if next.x < 0 or next.x >= SEG_W:
			break
		if next.y < 0 or next.y >= SEG_H:
			break
		
		if segments[next.y][next.x] == SegmentType.SOLID:
			segments[next.y][next.x] = SegmentType.SIDE_TUNNEL
		pos = next
		
		# Small vertical variation so tunnels sag or rise
		if rng.randf() < 0.3:
			var vy := -1 if rng.randf() < 0.5 else 1
			var ny = clamp(pos.y + vy, 1, SEG_H - 2)
			if segments[ny][pos.x] == SegmentType.SOLID:
				pos.y = ny
				segments[pos.y][pos.x] = SegmentType.SIDE_TUNNEL
	
	# End room
	var end_type_roll := rng.randf()
	if end_type_roll < 0.2:
		segments[pos.y][pos.x] = SegmentType.TEMPLE
	elif end_type_roll < 0.5:
		segments[pos.y][pos.x] = SegmentType.BIG_CHAMBER
	else:
		segments[pos.y][pos.x] = SegmentType.ROOM

func _scatter_blobby_zones(kind: SegmentType, attempts: int, max_radius: int) -> void:
	"""Grow blobby zones from seeds instead of placing single segments"""
	for i in range(attempts):
		var sx := rng.randi_range(0, SEG_W - 1)
		var sy := rng.randi_range(3, SEG_H - 1)
		if segments[sy][sx] != SegmentType.SOLID:
			continue
		
		var frontier: Array = [Vector2i(sx, sy)]
		var visited: Dictionary = {}
		var steps := 0
		
		while not frontier.is_empty() and steps < max_radius:
			steps += 1
			var current: Vector2i = frontier.pop_back()
			if visited.has(current):
				continue
			visited[current] = true
			
			if segments[current.y][current.x] == SegmentType.SOLID:
				segments[current.y][current.x] = kind
			
			# Chance to keep growing from this cell
			if rng.randf() > 0.65:
				continue
			
			var neighbors := [
				current + Vector2i(1, 0),
				current + Vector2i(-1, 0),
				current + Vector2i(0, 1),
				current + Vector2i(0, -1),
			]
			for n in neighbors:
				if n.x < 0 or n.x >= SEG_W:
					continue
				if n.y < 0 or n.y >= SEG_H:
					continue
				if segments[n.y][n.x] != SegmentType.SOLID:
					continue
				frontier.append(n)

## Step 2: Build connectivity graph between segments
func _build_segment_graph() -> void:
	segment_graph.clear()
	
	for y in range(SEG_H):
		for x in range(SEG_W):
			var seg_type = segments[y][x]
			if seg_type == SegmentType.SOLID:
				continue
			
			var pos = Vector2i(x, y)
			segment_graph[pos] = []
			
			# Check 4 neighbors
			var neighbors = [
				Vector2i(x, y - 1),  # N
				Vector2i(x + 1, y),  # E
				Vector2i(x, y + 1),  # S
				Vector2i(x - 1, y)   # W
			]
			
			for neighbor_pos in neighbors:
				if neighbor_pos.x < 0 or neighbor_pos.x >= SEG_W:
					continue
				if neighbor_pos.y < 0 or neighbor_pos.y >= SEG_H:
					continue
				
				var neighbor_type = segments[neighbor_pos.y][neighbor_pos.x]
				
				# Connect non-SOLID segments
				if neighbor_type != SegmentType.SOLID:
					segment_graph[pos].append(neighbor_pos)
	
	print("[SegGen] Graph built with %d nodes" % segment_graph.size())

## Step 3: Reserve door positions at segment boundaries (initial geometric placement)
func _reserve_doors() -> void:
	reserved_doors.clear()
	
	for seg_pos in segment_graph:
		var neighbors = segment_graph[seg_pos]
		
		for neighbor_pos in neighbors:
			# Only process each pair once
			if neighbor_pos < seg_pos:
				continue
			
			# Place temporary geometric doors (will be refined after WFC)
			_place_door_between(seg_pos, neighbor_pos)
	
	print("[SegGen] Reserved %d initial door positions" % reserved_doors.size())

func _place_door_between(seg_a: Vector2i, seg_b: Vector2i) -> void:
	"""Place door(s) at the border between two segments (geometric fallback)"""
	var origin_a = seg_a * SEGMENT_SIZE
	var origin_b = seg_b * SEGMENT_SIZE
	
	# Determine border orientation
	if seg_a.x == seg_b.x:  # Vertical border (N/S neighbors)
		var x_center = origin_a.x + SEGMENT_SIZE / 2
		var door_width = 3
		
		# Door at boundary
		var border_y = max(origin_a.y, origin_b.y)
		
		for dx in range(-door_width / 2, door_width / 2 + 1):
			var door_pos = Vector2i(x_center + dx, border_y)
			reserved_doors[door_pos] = true
	
	else:  # Horizontal border (E/W neighbors)
		var y_center = origin_a.y + SEGMENT_SIZE / 2
		var door_width = 3
		
		# Door at boundary
		var border_x = max(origin_a.x, origin_b.x)
		
		for dy in range(-door_width / 2, door_width / 2 + 1):
			var door_pos = Vector2i(border_x, y_center + dy)
			reserved_doors[door_pos] = true

## Step 3b: Rebuild doors based on actual floor layout
func _rebuild_doors_from_layout() -> void:
	"""Replace geometric doors with ones that align with actual floor positions"""
	reserved_doors.clear()
	
	for seg_a in segment_graph.keys():
		for seg_b in segment_graph[seg_a]:
			if seg_b < seg_a:
				continue
			
			var shared := _floor_pairs_on_border(seg_a, seg_b)
			if shared.is_empty():
				continue
			
			# Pick a few positions from the shared floor border
			var count = min(3, shared.size())
			for i in range(count):
				var idx := rng.randi_range(0, shared.size() - 1)
				var pos = shared[idx]
				shared.remove_at(idx)
				reserved_doors[pos] = true
	
	print("[SegGen] Rebuilt %d doors from floor layout" % reserved_doors.size())

func _floor_pairs_on_border(seg_a: Vector2i, seg_b: Vector2i) -> Array:
	"""Find positions on the border where both sides have floor"""
	var origin_a := seg_a * SEGMENT_SIZE
	var origin_b := seg_b * SEGMENT_SIZE
	var result: Array = []
	
	if seg_a.x == seg_b.x:
		# Vertical neighbors
		var x0 := origin_a.x
		var y_border = max(origin_a.y, origin_b.y)
		for dx in range(SEGMENT_SIZE):
			var pos0 := Vector2i(x0 + dx, y_border - 1)
			var pos1 := Vector2i(x0 + dx, y_border)
			if _is_floor(pos0) and _is_floor(pos1):
				result.append(pos1)
	else:
		# Horizontal neighbors
		var y0 := origin_a.y
		var x_border = max(origin_a.x, origin_b.x)
		for dy in range(SEGMENT_SIZE):
			var pos0 := Vector2i(x_border - 1, y0 + dy)
			var pos1 := Vector2i(x_border, y0 + dy)
			if _is_floor(pos0) and _is_floor(pos1):
				result.append(pos1)
	
	return result

func _is_floor(pos: Vector2i) -> bool:
	"""Check if a world position is floor"""
	return layout_map.get(pos, TileType.WALL) == TileType.FLOOR

## Step 4: Fill all segments with appropriate patterns
func _fill_all_segments() -> void:
	layout_map.clear()
	
	# Load and cache all template samples
	var samples = _load_template_samples()
	
	var total_segments = 0
	for y in range(SEG_H):
		for x in range(SEG_W):
			if segments[y][x] != SegmentType.SOLID:
				total_segments += 1
	
	var filled = 0
	for y in range(SEG_H):
		for x in range(SEG_W):
			var seg_type = segments[y][x]
			if seg_type == SegmentType.SOLID:
				_fill_segment_solid(x, y)
			else:
				_fill_segment_from_template(x, y, seg_type, samples)
				filled += 1
				
				if filled % 10 == 0:
					print("[SegGen] Filled %d/%d segments" % [filled, total_segments])

func _fill_segment_solid(sx: int, sy: int) -> void:
	"""Fill segment with solid walls"""
	var origin = Vector2i(sx * SEGMENT_SIZE, sy * SEGMENT_SIZE)
	
	for local_y in range(SEGMENT_SIZE):
		for local_x in range(SEGMENT_SIZE):
			var pos = origin + Vector2i(local_x, local_y)
			layout_map[pos] = TileType.WALL

func _fill_segment_wfc(sx: int, sy: int, seg_type: SegmentType) -> void:
	"""Fill segment using WFC with type-specific rules"""
	var origin = Vector2i(sx * SEGMENT_SIZE, sy * SEGMENT_SIZE)
	
	# Get pattern rules for this segment type
	var rules = _get_rules_for_type(seg_type)
	
	# Fill with simple pattern based on type
	for local_y in range(SEGMENT_SIZE):
		for local_x in range(SEGMENT_SIZE):
			var pos = origin + Vector2i(local_x, local_y)
			
			# Respect reserved doors
			if reserved_doors.has(pos):
				layout_map[pos] = TileType.FLOOR
				continue
			
			# Apply type-specific fill logic
			var tile = _get_tile_for_position(local_x, local_y, seg_type, rules)
			layout_map[pos] = tile

func _get_rules_for_type(seg_type: SegmentType) -> Dictionary:
	"""Get generation rules for segment type"""
	match seg_type:
		SegmentType.SHAFT:
			return {"floor_band": 6, "ore_chance": 0.15}
		SegmentType.ROOM:
			return {"floor_margin": 3, "ore_chance": 0.1}
		SegmentType.SIDE_TUNNEL:
			return {"floor_band": 4, "ore_chance": 0.2}
		SegmentType.TEMPLE:
			return {"floor_margin": 4, "ore_chance": 0.05}
		SegmentType.BIG_CHAMBER:
			return {"floor_margin": 2, "ore_chance": 0.1}
		SegmentType.CORRUPTED:
			return {"floor_margin": 3, "lava_chance": 0.3}
		SegmentType.ORE:
			return {"floor_margin": 3, "ore_chance": 0.5}
	
	return {}

func _get_tile_for_position(local_x: int, local_y: int, seg_type: SegmentType, rules: Dictionary) -> int:
	"""Determine tile type for position within segment"""
	match seg_type:
		SegmentType.SHAFT:
			# Vertical band of floor in center
			var center_dist = abs(local_x - SEGMENT_SIZE / 2)
			var floor_band = rules.get("floor_band", 6)
			if center_dist < floor_band / 2:
				if rng.randf() < rules.get("ore_chance", 0.1):
					return TileType.ORE
				return TileType.FLOOR
			return TileType.WALL
		
		SegmentType.ROOM, SegmentType.BIG_CHAMBER, SegmentType.TEMPLE:
			# Floor with wall margins
			var margin = rules.get("floor_margin", 3)
			if local_x < margin or local_x >= SEGMENT_SIZE - margin:
				return TileType.WALL
			if local_y < margin or local_y >= SEGMENT_SIZE - margin:
				return TileType.WALL
			
			# Interior
			if seg_type == SegmentType.TEMPLE and rng.randf() < 0.05:
				return TileType.SHRINE
			elif rng.randf() < rules.get("ore_chance", 0.1):
				return TileType.ORE
			return TileType.FLOOR
		
		SegmentType.SIDE_TUNNEL:
			# Horizontal band
			var center_dist = abs(local_y - SEGMENT_SIZE / 2)
			var floor_band = rules.get("floor_band", 4)
			if center_dist < floor_band / 2:
				if rng.randf() < rules.get("ore_chance", 0.15):
					return TileType.ORE
				return TileType.FLOOR
			return TileType.WALL
		
		SegmentType.CORRUPTED:
			var margin = 3
			if local_x < margin or local_x >= SEGMENT_SIZE - margin:
				return TileType.WALL
			if local_y < margin or local_y >= SEGMENT_SIZE - margin:
				return TileType.WALL
			
			if rng.randf() < rules.get("lava_chance", 0.2):
				return TileType.LAVA
			return TileType.FLOOR
		
		SegmentType.ORE:
			var margin = 3
			if local_x < margin or local_x >= SEGMENT_SIZE - margin:
				return TileType.WALL
			if local_y < margin or local_y >= SEGMENT_SIZE - margin:
				return TileType.WALL
			
			if rng.randf() < rules.get("ore_chance", 0.4):
				return TileType.ORE
			return TileType.FLOOR
	
	return TileType.WALL

## Tile type enum
enum TileType {
	FLOOR,
	WALL,
	ORE,
	LAVA,
	SHRINE
}

## Load template samples for each segment type
func _load_template_samples() -> Dictionary:
	var samples = {}
	
	var templates = {
		SegmentType.SHAFT: "res://rooms/templates/shaft.tscn",
		SegmentType.ROOM: "res://rooms/templates/room.tscn",
		SegmentType.SIDE_TUNNEL: "res://rooms/templates/side_tunnel.tscn",
		SegmentType.TEMPLE: "res://rooms/templates/temple.tscn",
		SegmentType.BIG_CHAMBER: "res://rooms/templates/big_chamber.tscn",
		SegmentType.CORRUPTED: "res://rooms/templates/corrupted.tscn",
		SegmentType.ORE: "res://rooms/templates/ore_vein.tscn",
		# Additional templates for variety
		"treasure_vault": "res://rooms/templates/treasure_vault.tscn",
		"boss_arena": "res://rooms/templates/boss_arena.tscn",
		"nest": "res://rooms/templates/nest.tscn"
	}
	
	for seg_type in templates:
		var path = templates[seg_type]
		if ResourceLoader.exists(path):
			var scene = load(path) as PackedScene
			if scene:
				var instance = scene.instantiate()
				var sample_map = instance.get_node_or_null("SampleMap")
				if sample_map:
					# Learn adjacency from this template
					var model = _learn_from_tilemap(sample_map)
					samples[seg_type] = model
					print("[SegGen] Loaded template: %s (%d tiles)" % [path.get_file(), model.get("tile_weights", {}).size()])
				instance.queue_free()
	
	print("[SegGen] Loaded %d template models" % samples.size())
	return samples

## Learn WFC model from a TileMapLayer
func _learn_from_tilemap(tilemap: TileMapLayer) -> Dictionary:
	var adjacency_rules = {}
	var tile_weights = {}
	
	var used_cells = tilemap.get_used_cells()
	if used_cells.is_empty():
		return {"adjacency_rules": adjacency_rules, "tile_weights": tile_weights}
	
	for cell in used_cells:
		var atlas_coords = tilemap.get_cell_atlas_coords(cell)
		var tile_id = _coord_to_id(atlas_coords)
		
		# Count frequency
		tile_weights[tile_id] = tile_weights.get(tile_id, 0) + 1
		
		# Initialize adjacency
		if not adjacency_rules.has(tile_id):
			adjacency_rules[tile_id] = {"N": [], "E": [], "S": [], "W": []}
		
		# Check neighbors
		var directions = {
			"N": Vector2i(0, -1),
			"E": Vector2i(1, 0),
			"S": Vector2i(0, 1),
			"W": Vector2i(-1, 0)
		}
		
		for dir_name in directions:
			var neighbor_cell = cell + directions[dir_name]
			var neighbor_coords = tilemap.get_cell_atlas_coords(neighbor_cell)
			
			if neighbor_coords != Vector2i(-1, -1):
				var neighbor_id = _coord_to_id(neighbor_coords)
				if neighbor_id not in adjacency_rules[tile_id][dir_name]:
					adjacency_rules[tile_id][dir_name].append(neighbor_id)
	
	return {"adjacency_rules": adjacency_rules, "tile_weights": tile_weights}

## Fill segment using template-learned WFC
func _fill_segment_from_template(sx: int, sy: int, seg_type: SegmentType, samples: Dictionary) -> void:
	var origin = Vector2i(sx * SEGMENT_SIZE, sy * SEGMENT_SIZE)
	
	# Get model for this segment type
	var model = samples.get(seg_type)
	if not model or model.get("adjacency_rules", {}).is_empty():
		# Fallback to simple fill
		_fill_segment_wfc(sx, sy, seg_type)
		return
	
	var adjacency_rules = model["adjacency_rules"]
	var tile_weights = model["tile_weights"]
	
	# Simple frontier-based WFC fill
	var placed = {}
	var frontier = []
	
	# Start with a random tile in center
	var all_tiles = adjacency_rules.keys()
	if all_tiles.is_empty():
		return
	
	var start_tile = all_tiles[rng.randi() % all_tiles.size()]
	var start_pos = Vector2i(SEGMENT_SIZE / 2, SEGMENT_SIZE / 2)
	
	_place_tile_in_segment(origin, start_pos, start_tile, placed)
	frontier.append(start_pos)
	
	# Expand outward
	var max_iterations = SEGMENT_SIZE * SEGMENT_SIZE * 4
	var iterations = 0
	
	while not frontier.is_empty() and iterations < max_iterations:
		iterations += 1
		
		var current = frontier[rng.randi() % frontier.size()]
		frontier.erase(current)
		
		var directions = {
			"N": Vector2i(0, -1),
			"E": Vector2i(1, 0),
			"S": Vector2i(0, 1),
			"W": Vector2i(-1, 0)
		}
		
		for dir_name in directions:
			var next_local = current + directions[dir_name]
			var next_world = origin + next_local
			
			# Bounds check
			if next_local.x < 0 or next_local.x >= SEGMENT_SIZE:
				continue
			if next_local.y < 0 or next_local.y >= SEGMENT_SIZE:
				continue
			if placed.has(next_local):
				continue
			
			# Respect reserved doors
			if reserved_doors.has(next_world):
				var floor_id = _coord_to_id(Vector2i(1, 5))
				_place_tile_in_segment(origin, next_local, floor_id, placed)
				frontier.append(next_local)
				continue
			
			# Find valid tile
			var valid_tile = _find_valid_tile_for_position(next_local, placed, current, dir_name, adjacency_rules, tile_weights)
			if valid_tile != null:
				_place_tile_in_segment(origin, next_local, valid_tile, placed)
				frontier.append(next_local)

func _find_valid_tile_for_position(pos: Vector2i, placed: Dictionary, from_pos: Vector2i, from_dir: String, adjacency_rules: Dictionary, tile_weights: Dictionary) -> Variant:
	# Get tile that was placed at from_pos
	var from_tile = placed.get(from_pos)
	if from_tile == null or not adjacency_rules.has(from_tile):
		# Pick random
		var all_tiles = adjacency_rules.keys()
		return all_tiles[rng.randi() % all_tiles.size()] if not all_tiles.is_empty() else null
	
	# Get allowed neighbors in this direction
	var candidates = adjacency_rules[from_tile].get(from_dir, [])
	
	if candidates.is_empty():
		return null
	
	# Pick weighted random
	var total_weight = 0.0
	for tile_id in candidates:
		total_weight += tile_weights.get(tile_id, 1.0)
	
	var rand_val = rng.randf() * total_weight
	var accumulated = 0.0
	
	for tile_id in candidates:
		accumulated += tile_weights.get(tile_id, 1.0)
		if rand_val <= accumulated:
			return tile_id
	
	return candidates[0]

func _place_tile_in_segment(origin: Vector2i, local_pos: Vector2i, tile_id: int, placed: Dictionary) -> void:
	var world_pos = origin + local_pos
	layout_map[world_pos] = _tile_id_to_type(tile_id)
	placed[local_pos] = tile_id

func _tile_id_to_type(tile_id: int) -> int:
	var coords = _id_to_coord(tile_id)
	
	# Map atlas coords to TileType
	if coords == Vector2i(1, 5) or coords.y == 5:  # Floor row
		return TileType.FLOOR
	elif coords == Vector2i(0, 6) or coords == Vector2i(1, 6) or coords == Vector2i(2, 6):  # Ore
		return TileType.ORE
	elif coords == Vector2i(3, 6):  # Lava
		return TileType.LAVA
	elif coords == Vector2i(4, 7):  # Shrine
		return TileType.SHRINE
	else:  # Default to wall
		return TileType.WALL

func _coord_to_id(coords: Vector2i) -> int:
	return coords.y * 100 + coords.x

func _id_to_coord(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % 100, tile_id / 100)
