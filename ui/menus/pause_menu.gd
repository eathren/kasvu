extends Control

## In-game pause menu with save/quit options

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		if visible:
			_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	show()
	get_tree().paused = true

func _unpause() -> void:
	hide()
	get_tree().paused = false

func _on_resume_button_pressed() -> void:
	_unpause()

func _on_save_button_pressed() -> void:
	if NetworkManager.is_host:
		GameState.save_game()
		$CenterContainer/VBoxContainer/SaveButton.text = "SAVED!"
		await get_tree().create_timer(1.0).timeout
		$CenterContainer/VBoxContainer/SaveButton.text = "SAVE GAME"
	else:
		print("PauseMenu: Only host can save")

func _on_quit_button_pressed() -> void:
	_unpause()
	await SceneTransition.fade_in()
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
	await SceneTransition.fade_out()
