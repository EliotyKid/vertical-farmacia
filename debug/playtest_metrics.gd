class_name PlaytestMetrics
extends Node

var elapsed_time: float = 0.0
var completed_orders: int = 0
var abandoned_orders: int = 0
var total_wait_time: float = 0.0
var stock_spending: int = 0
var explosions: int = 0
var inspections_passed: int = 0
var inspections_failed: int = 0
var upgrades_purchased: int = 0
var first_upgrade_time: float = -1.0
var distance_walked: float = 0.0

var _player: PharmacyPlayer
var _last_player_position: Vector3

func _ready() -> void:
	add_to_group("playtest_metrics")
	call_deferred("_connect_sources")

func _process(delta: float) -> void:
	elapsed_time += delta
	if _player == null or not is_instance_valid(_player):
		return
	var movement := _player.global_position.distance_to(_last_player_position)
	if movement < 2.0:
		distance_walked += movement
	_last_player_position = _player.global_position

func _connect_sources() -> void:
	_player = get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if _player != null:
		_last_player_position = _player.global_position
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner != null:
		spawner.customer_spawned.connect(_on_customer_spawned)
		for customer: PharmacyCustomer in spawner.active_customers:
			_on_customer_spawned(customer)
	var supplier := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if supplier != null:
		supplier.item_purchased.connect(_on_item_purchased)
	var station := get_tree().get_first_node_in_group("crafting_station") as StationInput
	if station != null:
		station.craft_failed.connect(_on_craft_failed)
	var inspection := get_tree().get_first_node_in_group("inspection_manager") as InspectionManager
	if inspection != null:
		inspection.inspection_resolved.connect(_on_inspection_resolved)
	var upgrades := get_tree().get_first_node_in_group("upgrade_terminal") as UpgradeTerminal
	if upgrades != null:
		upgrades.upgrade_purchased.connect(_on_upgrade_purchased)

func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	customer.order_completed.connect(_on_order_completed)
	customer.order_abandoned.connect(_on_order_abandoned)

func _on_order_completed(customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	completed_orders += 1
	total_wait_time += customer.get_order_wait_time()

func _on_order_abandoned(customer: PharmacyCustomer, _order: CustomerOrder) -> void:
	abandoned_orders += 1
	total_wait_time += customer.get_order_wait_time()

func _on_item_purchased(_item: ItemData, price: int) -> void:
	stock_spending += price

func _on_craft_failed() -> void:
	explosions += 1

func _on_inspection_resolved(passed: bool, _fine: int, _confiscated: int) -> void:
	if passed:
		inspections_passed += 1
	else:
		inspections_failed += 1

func _on_upgrade_purchased(_upgrade_id: StringName) -> void:
	upgrades_purchased += 1
	if first_upgrade_time < 0.0:
		first_upgrade_time = elapsed_time

func get_average_wait_time() -> float:
	var resolved := completed_orders + abandoned_orders
	return total_wait_time / float(resolved) if resolved > 0 else 0.0

func get_debug_summary() -> String:
	var first_upgrade := "--" if first_upgrade_time < 0.0 else _format_time(first_upgrade_time)
	return "TEMPO %s • DIST %.0fm\nPEDIDOS %d/%d • ESPERA %.1fs\nCOMPRAS $%d • EXPLOSÕES %d\nPOLÍCIA %d OK / %d FALHA\nMELHORIAS %d • PRIMEIRA %s" % [
		_format_time(elapsed_time), distance_walked,
		completed_orders, abandoned_orders, get_average_wait_time(),
		stock_spending, explosions,
		inspections_passed, inspections_failed,
		upgrades_purchased, first_upgrade,
	]

func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(fmod(seconds, 60.0))]
