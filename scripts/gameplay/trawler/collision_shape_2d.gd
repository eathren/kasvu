extends Node2D

enum DockSide {
	LEFT,
	RIGHT
}

@export var ship_scene: PackedScene      # assign PlayerShip scene in the inspector
@export var side: DockSide = DockSide.LEFT

var area: Area2D
var dock_marker: Marker2D
var sprite: Sprite2D

var player_in_zone: CharacterBody2D = null

func _ready() -> void:
	# Get nodes manually to ensure they're found
	area = get_node_or_null("Area2D")
	dock_marker = get_node_or_null("DockerMarker")
	sprite = get_node_or_null("Sprite2D")
	
	if area == null:
		push_error("LadderDock: Area2D not found")
		return
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	set_process_input(true)
	_update_sprite_flip()

func _on_body_entered(body: Node) -> void:
	print("LadderDock: Body entered - ", body.name, " Groups: ", body.get_groups())
	if body.is_in_group("player"):
		player_in_zone = body as CharacterBody2D
		print("LadderDock: Player entered zone")
		# Show UI prompt
		_show_prompt()

func _on_body_exited(body: Node) -> void:
	if body == player_in_zone:
		player_in_zone = null
		print("LadderDock: Player exited zone")
		# Hide UI prompt
		_hide_prompt()

func _show_prompt() -> void:
	# Show "Press E to board ship" message
	var ui := get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.has_method("show_interaction_prompt"):
		ui.show_interaction_prompt("Press E to board ship")

func _hide_prompt() -> void:
	var ui := get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.has_method("hide_interaction_prompt"):
		ui.hide_interaction_prompt()

func _input(event: InputEvent) -> void:
	if player_in_zone == null:
		return
	if event.is_action_pressed("interact"):
		_board_ship()

func _board_ship() -> void:
	if player_in_zone == null:
		return
	
	if ship_scene == null:
		push_warning("LadderDock: No ship scene assigned")
		return

	# 1. Deactivate player on foot
	player_in_zone.deactivate()

	# 2. Spawn ship outside the trawler (as sibling to trawler in the level)
	var level := get_tree().current_scene.get_node_or_null("Level_Mine")
	if level == null:
		level = get_tree().current_scene
	
	var ship := ship_scene.instantiate()
	level.add_child(ship)

	# Position ship outside the trawler, offset to the side
	var spawn_offset := Vector2.ZERO
	if side == DockSide.LEFT:
		spawn_offset = Vector2(-80, 0)  # 80 pixels to the left
	else:
		spawn_offset = Vector2(80, 0)   # 80 pixels to the right
	
	# Get trawler to apply offset relative to its rotation
	var trawler := get_parent().get_parent()
	ship.global_position = dock_marker.global_position + spawn_offset.rotated(trawler.rotation)
	ship.rotation = trawler.rotation  # Match trawler rotation

	# 3. Give control to the ship
	ship.call_deferred("take_control_from_player", player_in_zone)
	
	print("Player boarded ship at ", ship.global_position)

func _update_sprite_flip() -> void:
	if sprite:
		# Flip horizontally for right side
		sprite.flip_h = (side == DockSide.RIGHT)
