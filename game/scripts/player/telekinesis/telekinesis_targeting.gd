class_name TelekinesisTargeting
extends RefCounted


static func get_grabbable_body_under_crosshair(
	player: CharacterBody3D,
	camera: Camera3D,
	grab_distance: float,
	max_grabbable_mass: float,
	exclusions: Array[RID]
) -> RigidBody3D:
	var space_state := player.get_world_3d().direct_space_state

	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * grab_distance)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclusions

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
