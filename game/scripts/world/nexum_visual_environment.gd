extends Node

@export var transition_duration: float = 0.45
@export var directional_light_path: NodePath = ^"../DirectionalLight3D"

@export var earthly_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var astral_tint: Color = Color(0.22, 0.55, 0.95, 0.22)

@export var earthly_light_color: Color = Color(1.0, 0.95, 0.84, 1.0)
@export var astral_light_color: Color = Color(0.55, 0.82, 1.0, 1.0)
@export var earthly_light_energy: float = 1.0
@export var astral_light_energy: float = 0.65

var overlay: ColorRect
var directional_light: DirectionalLight3D
var transition_tween: Tween


func _ready() -> void:
	directional_light = get_node_or_null(directional_light_path) as DirectionalLight3D
	create_overlay()
	NexumSystem.phase_changed.connect(_on_phase_changed)
	apply_phase_visuals(NexumSystem.current_phase, true)


func create_overlay() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "NexumVisualOverlay"
	add_child(canvas_layer)

	overlay = ColorRect.new()
	overlay.name = "PhaseTint"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(overlay)


func _on_phase_changed(_previous_phase: String, current_phase: String) -> void:
	apply_phase_visuals(current_phase, false)


func apply_phase_visuals(phase: String, instant: bool) -> void:
	var target_tint := earthly_tint
	var target_light_color := earthly_light_color
	var target_light_energy := earthly_light_energy

	if phase == NexumSystem.PHASE_ASTRAL:
		target_tint = astral_tint
		target_light_color = astral_light_color
		target_light_energy = astral_light_energy

	if transition_tween != null:
		transition_tween.kill()

	if instant:
		overlay.color = target_tint
		apply_light_visuals(target_light_color, target_light_energy)
		return

	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.tween_property(
		overlay,
		"color",
		target_tint,
		transition_duration
	)

	if directional_light != null:
		transition_tween.tween_property(
			directional_light,
			"light_color",
			target_light_color,
			transition_duration
		)
		transition_tween.tween_property(
			directional_light,
			"light_energy",
			target_light_energy,
			transition_duration
		)


func apply_light_visuals(light_color: Color, light_energy: float) -> void:
	if directional_light == null:
		return

	directional_light.light_color = light_color
	directional_light.light_energy = light_energy
