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
	# Initialize grid
	segments = []
	for y in range(SEG_H):
		var row = []
		for x in range(SEG_W):
			row.append(SegmentType.SOLID)
		segments.append(row)
	
	# Center column index
	var center_x = SEG_W / 2
	
	# Fill center column with varied segment types (trawler will burrow through)
	segments[0][center_x] = SegmentType.ROOM  # Spawn area
	segments[1][center_x] = SegmentType.ROOM
	
	for y in range(2, SEG_H):
		var roll = rng.randf()
		if roll < 0.3:
			segments[y][center_x] = SegmentType.SHAFT
		elif roll < 0.45:
			segments[y][center_x] = SegmentType.ROOM
		elif roll < 0.6:
			segments[y][center_x] = SegmentType.BIG_CHAMBER
		elif roll < 0.7:
			segments[y][center_x] = SegmentType.TEMPLE
		elif roll < 0.8:
			segments[y][center_x] = SegmentType.ORE
		elif roll < 0.9:
			segments[y][center_x] = SegmentType.CORRUPTED
		else:
			segments[y][center_x] = SegmentType.SIDE_TUNNEL
	
	# Create side branches every 2-4 segments (more frequent)
	var y = 3
	while y < SEG_H:
		var branch_length = rng.randi_range(2, 5)  # Longer branches
		var go_left = rng.randf() < 0.5
		
		# Branch direction
		var dx = -1 if go_left else 1
		var branch_x = center_x + dx
		
		# Create tunnel segments
		for i in range(branch_length):
			if branch_x < 0 or branch_x >= SEG_W:
				break
			
			segments[y][branch_x] = SegmentType.SIDE_TUNNEL
			
			# Add more variety near tunnels (higher chance)
			if rng.randf() < 0.6 and branch_x + dx >= 0 and branch_x + dx < SEG_W:
				var roll = rng.randf()
				if roll < 0.35:
					segments[y][branch_x + dx] = SegmentType.ORE
				elif roll < 0.65:
					segments[y][branch_x + dx] = SegmentType.CORRUPTED
				else:
					segments[y][branch_x + dx] = SegmentType.ROOM
			
			branch_x += dx
		
		# End with a chamber (more variety)
		if branch_x >= 0 and branch_x < SEG_W:
			var chamber_type = rng.randf()
			if chamber_type < 0.2:
				segments[y][branch_x] = SegmentType.TEMPLE
			elif chamber_type < 0.5:
				segments[y][branch_x] = SegmentType.BIG_CHAMBER
			elif chamber_type < 0.7:
				segments[y][branch_x] = SegmentType.ROOM
			elif chamber_type < 0.85:
				segments[y][branch_x] = SegmentType.ORE
			else:
				segments[y][branch_x] = SegmentType.CORRUPTED
		
		# Next branch (more frequent)
		y += rng.randi_range(2, 4)
	
	# Add scattered special zones in solid areas
	for attempt in range(20):
		var zone_x = rng.randi_range(0, SEG_W - 1)
		var zone_y = rng.randi_range(4, SEG_H - 1)
		
		# Only place in solid areas
		if segments[zone_y][zone_x] == SegmentType.SOLID:
			var zone_type = rng.randf()
			if zone_type < 0.3:
				# Small ore pocket (1-2 segments)
				segments[zone_y][zone_x] = SegmentType.ORE
				if zone_x + 1 < SEG_W and segments[zone_y][zone_x + 1] == SegmentType.SOLID and rng.randf() < 0.5:
					segments[zone_y][zone_x + 1] = SegmentType.ORE
			elif zone_type < 0.5:
				# Hidden temple
				segments[zone_y][zone_x] = SegmentType.TEMPLE
			elif zone_type < 0.7:
				# Corrupted zone (2x2)
				segments[zone_y][zone_x] = SegmentType.CORRUPTED
				if zone_x + 1 < SEG_W and segments[zone_y][zone_x + 1] == SegmentType.SOLID:
					segments[zone_y][zone_x + 1] = SegmentType.CORRUPTED
				if zone_y + 1 < SEG_H and segments[zone_y + 1][zone_x] == SegmentType.SOLID:
					segments[zone_y + 1][zone_x] = SegmentType.CORRUPTED
			else:
				# Big chamber
				segments[zone_y][zone_x] = SegmentType.BIG_CHAMBER
	
	# Log segment counts
	var counts = {}
	for seg_y in range(SEG_H):
		for seg_x in range(SEG_W):
			var type = segments[seg_y][seg_x]
			counts[type] = counts.get(type, 0) + 1
	
	print("[SegGen] Segment layout: ", counts)

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

## Step 3: Reserve door positions at segment boundaries
func _reserve_doors() -> void:
	reserved_doors.clear()
	
	for seg_pos in segment_graph:
		var neighbors = segment_graph[seg_pos]
		
		for neighbor_pos in neighbors:
			# Only process each pair once
			if neighbor_pos < seg_pos:
				continue
			
			# Find border and place door
			_place_door_between(seg_pos, neighbor_pos)
	
	print("[SegGen] Reserved %d door positions" % reserved_doors.size())

func _place_door_between(seg_a: Vector2i, seg_b: Vector2i) -> void:
	"""Place door(s) at the border between two segments"""
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
