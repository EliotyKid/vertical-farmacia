class_name CustomerSpawner
extends Node3D

signal customer_spawned(customer: PharmacyCustomer)
signal active_customer_changed(customer: PharmacyCustomer)
signal customer_departed(customer: PharmacyCustomer)
signal opening_countdown_changed(seconds_remaining: int)

@export var customer_scene: PackedScene
@export var order_sequence: Array[ItemData] = []
@export_range(0.0, 120.0, 1.0) var initial_delay: float = 30.0
@export_range(1.0, 60.0, 0.5) var respawn_delay: float = 5.0
@export_range(1, 8, 1) var max_customers: int = 4
@export_category("Customer archetypes")
@export_range(5.0, 180.0, 1.0) var common_patience: float = 45.0
@export_range(5.0, 180.0, 1.0) var rushed_patience: float = 28.0
@export_range(5.0, 180.0, 1.0) var special_patience: float = 65.0
@export_range(2, 10, 1) var rushed_customer_frequency: int = 3

var active_customer: PharmacyCustomer
var active_customers: Array[PharmacyCustomer] = []
var _spawn_timer: float
var _next_order_index: int = 0
var _has_spawned_first_customer: bool = false
var _last_countdown_second: int = -1


func _ready() -> void:
	add_to_group("customer_spawner")
	_spawn_timer = initial_delay
	_emit_opening_countdown()


func _process(delta: float) -> void:
	if active_customers.size() >= max_customers:
		return
	_spawn_timer -= delta
	if not _has_spawned_first_customer:
		_emit_opening_countdown()
	if _spawn_timer <= 0.0:
		_spawn_customer()


func _spawn_customer() -> void:
	var queue_positions := _get_queue_positions()
	var exit_target := get_tree().get_first_node_in_group("customer_exit") as Marker3D
	if customer_scene == null or queue_positions.is_empty() or exit_target == null:
		push_warning("CustomerSpawner não encontrou cena ou pontos de navegação.")
		_spawn_timer = respawn_delay
		return
	var customer := customer_scene.instantiate() as PharmacyCustomer
	if not order_sequence.is_empty():
		var requested_item := order_sequence[_next_order_index % order_sequence.size()]
		customer.configure_order(requested_item)
		var customer_number := _next_order_index + 1
		if requested_item.category == ItemData.Category.CRAFTED_PRODUCT:
			customer.configure_archetype(PharmacyCustomer.Archetype.SPECIAL, special_patience)
		elif customer_number % rushed_customer_frequency == 0:
			customer.configure_archetype(PharmacyCustomer.Archetype.RUSHED, rushed_patience)
		else:
			customer.configure_archetype(PharmacyCustomer.Archetype.COMMON, common_patience)
		_next_order_index += 1
	var queue_index := mini(active_customers.size(), queue_positions.size() - 1)
	customer.setup(queue_positions[queue_index].global_position, exit_target.global_position)
	get_parent().add_child(customer)
	customer.global_position = global_position
	active_customers.append(customer)
	_has_spawned_first_customer = true
	active_customer = active_customers[0]
	customer.departed.connect(_on_customer_departed)
	customer_spawned.emit(customer)
	active_customer_changed.emit(active_customer)
	_spawn_timer = respawn_delay
	opening_countdown_changed.emit(0)


func _on_customer_departed(customer: PharmacyCustomer) -> void:
	active_customers.erase(customer)
	active_customer = active_customers[0] if not active_customers.is_empty() else null
	_reassign_queue_positions()
	_spawn_timer = respawn_delay
	customer_departed.emit(customer)
	active_customer_changed.emit(active_customer)


func _get_queue_positions() -> Array[Marker3D]:
	var positions: Array[Marker3D] = []
	for node: Node in get_tree().get_nodes_in_group("customer_queue_position"):
		var marker := node as Marker3D
		if marker != null:
			positions.append(marker)
	var counter := get_tree().get_first_node_in_group("customer_counter_target") as Marker3D
	if counter != null:
		positions.sort_custom(
			func(a: Marker3D, b: Marker3D) -> bool:
				return a.global_position.distance_squared_to(counter.global_position) < b.global_position.distance_squared_to(counter.global_position)
		)
	return positions


func get_opening_countdown() -> int:
	return maxi(ceili(_spawn_timer), 0) if not _has_spawned_first_customer else 0


func _reassign_queue_positions() -> void:
	var positions := _get_queue_positions()
	for index: int in range(mini(active_customers.size(), positions.size())):
		active_customers[index].update_queue_position(positions[index].global_position)


func _emit_opening_countdown() -> void:
	var seconds := maxi(ceili(_spawn_timer), 0)
	if seconds == _last_countdown_second:
		return
	_last_countdown_second = seconds
	opening_countdown_changed.emit(seconds)


func debug_spawn_customer() -> bool:
	if active_customers.size() >= max_customers:
		return false
	_spawn_customer()
	return true

func add_network_customer(customer: PharmacyCustomer) -> void:
	if customer == null or active_customers.has(customer):
		return
	active_customers.append(customer)
	active_customer = active_customers[0]
	customer_spawned.emit(customer)
	active_customer_changed.emit(active_customer)

func remove_network_customer(customer: PharmacyCustomer) -> void:
	active_customers.erase(customer)
	active_customer = active_customers[0] if not active_customers.is_empty() else null
	customer_departed.emit(customer)
	active_customer_changed.emit(active_customer)
