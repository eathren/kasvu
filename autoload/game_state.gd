extends Node

signal day_started
signal night_started
signal time_updated(time_of_day: float)

@export var day_length_seconds: float = 120.0  # full cycle 0.0 -> 1.0

var time_of_day: float = 0.0  # 0.0 morning, 0.5 evening
var is_night: bool = false


func _process(delta: float) -> void:
	if day_length_seconds <= 0.0:
		return

	# advance time, wrap around 0..1
	time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	_update_phase()
	time_updated.emit(time_of_day)



func _update_phase(emit_signal_now: bool = false) -> void:
	# night when time <= 0.25 or >= 0.75
	var new_is_night := (time_of_day <= 0.25 or time_of_day >= 0.75)

	if emit_signal_now or new_is_night != is_night:
		is_night = new_is_night
		if is_night:
			night_started.emit()
		else:
			day_started.emit()


func force_toggle_night() -> void:
	# for testing portals without waiting
	is_night = not is_night
	if is_night:
		night_started.emit()
	else:
		day_started.emit()
