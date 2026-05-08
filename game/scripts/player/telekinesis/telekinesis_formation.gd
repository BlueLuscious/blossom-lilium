class_name TelekinesisFormation
extends RefCounted

var slot_spacing: float = 1.25
var slot_padding: float = 0.35
var triangle_forward_offset: float = 0.2
var triangle_height_offset: float = 0.45
var triangle_side_offset: float = 0.75


func get_hold_slot_position(
	slot_index: int,
	held_objects: Array,
	hold_point: Marker3D,
	camera: Camera3D,
	player: CharacterBody3D
) -> Vector3:
	var slot_count: int = max(held_objects.size(), 1)
	var spacing: float = get_current_slot_spacing(held_objects)
	var slot_offset := get_hold_triangle_slot_offset(
		slot_index,
		slot_count,
		spacing,
		camera,
		player
	)

	return hold_point.global_position + slot_offset


func get_hold_triangle_slot_offset(
	slot_index: int,
	slot_count: int,
	spacing: float,
	camera: Camera3D,
	player: CharacterBody3D
) -> Vector3:
	var right := get_hold_right_direction(camera, player)
	var up := Vector3.UP
	var forward := get_hold_forward_direction(camera, player)

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
		side_multiplier = triangle_side_offset

	return (
		right * spacing * side_multiplier
		+ up * spacing * triangle_height_offset
		+ forward * triangle_forward_offset
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
				up * spacing * triangle_height_offset
				+ forward * triangle_forward_offset
			)
		1:
			return (
				right * spacing * triangle_side_offset
				+ up * spacing * triangle_height_offset
				+ forward * triangle_forward_offset
			)
		_:
			return (
				right * spacing * triangle_side_offset * 0.5
				+ up * spacing * 0.08
				+ forward * triangle_forward_offset * 1.35
			)


func get_current_slot_spacing(held_objects: Array) -> float:
	var largest_radius: float = 0.0

	for held_state in held_objects:
		if not held_state.is_valid():
			continue

		largest_radius = max(largest_radius, get_grabbable_radius(held_state.body))

	return max(slot_spacing, (largest_radius * 2.0) + slot_padding)


func get_hold_right_direction(camera: Camera3D, player: CharacterBody3D) -> Vector3:
	var right := camera.global_transform.basis.x
	right.y = 0.0

	if right == Vector3.ZERO:
		return player.global_transform.basis.x.normalized()

	return right.normalized()


func get_hold_forward_direction(camera: Camera3D, player: CharacterBody3D) -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0

	if forward == Vector3.ZERO:
		return -player.global_transform.basis.z.normalized()

	return forward.normalized()


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
