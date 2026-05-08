class_name TelekinesisController
extends RefCounted

const HeldObjectStateScript := preload("res://scripts/player/telekinesis/held_object_state.gd")

var throw_force: float = 10.0
var max_held_objects: int = 3
var initial_hold_follow_speed: float = 6.0
var initial_hold_duration: float = 0.45
var hold_follow_speed: float = 14.0
var max_hold_velocity: float = 14.0
var held_linear_damp: float = 8.0
var held_angular_damp: float = 8.0
var float_amplitude: float = 0.12
var float_speed: float = 2.4
var movement_sway_strength: float = 0.12
var movement_sway_limit: float = 0.55
var movement_sway_follow_speed: float = 8.0

var held_objects: Array[HeldObjectStateScript] = []


func has_held_objects() -> bool:
	return not held_objects.is_empty()


func can_grab_body(body: RigidBody3D) -> bool:
	if body == null:
		return false

	if is_body_held(body):
		return false

	return held_objects.size() < max_held_objects


func grab_object(body: RigidBody3D) -> void:
	held_objects.append(HeldObjectStateScript.new(body))

	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.gravity_scale = 0.0
	body.linear_damp = held_linear_damp
	body.angular_damp = held_angular_damp
	body.freeze = false


func throw_held_objects(camera: Camera3D) -> void:
	if held_objects.is_empty():
		return

	var direction := -camera.global_transform.basis.z

	for i in held_objects.size():
		var held_state := held_objects[i]
		if not held_state.is_valid():
			continue

		var object_to_throw := held_state.body
		held_state.restore_physics()
		object_to_throw.linear_velocity = Vector3.ZERO
		object_to_throw.angular_velocity = Vector3.ZERO
		object_to_throw.apply_central_impulse(direction * throw_force * object_to_throw.mass)

	held_objects.clear()


func update_held_objects(
	delta: float,
	player: CharacterBody3D,
	camera: Camera3D,
	hold_point: Marker3D,
	formation: RefCounted
) -> void:
	if held_objects.is_empty():
		return

	for i in range(held_objects.size() - 1, -1, -1):
		var held_state := held_objects[i]
		if not held_state.is_valid():
			remove_held_object_at(i)
			continue

		held_state.hold_time += delta
		held_state.movement_sway = held_state.movement_sway.lerp(
			get_player_movement_sway(player),
			1.0 - exp(-movement_sway_follow_speed * delta)
		)

		var target_position: Vector3 = formation.get_hold_slot_position(
			i,
			held_objects,
			hold_point,
			camera,
			player
		)
		target_position += held_state.movement_sway + get_float_offset(
			held_state.hold_time,
			i
		)

		move_held_object_toward(held_state.body, target_position, held_state.hold_time)


func remove_held_object_at(index: int) -> void:
	if index < held_objects.size():
		held_objects[index].restore_physics()

	held_objects.remove_at(index)


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


func get_current_hold_follow_speed(hold_time: float) -> float:
	var settle_progress: float = clamp(hold_time / initial_hold_duration, 0.0, 1.0)
	return lerp(initial_hold_follow_speed, hold_follow_speed, settle_progress)


func get_player_movement_sway(player: CharacterBody3D) -> Vector3:
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


func get_raycast_exclusions(player: CharacterBody3D) -> Array[RID]:
	var exclusions: Array[RID] = [player.get_rid()]

	for held_state in held_objects:
		if held_state.is_valid():
			exclusions.append(held_state.body.get_rid())

	return exclusions


func is_body_held(body: RigidBody3D) -> bool:
	for held_state in held_objects:
		if held_state.is_valid() and held_state.body == body:
			return true

	return false
