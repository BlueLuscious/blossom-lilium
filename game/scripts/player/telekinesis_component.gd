extends Node


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

var held_objects: Array[RigidBody3D] = []
var held_hold_times: Array[float] = []
var held_movement_sways: Array[Vector3] = []
var held_original_gravity_scales: Array[float] = []
var held_original_linear_damps: Array[float] = []
var held_original_angular_damps: Array[float] = []
var targeted_object: RigidBody3D = null
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
	var body := get_grabbable_body_under_crosshair()

	if can_grab_body(body):
		grab_object(body)
		return

	if not held_objects.is_empty():
		throw_held_objects()


func can_grab_body(body: RigidBody3D) -> bool:
	if body == null:
		return false

	if held_objects.has(body):
		return false

	return held_objects.size() < max_held_objects


func grab_object(body: RigidBody3D) -> void:
	clear_target_outline()
	targeted_object = null

	held_objects.append(body)
	held_hold_times.append(0.0)
	held_movement_sways.append(Vector3.ZERO)
	held_original_gravity_scales.append(body.gravity_scale)
	held_original_linear_damps.append(body.linear_damp)
	held_original_angular_damps.append(body.angular_damp)

	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.gravity_scale = 0.0
	body.linear_damp = held_linear_damp
	body.angular_damp = held_angular_damp
	body.freeze = false


func throw_held_objects() -> void:
	if held_objects.is_empty():
		return

	var direction := -camera.global_transform.basis.z

	for i in held_objects.size():
		var object_to_throw := held_objects[i]
		if not is_instance_valid(object_to_throw):
			continue

		restore_held_object_physics(i)
		object_to_throw.linear_velocity = Vector3.ZERO
		object_to_throw.angular_velocity = Vector3.ZERO
		object_to_throw.apply_central_impulse(direction * throw_force * object_to_throw.mass)

	held_objects.clear()
	held_hold_times.clear()
	held_movement_sways.clear()
	held_original_gravity_scales.clear()
	held_original_linear_damps.clear()
	held_original_angular_damps.clear()


func update_aim_target() -> void:
	var body := get_grabbable_body_under_crosshair()
	if body != null and not can_grab_body(body):
		body = null

	if body == targeted_object:
		return

	clear_target_outline()
	targeted_object = body

	if targeted_object != null:
		apply_target_outline(targeted_object)


func update_held_object(delta: float) -> void:
	if held_objects.is_empty():
		return

	for i in range(held_objects.size() - 1, -1, -1):
		var held_object := held_objects[i]
		if not is_instance_valid(held_object):
			remove_held_object_at(i)
			continue

		held_hold_times[i] += delta
		held_movement_sways[i] = held_movement_sways[i].lerp(
			get_player_movement_sway(),
			1.0 - exp(-movement_sway_follow_speed * delta)
		)

		var target_position := get_hold_slot_position(i)
		target_position += held_movement_sways[i] + get_float_offset(held_hold_times[i], i)

		move_held_object_toward(held_object, target_position, held_hold_times[i])


func remove_held_object_at(index: int) -> void:
	if index < held_objects.size() and is_instance_valid(held_objects[index]):
		restore_held_object_physics(index)

	held_objects.remove_at(index)
	held_hold_times.remove_at(index)
	held_movement_sways.remove_at(index)
	held_original_gravity_scales.remove_at(index)
	held_original_linear_damps.remove_at(index)
	held_original_angular_damps.remove_at(index)


func move_held_object_toward(
	held_object: RigidBody3D,
	target_position: Vector3,
	hold_time: float
) -> void:
	var to_target := target_position - held_object.global_position
	var current_follow_speed := get_current_hold_follow_speed(hold_time)
	var desired_velocity := to_target * current_follow_speed

	if desired_velocity.length() > max_hold_velocity:
		desired_velocity = desired_velocity.normalized() * max_hold_velocity

	held_object.linear_velocity = held_object.linear_velocity.lerp(desired_velocity, 0.45)


