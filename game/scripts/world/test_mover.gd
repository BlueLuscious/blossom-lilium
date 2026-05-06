extends Node3D

enum ActivePhase {
	BOTH,
	EARTHLY_ONLY,
	ASTRAL_ONLY
}

@export var active_phase: ActivePhase = ActivePhase.EARTHLY_ONLY
@export var movement_speed: float = 2.0
@export var movement_range: float = 3.0

var start_position: Vector3
var frozen: bool = false
var local_time: float = 0.0


func _ready() -> void:
	start_position = global_position
	NexumSystem.phase_changed.connect(_on_phase_changed)
	update_phase_state()


func _process(delta: float) -> void:
	if frozen:
		return

	local_time += delta

	var offset := sin(local_time * movement_speed) * movement_range
	global_position.x = start_position.x + offset


func _on_phase_changed(_previous_phase: String, _current_phase: String) -> void:
	update_phase_state()


func update_phase_state() -> void:
	match active_phase:
		ActivePhase.BOTH:
			frozen = false

		ActivePhase.EARTHLY_ONLY:
			frozen = not NexumSystem.is_earthly()

		ActivePhase.ASTRAL_ONLY:
			frozen = not NexumSystem.is_astral()
