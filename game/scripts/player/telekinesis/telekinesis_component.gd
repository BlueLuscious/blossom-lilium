extends Node

const TelekinesisControllerScript := preload("res://scripts/player/telekinesis/telekinesis_controller.gd")
const TelekinesisFormationScript := preload("res://scripts/player/telekinesis/telekinesis_formation.gd")
const TelekinesisTargetingScript := preload("res://scripts/player/telekinesis/telekinesis_targeting.gd")

@export var grab_distance: float = 5.0
@export var throw_force: float = 10.0
@export var max_held_objects: int = 3
@export var initial_hold_follow_speed: float = 6.0
@export var initial_hold_duration: float = 0.45
@export var hold_follow_speed: float = 14.0
@export var max_hold_velocity: float = 14.0
@export var held_linear_damp: float = 8.0
@export var held_angular_damp: float = 8.0
@export var max_grabbable_mass: float = 25.0
@export var hold_slot_spacing: float = 1.25
@export var hold_slot_padding: float = 0.35
@export var hold_triangle_forward_offset: float = 0.2
@export var hold_triangle_height_offset: float = 0.45
@export var hold_triangle_side_offset: float = 0.75
@export var float_amplitude: float = 0.12
@export var float_speed: float = 2.4
@export var movement_sway_strength: float = 0.12
@export var movement_sway_limit: float = 0.55
@export var movement_sway_follow_speed: float = 8.0
@export var outline_scale: float = 1.06
@export var outline_color: Color = Color(0.45, 0.95, 1.0, 1.0)

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = $"../CameraPivot/SpringArm3D/Camera"
@onready var hold_point: Marker3D = $"../HoldPoint"

var controller
var formation
var targeted_object: RigidBody3D = null
var outline_nodes: Array[Node] = []
var outline_material: StandardMaterial3D


func _ready() -> void:
	controller = TelekinesisControllerScript.new()
	formation = TelekinesisFormationScript.new()

	sync_controller_config()
	sync_formation_config()
	create_outline_material()


func _physics_process(delta: float) -> void:
	update_aim_target()
	controller.update_held_objects(delta, player, camera, hold_point, formation)


func try_grab_or_throw() -> void:
	var body := get_grabbable_body_under_crosshair()

	if controller.can_grab_body(body):
		clear_target_outline()
		targeted_object = null
		controller.grab_object(body)
		return

	if controller.has_held_objects():
		controller.throw_held_objects(camera)


func update_aim_target() -> void:
	var body := get_grabbable_body_under_crosshair()
	if body != null and not controller.can_grab_body(body):
		body = null

	if body == targeted_object:
		return

	clear_target_outline()
	targeted_object = body

	if targeted_object != null:
		apply_target_outline(targeted_object)


func get_grabbable_body_under_crosshair() -> RigidBody3D:
	return TelekinesisTargetingScript.get_grabbable_body_under_crosshair(
		player,
		camera,
		grab_distance,
		max_grabbable_mass,
		controller.get_raycast_exclusions(player)
	)


func sync_controller_config() -> void:
	controller.throw_force = throw_force
	controller.max_held_objects = max_held_objects
	controller.initial_hold_follow_speed = initial_hold_follow_speed
	controller.initial_hold_duration = initial_hold_duration
	controller.hold_follow_speed = hold_follow_speed
	controller.max_hold_velocity = max_hold_velocity
	controller.held_linear_damp = held_linear_damp
	controller.held_angular_damp = held_angular_damp
	controller.float_amplitude = float_amplitude
	controller.float_speed = float_speed
	controller.movement_sway_strength = movement_sway_strength
	controller.movement_sway_limit = movement_sway_limit
	controller.movement_sway_follow_speed = movement_sway_follow_speed


func sync_formation_config() -> void:
	formation.slot_spacing = hold_slot_spacing
	formation.slot_padding = hold_slot_padding
	formation.triangle_forward_offset = hold_triangle_forward_offset
	formation.triangle_height_offset = hold_triangle_height_offset
	formation.triangle_side_offset = hold_triangle_side_offset


func create_outline_material() -> void:
	outline_material = StandardMaterial3D.new()
	outline_material.albedo_color = outline_color
	outline_material.emission_enabled = true
	outline_material.emission = outline_color
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT


func apply_target_outline(body: RigidBody3D) -> void:
	for child in body.get_children():
		if child is MeshInstance3D:
			add_outline_for_mesh(child)


func add_outline_for_mesh(mesh_instance: MeshInstance3D) -> void:
	var outline := MeshInstance3D.new()
	outline.name = "TelekinesisOutline"
	outline.mesh = mesh_instance.mesh
	outline.material_override = outline_material
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.scale = Vector3.ONE * outline_scale

	mesh_instance.add_child(outline)
	outline_nodes.append(outline)


func clear_target_outline() -> void:
	for outline in outline_nodes:
		if is_instance_valid(outline):
			outline.queue_free()

	outline_nodes.clear()
