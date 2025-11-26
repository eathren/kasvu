extends CanvasLayer

## Simple scene transition with fade in/out

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Start with fade out (transparent)
	color_rect.color.a = 0.0

func fade_in() -> void:
	"""Fade to black"""
	animation_player.play("fade_in")
	await animation_player.animation_finished

func fade_out() -> void:
	"""Fade from black to transparent"""
	animation_player.play("fade_out")
	await animation_player.animation_finished

