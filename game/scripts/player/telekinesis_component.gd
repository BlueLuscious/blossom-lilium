extends Node


@export var grab_distance: float = 5.0
@export var throw_force: float = 10.0
@export var initial_hold_follow_speed: float = 6.0
@export var initial_hold_duration: float = 0.45
@export var hold_follow_speed: float = 14.0
@export var max_grabbable_mass: float = 25.0
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

var held_object: RigidBody3D = null
var targeted_object: RigidBody3D = null
var hold_time: float = 0.0
var movement_sway: Vector3 = Vector3.ZERO
var outline_nodes: Array[Node] = []
var outline_material: StandardMaterial3D


func _ready() -> void:
	outline_material = StandardMaterial3D.new()
	outline_material.albedo_color = outline_color
	outline_material.emission_enabled = true
	outline_material.emission = outline_color
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT


func _physics_process(delta: float) -> void:
	update_aim_target()

	update_held_object(delta)


func try_grab_or_throw() -> void:
	if held_object != null:
		use_held_object()
	else:
		use_aim_target()


func use_aim_target() -> void:
	var body := get_grabbable_body_under_crosshair()
	if body == null:
		return

	grab_object(body)


func use_held_object() -> void:
	throw_held_object()


func grab_object(body: RigidBody3D) -> void:
	clear_target_outline()
	targeted_object = null
	hold_time = 0.0
	movement_sway = Vector3.ZERO

	held_object = body
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO
	held_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	held_object.freeze = true


func throw_held_object() -> void:
	if held_object == null:
		return

	var object_to_throw := held_object
	held_object = null
	hold_time = 0.0
	movement_sway = Vector3.ZERO

	var direction := -camera.global_transform.basis.z

	object_to_throw.freeze = false
	object_to_throw.linear_velocity = Vector3.ZERO
	object_to_throw.angular_velocity = Vector3.ZERO
	object_to_throw.apply_central_impulse(direction * throw_force * object_to_throw.mass)


func update_aim_target() -> void:
	if held_object != null:
		if targeted_object != null:
			clear_target_outline()
			targeted_object = null
		return

	var body := get_grabbable_body_under_crosshair()
	if body == targeted_object:
		return

	clear_target_outline()
	targeted_object = body

	if targeted_object != null:
		apply_target_outline(targeted_object)


func update_held_object(delta: float) -> void:
	if held_object == null:
		return

	hold_time += delta
	movement_sway = movement_sway.lerp(
		get_player_movement_sway(),
		1.0 - exp(-movement_sway_follow_speed * delta)
	)

	var target_position := hold_point.global_position + movement_sway + get_float_offset()
	var current_follow_speed := get_current_hold_follow_speed()
	var follow_weight := 1.0 - exp(-current_follow_speed * delta)
	var next_position := held_object.global_position.lerp(target_position, follow_weight)

	held_object.global_transform = Transform3D(
		held_object.global_transform.basis,
		next_position
	)


func get_current_hold_follow_speed() -> float:
	var settle_progress: float = clamp(hold_time / initial_hold_duration, 0.0, 1.0)
	return lerp(initial_hold_follow_speed, hold_follow_speed, settle_progress)


func get_player_movement_sway() -> Vector3:
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity == Vector3.ZERO:
		return Vector3.ZERO

	var sway := -horizontal_velocity * movement_sway_strength
	if sway.length() > movement_sway_limit:
		sway = sway.normalized() * movement_sway_limit

	return sway


func get_float_offset() -> Vector3:
	var vertical := sin(hold_time * float_speed) * float_amplitude
	var lateral := sin(hold_time * float_speed * 0.65) * float_amplitude * 0.35
	return Vector3(lateral, vertical, 0.0)


func get_grabbable_body_under_crosshair() -> RigidBody3D:
	var space_state := player.get_world_3d().direct_space_state

	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * grab_distance)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider: Object = result["collider"]

	if not (collider is RigidBody3D):
		return null

	var body := collider as RigidBody3D
	if body.mass > max_grabbable_mass:
		return null

	return body


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
