extends Node2D

@export var imp_scene: PackedScene
@export var spawn_interval: float = 4.0
@export var max_alive_from_this: int = 5

var alive_from_this := 0
@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	if spawn_timer == null:
		push_error("SpawnTimer missing on HellPortal")
		return
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timeout)
	spawn_timer.start()
	add_to_group("hell_portals")

func set_spawn_profile(profile: Dictionary) -> void:
	if profile.has("scene"):
		imp_scene = profile["scene"]
	if profile.has("interval"):
		spawn_interval = profile["interval"]
		if spawn_timer:
			spawn_timer.wait_time = spawn_interval
	if profile.has("max_alive"):
		max_alive_from_this = profile["max_alive"]

func _on_spawn_timeout() -> void:
	if not GameState.is_night:
		return
	if alive_from_this >= max_alive_from_this:
		return
	if imp_scene == null:
		return

	var imp := imp_scene.instantiate()
	imp.global_position = global_position
	get_tree().current_scene.add_child(imp)

	alive_from_this += 1
	imp.tree_exited.connect(func() -> void:
		alive_from_this -= 1)
