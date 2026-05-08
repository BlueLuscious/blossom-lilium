class_name HeldObjectState
extends RefCounted

var body: RigidBody3D
var hold_time: float = 0.0
var movement_sway: Vector3 = Vector3.ZERO
var original_gravity_scale: float
var original_linear_damp: float
var original_angular_damp: float


func _init(held_body: RigidBody3D) -> void:
	body = held_body
	original_gravity_scale = held_body.gravity_scale
	original_linear_damp = held_body.linear_damp
	original_angular_damp = held_body.angular_damp


func is_valid() -> bool:
	return is_instance_valid(body)


func restore_physics() -> void:
	if not is_valid():
		return

	body.gravity_scale = original_gravity_scale
	body.linear_damp = original_linear_damp
	body.angular_damp = original_angular_damp
