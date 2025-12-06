extends Node2D

## Test scene for segmented mine generation

@onready var target_map: TileMapLayer = $TargetMap
@onready var camera: Camera2D = $Camera2D


const SegmentedMineGenerator = preload("res://systems/generation/segmented_mine_generator.gd")

func _ready() -> void:
	print("=== Segmented Mine Generator Test ===")
	print("Generating...")
	
	var gen = SegmentedMineGenerator.new()
	var result = gen.generate(12345)
	
	# Apply to tilemap
	_apply_layout(result)
	
	# Center camera
	var bounds = result["bounds"]
	camera.position = Vector2(bounds.x * 8, bounds.y * 8)
	
	print("Generation complete! Press ESC to quit")

func _apply_layout(result: Dictionary) -> void:
	target_map.clear()
	
	var layout = result["layout_map"]
	var segments = result["segments"]
	var source_id = 6
	
	# Tile coordinates with more variety
	var tiles = {
		SegmentedMineGenerator.TileType.FLOOR: Vector2i(1, 5),
		SegmentedMineGenerator.TileType.WALL: Vector2i(1, 1),
		SegmentedMineGenerator.TileType.ORE: Vector2i(0, 6),
		SegmentedMineGenerator.TileType.LAVA: Vector2i(3, 6),
		SegmentedMineGenerator.TileType.SHRINE: Vector2i(4, 7)
	}
	
	# Apply tiles with segment-aware styling
	for pos in layout:
		var tile_type = layout[pos]
		
		# Determine which segment this tile is in
		var seg_x = pos.x / 32
		var seg_y = pos.y / 32
		var seg_type = segments[seg_y][seg_x]
		
		# Highlight spawn zones with distinct colors
		var tile_coord = tiles.get(tile_type, Vector2i(1, 1))
		
		# Boss area (top) - use bright distinctive floor
		if seg_y == 0:
			if tile_type == SegmentedMineGenerator.TileType.FLOOR:
				tile_coord = Vector2i(4, 5)  # Bright floor for boss area
		# Player spawn area (bottom) - use different distinctive floor
		elif seg_y >= segments.size() - 2:
			if tile_type == SegmentedMineGenerator.TileType.FLOOR:
				tile_coord = Vector2i(0, 5)  # Different floor for player spawn
		# Normal area styling
		elif tile_type == SegmentedMineGenerator.TileType.WALL:
			match seg_type:
				SegmentedMineGenerator.SegmentType.CORRUPTED:
					tile_coord = Vector2i(2, 1)  # Different wall style
				SegmentedMineGenerator.SegmentType.TEMPLE:
					tile_coord = Vector2i(3, 1)  # Temple wall
				SegmentedMineGenerator.SegmentType.ORE:
					tile_coord = Vector2i(0, 1)  # Rocky wall
		elif tile_type == SegmentedMineGenerator.TileType.FLOOR:
			match seg_type:
				SegmentedMineGenerator.SegmentType.CORRUPTED:
					tile_coord = Vector2i(2, 5)  # Different floor
				SegmentedMineGenerator.SegmentType.TEMPLE:
					tile_coord = Vector2i(3, 5)  # Temple floor
		
		target_map.set_cell(pos, source_id, tile_coord)
	
	# Print segment type distribution
	print("[Test] Applied %d tiles" % layout.size())
	print("[Test] Boss spawn area: TOP (y=0, bright floor)")
	print("[Test] Player spawn area: BOTTOM (y=%d-%d, different floor)" % [segments.size() - 2, segments.size() - 1])
	print("[Test] Use WASD to move camera, Q/E to zoom in/out")
	_print_segment_stats(segments)

func _process(delta: float) -> void:
	var move_speed := 500.0 * delta
	var zoom_speed := 0.5 * delta
	
	# Cwamera movement
	if Input.is_key_pressed(KEY_W):
		camera.position.y -= move_speed / camera.zoom.x
	if Input.is_key_pressed(KEY_S):
		camera.position.y += move_speed / camera.zoom.x
	if Input.is_key_pressed(KEY_A):
		camera.position.x -= move_speed / camera.zoom.x
	if Input.is_key_pressed(KEY_D):
		camera.position.x += move_speed / camera.zoom.x
	
	# Camera zoom
	if Input.is_key_pressed(KEY_Q):
		camera.zoom += Vector2.ONE * zoom_speed
		camera.zoom = camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(2.0, 2.0))
	if Input.is_key_pressed(KEY_E):
		camera.zoom -= Vector2.ONE * zoom_speed
		camera.zoom = camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(2.0, 2.0))

func _print_segment_stats(segments: Array) -> void:
	var counts = {}
	var seg_names = {
		SegmentedMineGenerator.SegmentType.SOLID: "SOLID",
		SegmentedMineGenerator.SegmentType.SHAFT: "SHAFT",
		SegmentedMineGenerator.SegmentType.ROOM: "ROOM",
		SegmentedMineGenerator.SegmentType.SIDE_TUNNEL: "SIDE_TUNNEL",
		SegmentedMineGenerator.SegmentType.TEMPLE: "TEMPLE",
		SegmentedMineGenerator.SegmentType.BIG_CHAMBER: "BIG_CHAMBER",
		SegmentedMineGenerator.SegmentType.CORRUPTED: "CORRUPTED",
		SegmentedMineGenerator.SegmentType.ORE: "ORE",
		SegmentedMineGenerator.SegmentType.EMPTY: "EMPTY"
	}
	
	for row in segments:
		for seg_type in row:
			var name = seg_names.get(seg_type, "UNKNOWN")
			counts[name] = counts.get(name, 0) + 1
	
	print("[Test] Segment distribution:")
	for seg_name in counts:
		print("  %s: %d" % [seg_name, counts[seg_name]])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
