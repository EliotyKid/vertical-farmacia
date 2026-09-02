class_name GameSession
extends Node

signal progress_changed(completed_orders: int, target_orders: int)
signal session_won(completed_orders: int)

@export_range(1, 20, 1) var target_orders: int = 2

var completed_orders: int = 0
var is_complete: bool = false


func _ready() -> void:
	add_to_group("game_session")
	call_deferred("_connect_spawner")
	progress_changed.emit(completed_orders, target_orders)


func _connect_spawner() -> void:
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner == null:
		push_warning("GameSession não encontrou o CustomerSpawner.")
		return
	spawner.customer_spawned.connect(_on_customer_spawned)
	if spawner.active_customer != null:
		_on_customer_spawned(spawner.active_customer)


func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	if not customer.order_completed.is_connected(_on_order_completed):
		customer.order_completed.connect(_on_order_completed)


func _on_order_completed(_customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	if is_complete:
		return
	completed_orders += 1
	progress_changed.emit(completed_orders, target_orders)
	if completed_orders >= target_orders:
		_complete_session()


func _complete_session() -> void:
	is_complete = true
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player != null:
		player.controls_enabled = false
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner != null:
		spawner.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session_won.emit(completed_orders)
