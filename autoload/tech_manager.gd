extends Node

var unlocked:={}

func has_tech(t: StringName) -> bool:
	return unlocked.get(t, false)
	
func unlock(t: StringName) -> void:
	unlocked[t] = true
