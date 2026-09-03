class_name LabDoor
extends Node3D

signal lab_visibility_changed(is_hidden: bool)

enum State {
	OPEN,
	CLOSING,
	CLOSED,
	OPENING,
}

@export var starts_closed: bool = false
@export var open_offset: Vector3 = Vector3(-4.7, 0.0, 0.0)
@export_range(0.1, 3.0, 0.05) var movement_duration: float = 0.65

@onready var door_body: AnimatableBody3D = %DoorBody
@onready var interactables: Array[InteractableComponent] = [$OutsideControlPanel/Interactable, $InsideControlPanel/Interactable]
@onready var status_labels: Array[Label3D] = [$OutsideControlPanel/StatusLabel, $InsideControlPanel/StatusLabel]

var current_state: State = State.OPEN
var _closed_position: Vector3
var _movement_tween: Tween
var _network_target_position: Vector3
var _network_proxy: bool = false
var _has_network_snapshot: bool = false

func _process(delta: float) -> void:
	if not _network_proxy:
		return
	var smoothing := 1.0 - exp(-22.0 * delta)
	door_body.position = door_body.position.lerp(_network_target_position, smoothing)

func _ready() -> void:
	add_to_group("lab_door")
	_closed_position = door_body.position
	for interactable: InteractableComponent in interactables:
		interactable.interacted.connect(_on_interacted)
	if starts_closed:
		current_state = State.CLOSED
	else:
		current_state = State.OPEN
		door_body.position = _closed_position + open_offset
	_update_visual_state()
	lab_visibility_changed.emit(is_lab_hidden())

func can_player_interact(_player: PharmacyPlayer) -> bool:
	return current_state == State.OPEN or current_state == State.CLOSED

func get_contextual_interaction_text() -> String:
	match current_state:
		State.OPEN:
			return "Fechar porta do laboratório"
		State.CLOSED:
			return "Abrir porta do laboratório"
		State.CLOSING:
			return "Fechando laboratório..."
		_:
			return "Abrindo laboratório..."

func is_lab_hidden() -> bool:
	return current_state == State.CLOSED

func _on_interacted(_player: PharmacyPlayer) -> void:
	var network_lab := get_node_or_null("/root/NetworkLabState")
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_lab != null and network_session != null and network_session._steam_peer != null:
		network_lab.request_door_toggle()
		return
	network_authority_toggle()

func network_authority_toggle() -> void:
	if current_state == State.OPEN:
		_move_door(true)
	elif current_state == State.CLOSED:
		_move_door(false)

func get_network_snapshot() -> Dictionary:
	return {"state": int(current_state), "position": door_body.position}

func apply_network_snapshot(data: Dictionary) -> void:
	if not _network_proxy:
		_network_target_position = door_body.position
	_network_proxy = true
	current_state = int(data.get("state", int(current_state))) as State
	_network_target_position = data.get("position", door_body.position)
	if not _has_network_snapshot:
		door_body.position = _network_target_position
		_has_network_snapshot = true
	_set_panels_enabled(current_state == State.OPEN or current_state == State.CLOSED)
	_update_visual_state()

func _move_door(close_door: bool) -> void:
	_network_proxy = false
	if _movement_tween != null and _movement_tween.is_valid():
		_movement_tween.kill()
	current_state = State.CLOSING if close_door else State.OPENING
	_set_panels_enabled(false)
	_update_visual_state()
	var destination := _closed_position if close_door else _closed_position + open_offset
	_movement_tween = create_tween()
	_movement_tween.tween_property(door_body, "position", destination, movement_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _movement_tween.finished
	current_state = State.CLOSED if close_door else State.OPEN
	_set_panels_enabled(true)
	_update_visual_state()
	lab_visibility_changed.emit(is_lab_hidden())

func _update_visual_state() -> void:
	var text := ""
	var color := Color.WHITE
	match current_state:
		State.OPEN:
			text = "LAB ABERTO"
			color = Color("ff806b")
		State.CLOSED:
			text = "LAB OCULTO"
			color = Color("69e596")
		State.CLOSING:
			text = "OCULTANDO..."
			color = Color("ffd36a")
		State.OPENING:
			text = "ABRINDO..."
			color = Color("ffd36a")
	for label: Label3D in status_labels:
		label.text = text
		label.modulate = color


func _set_panels_enabled(value: bool) -> void:
	for interactable: InteractableComponent in interactables:
		interactable.enabled = value
