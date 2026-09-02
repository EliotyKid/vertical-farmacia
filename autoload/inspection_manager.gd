class_name InspectionManager
extends Node

signal inspection_status_changed(status: String, urgent: bool)
signal inspection_resolved(passed: bool, fine: int, confiscated: int)

enum State { WAITING, WARNING, ACTIVE }

@export var police_scene: PackedScene
@export_range(10.0, 600.0, 1.0) var first_inspection_delay: float = 75.0
@export_range(30.0, 900.0, 1.0) var inspection_interval: float = 150.0
@export_range(3.0, 30.0, 1.0) var warning_duration: float = 12.0
@export_range(0.0, 1.0, 0.05) var fine_ratio: float = 0.2
@export_range(0, 1000, 1) var minimum_fine: int = 5
@export_range(0, 1000, 1) var maximum_fine: int = 30
@export_range(0.0, 1.0, 0.05) var confiscation_ratio: float = 0.25

var current_state: State = State.WAITING
var _remaining: float
var _last_status: String = ""
var _active_inspector: PoliceInspector

func _ready() -> void:
	add_to_group("inspection_manager")
	_remaining = first_inspection_delay
	_emit_status("Fiscalização tranquila", false)

func _process(delta: float) -> void:
	if current_state == State.ACTIVE:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if current_state == State.WAITING and _remaining <= warning_duration:
		current_state = State.WARNING
	if current_state == State.WARNING:
		_emit_status("POLÍCIA EM %.0fs • FECHE O LABORATÓRIO" % _remaining, true)
	if _remaining <= 0.0:
		_start_inspection()

func _start_inspection() -> void:
	var spawn := get_tree().get_first_node_in_group("police_spawn") as Marker3D
	var target := get_tree().get_first_node_in_group("police_inspection_point") as Marker3D
	var exit := get_tree().get_first_node_in_group("customer_exit") as Marker3D
	if police_scene == null or spawn == null or target == null or exit == null:
		push_warning("InspectionManager não encontrou cena ou marcadores do policial.")
		_remaining = inspection_interval
		current_state = State.WAITING
		return
	current_state = State.ACTIVE
	_active_inspector = police_scene.instantiate() as PoliceInspector
	_active_inspector.setup(target.global_position, exit.global_position)
	get_parent().add_child(_active_inspector)
	_active_inspector.global_position = spawn.global_position
	_active_inspector.inspection_reached.connect(_resolve_inspection)
	_active_inspector.departed.connect(_on_inspector_departed)
	_emit_status("POLÍCIA NA FARMÁCIA", true)

func _resolve_inspection(inspector: PoliceInspector) -> void:
	var door := get_tree().get_first_node_in_group("lab_door") as LabDoor
	var passed := door != null and door.is_lab_hidden()
	var fine := 0
	var confiscated := 0
	if not passed:
		fine = _apply_fine()
		confiscated = _confiscate_ingredients()
		_emit_status("DESCOBERTO • MULTA $%d • %d INGREDIENTES" % [fine, confiscated], true)
	else:
		_emit_status("INSPEÇÃO APROVADA", false)
	inspection_resolved.emit(passed, fine, confiscated)
	inspector.finish_inspection(passed)

func _apply_fine() -> int:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player == null:
		return 0
	var wallet := player.get_node_or_null("Wallet") as Wallet
	if wallet == null:
		return 0
	var desired := clampi(ceili(wallet.money * fine_ratio), minimum_fine, maximum_fine)
	return wallet.remove_money(desired)

func _confiscate_ingredients() -> int:
	var total := 0
	for node: Node in get_tree().get_nodes_in_group("storage_feedback"):
		var shelf := node as PharmacyShelf
		if shelf != null:
			total += shelf.count_category(ItemData.Category.INGREDIENT)
	var target := ceili(total * confiscation_ratio)
	var removed := 0
	for node: Node in get_tree().get_nodes_in_group("storage_feedback"):
		var shelf := node as PharmacyShelf
		if shelf != null and removed < target:
			removed += shelf.confiscate_category(ItemData.Category.INGREDIENT, target - removed)
	return removed

func _on_inspector_departed(_inspector: PoliceInspector) -> void:
	_active_inspector = null
	current_state = State.WAITING
	_remaining = inspection_interval
	_emit_status("Fiscalização tranquila", false)

func _emit_status(status: String, urgent: bool) -> void:
	if status == _last_status:
		return
	_last_status = status
	inspection_status_changed.emit(status, urgent)


func debug_schedule_inspection(seconds: float = 5.0) -> bool:
	if current_state == State.ACTIVE:
		return false
	_remaining = maxf(seconds, 1.0)
	current_state = State.WARNING
	_last_status = ""
	_emit_status("POLÍCIA EM %.0fs • FECHE O LABORATÓRIO" % _remaining, true)
	return true
