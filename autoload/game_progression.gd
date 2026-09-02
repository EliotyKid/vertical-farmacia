class_name GameProgression
extends Node

signal progress_changed(completed_orders: int, abandoned_orders: int, total_revenue: int)
signal demand_level_changed(level: int, label: String)

var completed_orders: int = 0
var abandoned_orders: int = 0
var total_revenue: int = 0
@export_range(0, 100, 1) var complaint_penalty: int = 3
@export_range(1, 50, 1) var busy_threshold: int = 5
@export_range(1, 100, 1) var hectic_threshold: int = 12

func _ready() -> void:
	add_to_group("game_progression")
	call_deferred("_connect_spawner")
	progress_changed.emit(completed_orders, abandoned_orders, total_revenue)

func _connect_spawner() -> void:
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner == null:
		push_warning("GameProgression não encontrou o CustomerSpawner.")
		return
	spawner.customer_spawned.connect(_on_customer_spawned)
	if spawner.active_customer != null:
		_on_customer_spawned(spawner.active_customer)
	_update_demand(spawner)

func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	if not customer.order_completed.is_connected(_on_order_completed):
		customer.order_completed.connect(_on_order_completed)
	if not customer.order_abandoned.is_connected(_on_order_abandoned):
		customer.order_abandoned.connect(_on_order_abandoned)

func _on_order_completed(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	completed_orders += 1
	total_revenue += order.reward
	_update_demand()
	progress_changed.emit(completed_orders, abandoned_orders, total_revenue)

func _on_order_abandoned(_customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	abandoned_orders += 1
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player != null:
		var wallet := player.get_node_or_null("Wallet") as Wallet
		if wallet != null:
			wallet.remove_money(complaint_penalty)
	progress_changed.emit(completed_orders, abandoned_orders, total_revenue)

func get_demand_level() -> int:
	if completed_orders >= hectic_threshold:
		return 3
	if completed_orders >= busy_threshold:
		return 2
	return 1

func get_demand_label() -> String:
	match get_demand_level():
		2: return "MOVIMENTADO"
		3: return "FRENÉTICO"
		_: return "TRANQUILO"

func restore_progress(saved_completed: int, saved_abandoned: int, saved_revenue: int) -> void:
	completed_orders = maxi(saved_completed, 0)
	abandoned_orders = maxi(saved_abandoned, 0)
	total_revenue = maxi(saved_revenue, 0)
	_update_demand()
	progress_changed.emit(completed_orders, abandoned_orders, total_revenue)

func _update_demand(spawner: CustomerSpawner = null) -> void:
	if spawner == null:
		spawner = get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner == null:
		return
	match get_demand_level():
		1:
			spawner.max_customers = 2
			spawner.respawn_delay = 6.0
		2:
			spawner.max_customers = 3
			spawner.respawn_delay = 4.5
		3:
			spawner.max_customers = 4
			spawner.respawn_delay = 3.0
	demand_level_changed.emit(get_demand_level(), get_demand_label())
