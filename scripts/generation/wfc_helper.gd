extends Node

## Helper for converting WFC symbols to TileMap tiles

# Map symbols to tile coordinates
# Using WFC tileset (source_id: 6)
const SYMBOL_TO_TILE := {
	# Mine symbols - Core tiles (MAPPED TO WFC TILESET)
	"ROCK": { "source_id": 6, "atlas": Vector2i(1, 1) },        # Wall center
	"EMPTY": { "source_id": 6, "atlas": Vector2i(1, 5) },       # Ground/floor
	"WALL": { "source_id": 6, "atlas": Vector2i(1, 1) },        # Wall center
	"ROOM_FLOOR": { "source_id": 6, "atlas": Vector2i(2, 5) },  # Ground variant
	"CORRIDOR": { "source_id": 6, "atlas": Vector2i(3, 5) },    # Ground variant
	
	# Mine features - Now mapped to actual tiles
	"ORE": { "source_id": 6, "atlas": Vector2i(0, 6) },         # Ore tile
	"LAVA": { "source_id": 6, "atlas": Vector2i(3, 6) },        # Lava tile
	"DOOR": { "source_id": 6, "atlas": Vector2i(0, 7) },        # Door tile
	"TREASURE": { "source_id": 6, "atlas": Vector2i(3, 7) },    # Treasure chest
	"PILLAR": { "source_id": 6, "atlas": Vector2i(2, 7) },      # Pillar tile
	
	# Town/surface symbols - Use ground variants and new props
	"GRASS": { "source_id": 6, "atlas": Vector2i(1, 5) },       # Ground
	"DIRT": { "source_id": 6, "atlas": Vector2i(2, 5) },        # Ground variant
	"STONE_PATH": { "source_id": 6, "atlas": Vector2i(3, 5) },  # Ground variant
	"WATER": { "source_id": 6, "atlas": Vector2i(3, 6) },       # Lava/water tile
	"TREE": { "source_id": 6, "atlas": Vector2i(5, 7) },        # Crate (placeholder)
	"ROCK_SMALL": { "source_id": 6, "atlas": Vector2i(0, 6) },  # Ore (small rock)
	"WALL_STONE": { "source_id": 6, "atlas": Vector2i(1, 1) },  # Wall center
	"WALL_WOOD": { "source_id": 6, "atlas": Vector2i(2, 1) },   # Wall center variant
	"FLOOR_STONE": { "source_id": 6, "atlas": Vector2i(1, 5) }, # Ground
	"FLOOR_WOOD": { "source_id": 6, "atlas": Vector2i(2, 5) },  # Ground variant
	"WINDOW": { "source_id": 6, "atlas": Vector2i(5, 6) },      # Hazard stripe
	"ROOF": { "source_id": 6, "atlas": Vector2i(1, 0) },        # Ceiling tile
	"BARREL": { "source_id": 6, "atlas": Vector2i(6, 7) },      # Barrel tile
	"CRATE": { "source_id": 6, "atlas": Vector2i(5, 7) },       # Crate tile
	
	# Dungeon symbols - Mapped to new tileset
	"VOID": { "source_id": 6, "atlas": Vector2i(4, 6) },        # Pit tile (impassable)
	"WALL_DUNGEON": { "source_id": 6, "atlas": Vector2i(1, 4) },# Reinforced wall
	"FLOOR": { "source_id": 6, "atlas": Vector2i(1, 5) },       # Ground
	"STAIRS_UP": { "source_id": 6, "atlas": Vector2i(5, 6) },   # Hazard stripe (placeholder)
	"STAIRS_DOWN": { "source_id": 6, "atlas": Vector2i(5, 6) }, # Hazard stripe (placeholder)
	"ALTAR": { "source_id": 6, "atlas": Vector2i(4, 7) },       # Shrine tile
	"CHEST": { "source_id": 6, "atlas": Vector2i(3, 7) },       # Treasure chest
	"TORCH": { "source_id": 6, "atlas": Vector2i(2, 7) },       # Pillar (torch placeholder)
	"TRAP": { "source_id": 6, "atlas": Vector2i(5, 6) },        # Hazard stripe (visible)
	"WATER_DEEP": { "source_id": 6, "atlas": Vector2i(3, 6) },  # Lava/water tile
	"BRIDGE": { "source_id": 6, "atlas": Vector2i(1, 7) }       # Door variant (placeholder)
}

static func seed_from_string(s: String) -> int:
	"""Convert string to deterministic seed"""
	var h = hash(s)
	return int(h & 0x7fffffff)

static func chunk_seed(global_seed: String, cx: int, cy: int) -> int:
	"""Generate deterministic seed for a chunk"""
	return seed_from_string("%s_%d_%d" % [global_seed, cx, cy])

static func paint_to_tilemap(tilemap: TileMap, symbol_grid: Array, layer: int = 0) -> void:
	"""Paint WFC symbol grid to TileMap"""
	if symbol_grid.is_empty():
		return
	
	var h := symbol_grid.size()
	var w = symbol_grid[0].size()
	
	for y in range(h):
		for x in range(w):
			var sym: String = symbol_grid[y][x]
			
			if sym == "UNKNOWN":
				continue
			
			if sym not in SYMBOL_TO_TILE:
				push_warning("Unknown symbol for tile mapping: " + sym)
				continue
			
			var info = SYMBOL_TO_TILE[sym]
			tilemap.set_cell(
				layer,
				Vector2i(x, y),
				info.source_id,
				info.atlas
			)

static func generate_chunk(rules_path: String, chunk_size: int, seed_value: int) -> Array:
	"""Generate a chunk of terrain using WFC"""
	var wfc := Wfc.new()
	
	if not wfc.load_rules(rules_path):
		push_error("[WFC] Failed to load rules from: " + rules_path)
		return []
	
	wfc.init_grid(chunk_size, chunk_size, seed_value)
	
	if not wfc.run_to_completion():
		push_error("[WFC] Generation failed (contradiction) for seed %d" % seed_value)
		return []
	
	return wfc.get_symbol_grid()
