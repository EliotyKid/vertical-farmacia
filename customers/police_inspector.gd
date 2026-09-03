class_name PoliceInspector
extends CharacterBody3D

signal inspection_reached(inspector: PoliceInspector)
signal departed(inspector: PoliceInspector)

enum State { ENTERING, INSPECTING, LEAVING }

@export_range(0.5, 6.0, 0.1) var move_speed: float = 2.0
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.2
@export_range(3.0, 30.0, 1.0) var maximum_entry_time: float = 12.0

@onready var state_label: Label3D = %StateLabel

var current_state: State = State.ENTERING
var inspection_position: Vector3
var exit_position: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _entry_remaining: float
var remote_proxy: bool = false
var _remote_position: Vector3
var _remote_yaw: float = 0.0
var _has_network_snapshot: bool = false

func setup(inspection_target: Vector3, exit_target: Vector3) -> void:
	inspection_position = inspection_target
	exit_position = exit_target
	_entry_remaining = maximum_entry_time

func _physics_process(delta: float) -> void:
	if remote_proxy:
		var smoothing := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(_remote_position, smoothing)
		rotation.y = lerp_angle(rotation.y, _remote_yaw, smoothing)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	match current_state:
		State.ENTERING:
			_entry_remaining -= delta
			_move_toward(inspection_position)
			if _horizontal_distance_to(inspection_position) <= arrival_distance or _entry_remaining <= 0.0:
				_begin_inspection()
		State.LEAVING:
			_move_toward(exit_position)
			if _horizontal_distance_to(exit_position) <= arrival_distance:
				departed.emit(self)
				queue_free()
		_:
			_stop_moving()
	move_and_slide()

func finish_inspection(passed: bool) -> void:
	state_label.text = "TUDO CERTO" if passed else "FÁBRICA DESCOBERTA"
	state_label.modulate = Color("71e69a") if passed else Color("ff6969")
	await get_tree().create_timer(2.0).timeout
	current_state = State.LEAVING
	state_label.text = "SAINDO"
	state_label.modulate = Color.WHITE

func _begin_inspection() -> void:
	if current_state != State.ENTERING:
		return
	current_state = State.INSPECTING
	_stop_moving()
	state_label.text = "INSPECIONANDO"
	inspection_reached.emit(self)

func _move_toward(target: Vector3) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= arrival_distance * arrival_distance:
		_stop_moving()
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.18)

func _stop_moving() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _horizontal_distance_to(target: Vector3) -> float:
	var offset := target - global_position
	offset.y = 0.0
	return offset.length()

func get_network_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"yaw": rotation.y,
		"state": int(current_state),
		"label": state_label.text,
		"color": state_label.modulate,
	}

func apply_network_snapshot(data: Dictionary) -> void:
	_remote_position = data.get("position", global_position)
	_remote_yaw = float(data.get("yaw", rotation.y))
	if not _has_network_snapshot:
		global_position = _remote_position
		rotation.y = _remote_yaw
		_has_network_snapshot = true
	current_state = int(data.get("state", int(current_state))) as State
	state_label.text = str(data.get("label", state_label.text))
	state_label.modulate = data.get("color", state_label.modulate)
