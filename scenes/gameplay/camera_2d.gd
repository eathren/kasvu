extends Camera2D

@export var move_speed: float = 300.0

@export var min_x: float = -1000.0
@export var max_x: float = 1000.0
@export var min_y: float = -1000.0
@export var max_y: float = 1000.0

const ZOOM_STEP := 0.1
const MIN_ZOOM := 0.3   # most zoomed in (tiles largest)
const MAX_ZOOM := 5.0   # most zoomed out (tiles smallest)

func _ready() -> void:
	make_current()
	# tiles look bigger because zoom is less than 1
	zoom = Vector2(0.5, 0.5)

func _process(delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		global_position += dir * move_speed * delta
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.y = clamp(global_position.y, min_y, max_y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_out()

func _zoom_in() -> void:
	var new_zoom := zoom.x - ZOOM_STEP
	new_zoom = clamp(new_zoom, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_zoom, new_zoom)

func _zoom_out() -> void:
	var new_zoom := zoom.x + ZOOM_STEP
	new_zoom = clamp(new_zoom, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_zoom, new_zoom)
