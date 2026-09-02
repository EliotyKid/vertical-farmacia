class_name PharmacyPlayer
extends CharacterBody3D

@export_category("Movement")
@export_range(1.0, 12.0, 0.1) var walk_speed: float = 4.5
@export_range(1.0, 2.5, 0.1) var sprint_multiplier: float = 1.55
@export_range(5.0, 30.0, 0.5) var acceleration: float = 18.0
@export_range(5.0, 30.0, 0.5) var deceleration: float = 22.0
@export_category("Recovery")
@export var fall_recovery_height: float = -4.0

@export_category("Camera")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(45.0, 89.0, 1.0) var vertical_look_limit: float = 85.0
@export_range(0.0, 0.3, 0.01) var camera_shake_strength: float = 0.11
@export_range(0.1, 5.0, 0.1) var camera_shake_decay: float = 2.4

@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var controls_enabled: bool = true
var _camera_origin: Vector3
var _shake_amount: float = 0.0
var _shake_random := RandomNumberGenerator.new()
var _safe_transform: Transform3D


func _ready() -> void:
	add_to_group("player")
	_camera_origin = camera.position
	_safe_transform = global_transform
	_shake_random.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if global_position.y < fall_recovery_height:
		_recover_from_fall()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if controls_enabled else Vector2.ZERO
	var input_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (transform.basis * input_direction).normalized()
	var current_speed := walk_speed
	if Input.is_action_pressed("sprint"):
		current_speed *= sprint_multiplier

	var target_velocity := world_direction * current_speed
	var rate := acceleration if world_direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	move_and_slide()
	_update_camera_shake(delta)


func apply_knockback(origin: Vector3, strength: float) -> void:
	var direction := global_position - origin
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	velocity.x = direction.x * strength
	velocity.z = direction.z * strength
	velocity.y = strength * 0.65
	add_camera_shake(1.0)


func add_camera_shake(amount: float) -> void:
	_shake_amount = clampf(_shake_amount + amount, 0.0, 1.0)


func _update_camera_shake(delta: float) -> void:
	_shake_amount = move_toward(_shake_amount, 0.0, camera_shake_decay * delta)
	if _shake_amount <= 0.0:
		camera.position = camera.position.lerp(_camera_origin, minf(delta * 20.0, 1.0))
		return
	var offset := Vector3(
		_shake_random.randf_range(-1.0, 1.0),
		_shake_random.randf_range(-1.0, 1.0),
		0.0
	) * camera_shake_strength * _shake_amount
	camera.position = _camera_origin + offset


func _recover_from_fall() -> void:
	global_transform = _safe_transform
	velocity = Vector3.ZERO
	add_camera_shake(0.35)
