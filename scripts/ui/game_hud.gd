extends CanvasLayer
class_name GameHUD

## Main game HUD showing XP, level, and timer

@onready var xp_bar: ProgressBar = $MarginContainer/HBoxContainer/CenterContainer/XPBar
@onready var level_label: Label = $MarginContainer/HBoxContainer/RightContainer/LevelLabel
@onready var timer_label: Label = $MarginContainer/HBoxContainer/LeftContainer/TimerLabel
@onready var kills_label: Label = $MarginContainer/HBoxContainer/RightContainer/KillsLabel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/RightContainer/GoldLabel
@onready var scrap_label: Label = $MarginContainer/HBoxContainer/RightContainer/ScrapLabel

var game_start_time: float = 0.0

func _ready() -> void:
	# Connect to GameState signals
	if GameState:
		GameState.experience_gained.connect(_on_experience_gained)
		GameState.level_up.connect(_on_level_up)
		GameState.kills_changed.connect(_on_kills_changed)
		GameState.gold_changed.connect(_on_gold_changed)
		GameState.scrap_changed.connect(_on_scrap_changed)
	
	# Initialize displays
	_update_xp_bar()
	_update_level_display()
	_update_resource_displays()
	
	# Record start time
	game_start_time = Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	_update_timer()

func _update_xp_bar() -> void:
	if not xp_bar or not GameState:
		return
	
	var current_xp: int = GameState.get_xp()
	var xp_needed: int = GameState.get_xp_to_next_level()
	
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
	
	# Update label on the bar
	var xp_label = xp_bar.get_node_or_null("XPLabel")
	if xp_label and xp_label is Label:
		xp_label.text = "%d / %d XP" % [current_xp, xp_needed]

func _update_level_display() -> void:
	if not level_label or not GameState:
		return
	
	var level: int = GameState.get_level()
	level_label.text = "Level %d" % level

func _update_timer() -> void:
	if not timer_label:
		return
	
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - game_start_time
	
	var minutes: int = int(elapsed / 60.0)
	var seconds: int = int(elapsed) % 60
	
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_experience_gained(_amount: int, _total: int) -> void:
	_update_xp_bar()

func _on_level_up(_new_level: int) -> void:
	_update_level_display()
	_update_xp_bar()

func _update_resource_displays() -> void:
	_update_kills_display()
	_update_gold_display()
	_update_scrap_display()

func _update_kills_display() -> void:
	if not kills_label or not GameState:
		return
	kills_label.text = "Kills: %d" % GameState.get_kills()

func _update_gold_display() -> void:
	if not gold_label or not GameState:
		return
	gold_label.text = "Gold: %d" % GameState.get_gold()

func _update_scrap_display() -> void:
	if not scrap_label or not GameState:
		return
	scrap_label.text = "Scrap: %d" % GameState.get_scrap()

func _on_kills_changed(_new_count: int) -> void:
	_update_kills_display()

func _on_gold_changed(_new_count: int) -> void:
	_update_gold_display()

func _on_scrap_changed(_new_count: int) -> void:
	_update_scrap_display()

