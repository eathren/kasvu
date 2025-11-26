extends Node

## RunManager - Owns run state, seed, difficulty, and level swapping
## Handles loading/unloading level scenes under Main/CurrentLevel

signal level_loaded
signal run_started(seed: int)

# Run state
var current_level: Node = null
var current_seed: int = 0
var current_level_num: int = 1
var level_start_time: float = 0.0
var level_duration_minutes: float = 10.0

# Level configuration (can be overridden)
var shaft_height_tiles: int = 2000  # Reduced from 3000
var shaft_width_tiles: int = 100  # Reduced from 400 (
var starter_clearing_width_px: float = 300.0
var starter_clearing_height_px: float = 500.0

func _ready() -> void:
	# RunManager is ready
	pass

## Start a new run with a seed
func start_run(seed: int = 0) -> void:
	if seed == 0:
		seed = randi()
	
	current_seed = seed
	current_level_num = 1
	level_start_time = Time.get_ticks_msec() / 1000.0
	
	_load_level("res://scenes/levels/level_mine.tscn")
	run_started.emit(seed)

## Load a level scene with simple fade transition
func _load_level(path: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		push_error("RunManager: Main node not found in scene tree")
		return
	
	var level_slot := main.get_node_or_null("CurrentLevel")
	if level_slot == null:
		push_error("RunManager: CurrentLevel node not found under Main")
		return
	
	# Fade in (to black)
	print("RunManager: Starting fade in")
	if SceneTransition:
		await SceneTransition.fade_in()
	print("RunManager: Fade in complete")
	
	# Clear old level
	for child in level_slot.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Load and instantiate new level
	print("RunManager: Loading level: ", path)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("RunManager: Failed to load level scene: " + path)
		if SceneTransition:
			await SceneTransition.fade_out()
		return
	
	print("RunManager: Instantiating level")
	var level := packed.instantiate()
	level_slot.add_child(level)
	current_level = level
	
	# Wait for level's _ready() to complete (generation is now synchronous)
	print("RunManager: Waiting for level _ready()")
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("RunManager: Level ready, fading out")
	# Fade out (from black)
	if SceneTransition:
		await SceneTransition.fade_out()
	
	level_loaded.emit()
	print("RunManager: Loaded level from ", path)

## Return to hub (if you have one)
func return_to_hub() -> void:
	_load_level("res://scenes/levels/Hub.tscn")

## Get level progress (0.0 to 1.0)
func get_level_progress() -> float:
	if level_duration_minutes <= 0.0:
		return 0.0
	
	var elapsed_seconds: float = (Time.get_ticks_msec() / 1000.0) - level_start_time
	var elapsed_minutes: float = elapsed_seconds / 60.0
	return clamp(elapsed_minutes / level_duration_minutes, 0.0, 1.0)

## Check if level is complete
func is_level_complete() -> bool:
	return get_level_progress() >= 1.0

## Get generator config for current run
func get_generator_config() -> Dictionary:
	return {
		"shaft_height_tiles": shaft_height_tiles,
		"shaft_width_tiles": shaft_width_tiles,
		"starter_clearing_width_px": starter_clearing_width_px,
		"starter_clearing_height_px": starter_clearing_height_px
	}
