extends Control

## Simple interaction prompt UI at bottom of screen

@onready var label: Label = $Label

func _ready() -> void:
	hide()

func show_interaction_prompt(text: String) -> void:
	label.text = text
	show()

func hide_interaction_prompt() -> void:
	hide()

