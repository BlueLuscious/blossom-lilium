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
	var is_active := true

	match phase_visibility:
		PhaseVisibility.BOTH:
			is_active = true

		PhaseVisibility.EARTHLY_ONLY:
			is_active = NexumSystem.is_earthly()

		PhaseVisibility.ASTRAL_ONLY:
			is_active = NexumSystem.is_astral()

	visible = is_active
	set_collision_enabled(self, is_active)


func set_collision_enabled(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled

		set_collision_enabled(child, enabled)