func restore_held_object_physics(index: int) -> void:
	var body := held_objects[index]
	body.gravity_scale = held_original_gravity_scales[index]
	body.linear_damp = held_original_linear_damps[index]
	body.angular_damp = held_original_angular_damps[index]


func get_hold_slot_position(slot_index: int) -> Vector3:
	var slot_count: int = max(held_objects.size(), 1)
	var spacing: float = get_current_slot_spacing()
	var slot_offset := get_hold_triangle_slot_offset(slot_index, slot_count, spacing)
	return hold_point.global_position + slot_offset


func get_hold_triangle_slot_offset(slot_index: int, slot_count: int, spacing: float) -> Vector3:
	var right := get_hold_right_direction()
	var up := Vector3.UP
	var forward := get_hold_forward_direction()

	if slot_count == 1:
		return Vector3.ZERO

	if slot_count == 2:
		return get_two_object_slot_offset(slot_index, spacing, right, up, forward)

	return get_three_object_slot_offset(slot_index, spacing, right, up, forward)


func get_two_object_slot_offset(
	slot_index: int,
	spacing: float,
	right: Vector3,
	up: Vector3,
	forward: Vector3
) -> Vector3:
	var side_multiplier := 0.0
	if slot_index == 1:
		side_multiplier = hold_triangle_side_offset

	return (
		right * spacing * side_multiplier
		+ up * spacing * hold_triangle_height_offset
		+ forward * hold_triangle_forward_offset
	)


func get_three_object_slot_offset(
	slot_index: int,
	spacing: float,
	right: Vector3,
	up: Vector3,
	forward: Vector3
) -> Vector3:
	match slot_index:
		0:
			return (
				up * spacing * hold_triangle_height_offset
				+ forward * hold_triangle_forward_offset
			)
		1:
			return (
				right * spacing * hold_triangle_side_offset
				+ up * spacing * hold_triangle_height_offset
				+ forward * hold_triangle_forward_offset
			)
		_:
			return (
				right * spacing * hold_triangle_side_offset * 0.5
				+ up * spacing * 0.08
				+ forward * hold_triangle_forward_offset * 1.35
			)


func get_current_slot_spacing() -> float:
	var largest_radius: float = 0.0

	for body in held_objects:
		if not is_instance_valid(body):
			continue

		largest_radius = max(largest_radius, get_grabbable_radius(body))

	return max(hold_slot_spacing, (largest_radius * 2.0) + hold_slot_padding)


func get_hold_right_direction() -> Vector3:
	var right := camera.global_transform.basis.x
	right.y = 0.0

	if right == Vector3.ZERO:
		return player.global_transform.basis.x.normalized()

	return right.normalized()


func get_hold_forward_direction() -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0

	if forward == Vector3.ZERO:
		return -player.global_transform.basis.z.normalized()

	return forward.normalized()


func get_current_hold_follow_speed(hold_time: float) -> float:
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


func get_float_offset(hold_time: float, slot_index: int) -> Vector3:
	var time_offset := float(slot_index) * 0.7
	var vertical := sin((hold_time + time_offset) * float_speed) * float_amplitude
	var lateral := sin((hold_time + time_offset) * float_speed * 0.65) * float_amplitude * 0.35
	return Vector3(lateral, vertical, 0.0)


func get_grabbable_body_under_crosshair() -> RigidBody3D:
	var space_state := player.get_world_3d().direct_space_state

	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * grab_distance)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = get_raycast_exclusions()

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


func get_raycast_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [player.get_rid()]

	for body in held_objects:
		if is_instance_valid(body):
			exclusions.append(body.get_rid())

	return exclusions


func get_grabbable_radius(body: RigidBody3D) -> float:
	var radius := 0.5

	for child in body.get_children():
		if not child is MeshInstance3D:
			continue

		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var size := mesh_instance.get_aabb().size * mesh_instance.global_transform.basis.get_scale()
		radius = max(radius, size.length() * 0.5)

	return radius


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
