extends Node3D

enum PhaseVisibility {
	BOTH,
	EARTHLY_ONLY,
	ASTRAL_ONLY
}

@export var phase_visibility: PhaseVisibility = PhaseVisibility.BOTH


func _ready() -> void:
	NexumSystem.phase_changed.connect(_on_phase_changed)
	update_visibility()


func _on_phase_changed(_previous_phase: String, _current_phase: String) -> void:
	update_visibility()


func update_visibility() -> void:
	match phase_visibility:
		PhaseVisibility.BOTH:
			visible = true

		PhaseVisibility.EARTHLY_ONLY:
			visible = NexumSystem.is_earthly()

		PhaseVisibility.ASTRAL_ONLY:
			visible = NexumSystem.is_astral()
