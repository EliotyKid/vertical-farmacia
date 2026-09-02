class_name GameProgression
extends Node

signal progress_changed(completed_orders: int, total_revenue: int)

var completed_orders: int = 0
var total_revenue: int = 0

func _ready() -> void:
	add_to_group("game_progression")
	call_deferred("_connect_spawner")
	progress_changed.emit(completed_orders, total_revenue)

func _connect_spawner() -> void:
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner == null:
		push_warning("GameProgression não encontrou o CustomerSpawner.")
		return
	spawner.customer_spawned.connect(_on_customer_spawned)
	if spawner.active_customer != null:
		_on_customer_spawned(spawner.active_customer)

func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	if not customer.order_completed.is_connected(_on_order_completed):
		customer.order_completed.connect(_on_order_completed)

func _on_order_completed(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	completed_orders += 1
	total_revenue += order.reward
	progress_changed.emit(completed_orders, total_revenue)
