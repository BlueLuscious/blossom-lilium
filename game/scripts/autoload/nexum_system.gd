extends Node

signal phase_changed(previous_phase: String, current_phase: String)

const PHASE_EARTHLY := "earthly"
const PHASE_ASTRAL := "astral"

var current_phase: String = PHASE_EARTHLY


func toggle_phase() -> void:
	if current_phase == PHASE_EARTHLY:
		set_phase(PHASE_ASTRAL)
	else:
		set_phase(PHASE_EARTHLY)


func set_phase(new_phase: String) -> void:
	if new_phase == current_phase:
		return

	var previous_phase := current_phase
	current_phase = new_phase

	print("Nexum phase changed: ", previous_phase, " -> ", current_phase)

	phase_changed.emit(previous_phase, current_phase)


func is_earthly() -> bool:
	return current_phase == PHASE_EARTHLY


func is_astral() -> bool:
	return current_phase == PHASE_ASTRAL
