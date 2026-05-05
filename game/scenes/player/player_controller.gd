extends CharacterBody3D


@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 12.0
@export var rotation_speed: float = 8.0

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -45.0
@export var max_pitch: float = 35.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera

var camera_pitch: float = 0.0


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	if input_dir == Vector2.ZERO:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		return

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	forward.y = 0
	right.y = 0

	forward = forward.normalized()
	right = right.normalized()

	var direction := (forward * -input_dir.y + right * input_dir.x).normalized()

	# Movimiento
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

		camera_pivot.rotation.x = camera_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
