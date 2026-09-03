class_name PharmacyPlayer
extends CharacterBody3D

@export_category("Movement")
@export_range(1.0, 12.0, 0.1) var walk_speed: float = 4.5
@export_range(1.0, 2.5, 0.1) var sprint_multiplier: float = 1.55
@export_range(5.0, 30.0, 0.5) var acceleration: float = 18.0
@export_range(5.0, 30.0, 0.5) var deceleration: float = 22.0
@export_category("Recovery")
@export var fall_recovery_height: float = -4.0
@export_category("Network")
@export var locally_controlled: bool = true
@export_range(0.02, 0.2, 0.01) var network_send_interval: float = 0.067
@export_range(1.0, 30.0, 0.5) var remote_interpolation_speed: float = 12.0

@export_category("Camera")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(45.0, 89.0, 1.0) var vertical_look_limit: float = 85.0
@export_range(0.0, 0.3, 0.01) var camera_shake_strength: float = 0.11
@export_range(0.1, 5.0, 0.1) var camera_shake_decay: float = 2.4

@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var body_mesh: MeshInstance3D = %BodyMesh
@onready var name_label: Label3D = %NetworkNameLabel
@onready var interaction_controller: Node = %InteractionController
@onready var carry_controller: Node = %CarryController

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var controls_enabled: bool = true
var _camera_origin: Vector3
var _shake_amount: float = 0.0
var _shake_random := RandomNumberGenerator.new()
var _safe_transform: Transform3D
var network_peer_id: int = 0
var is_network_session_active: bool = false
var network_send_accumulator: float = 0.0
var _remote_position: Vector3
var _remote_yaw: float = 0.0
var _remote_head_pitch: float = 0.0
var _network_display_name: String = "Jogador remoto"


func _ready() -> void:
	add_to_group("network_player")
	if locally_controlled:
		add_to_group("player")
	_camera_origin = camera.position
	_safe_transform = global_transform
	_shake_random.randomize()
	camera.current = locally_controlled
	name_label.visible = not locally_controlled
	name_label.text = _network_display_name
	interaction_controller.process_mode = Node.PROCESS_MODE_INHERIT if locally_controlled else Node.PROCESS_MODE_DISABLED
	carry_controller.process_mode = Node.PROCESS_MODE_INHERIT if locally_controlled else Node.PROCESS_MODE_DISABLED
	if locally_controlled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_apply_remote_appearance()
		_remote_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if not locally_controlled or not controls_enabled:
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
	if not locally_controlled:
		global_position = global_position.lerp(_remote_position, minf(delta * remote_interpolation_speed, 1.0))
		rotation.y = lerp_angle(rotation.y, _remote_yaw, minf(delta * remote_interpolation_speed, 1.0))
		head.rotation.x = lerp_angle(head.rotation.x, _remote_head_pitch, minf(delta * remote_interpolation_speed, 1.0))
		return
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

func configure_network_player(peer_id: int, local: bool, display_name: String) -> void:
	network_peer_id = peer_id
	is_network_session_active = true
	locally_controlled = local
	set_multiplayer_authority(peer_id)
	if is_node_ready():
		camera.current = local
		name_label.visible = not local
		interaction_controller.process_mode = Node.PROCESS_MODE_INHERIT if local else Node.PROCESS_MODE_DISABLED
		carry_controller.process_mode = Node.PROCESS_MODE_INHERIT if local else Node.PROCESS_MODE_DISABLED
	set_network_display_name(display_name)

func configure_solo_player() -> void:
	network_peer_id = 0
	is_network_session_active = false
	locally_controlled = true
	set_multiplayer_authority(1)
	if is_node_ready():
		set_network_color(Color("2e5985"))
		camera.current = true
		name_label.visible = false
		interaction_controller.process_mode = Node.PROCESS_MODE_INHERIT
		carry_controller.process_mode = Node.PROCESS_MODE_INHERIT

func set_network_display_name(display_name: String) -> void:
	_network_display_name = display_name
	if is_node_ready():
		name_label.text = display_name

func set_network_color(color: Color) -> void:
	if not is_node_ready():
		return
	var source := body_mesh.material_override as StandardMaterial3D
	var material := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
	material.albedo_color = color
	body_mesh.material_override = material

func set_remote_network_state(position: Vector3, yaw: float, head_pitch: float) -> void:
	_remote_position = position
	_remote_yaw = yaw
	_remote_head_pitch = head_pitch

func set_safe_transform(value: Transform3D) -> void:
	_safe_transform = value

func get_hold_transform() -> Transform3D:
	var marker := get_node_or_null("Head/Camera3D/HoldMarker") as Marker3D
	return marker.global_transform if marker != null else global_transform

func apply_network_carried_item(item: WorldItem) -> void:
	var carry := get_node_or_null("CarryController") as CarryController
	if carry != null:
		carry.apply_network_item(item)

func clear_network_carried_item(item: WorldItem) -> void:
	var carry := get_node_or_null("CarryController") as CarryController
	if carry != null:
		carry.clear_network_item(item)

func _apply_remote_appearance() -> void:
	var material := body_mesh.material_override.duplicate() as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(0.88, 0.38, 0.2, 1.0)
		body_mesh.material_override = material
