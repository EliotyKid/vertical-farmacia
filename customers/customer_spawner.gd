class_name CustomerSpawner
extends Node3D

signal customer_spawned(customer: PharmacyCustomer)
signal active_customer_changed(customer: PharmacyCustomer)

@export var customer_scene: PackedScene
@export var order_sequence: Array[ItemData] = []
@export_range(0.0, 30.0, 0.5) var initial_delay: float = 2.0
@export_range(1.0, 60.0, 0.5) var respawn_delay: float = 5.0

var active_customer: PharmacyCustomer
var _spawn_timer: float
var _next_order_index: int = 0


func _ready() -> void:
	add_to_group("customer_spawner")
	_spawn_timer = initial_delay


func _process(delta: float) -> void:
	if active_customer != null:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_customer()


func _spawn_customer() -> void:
	var counter_target := get_tree().get_first_node_in_group("customer_counter_target") as Marker3D
	var exit_target := get_tree().get_first_node_in_group("customer_exit") as Marker3D
	if customer_scene == null or counter_target == null or exit_target == null:
		push_warning("CustomerSpawner não encontrou cena ou pontos de navegação.")
		_spawn_timer = respawn_delay
		return
	active_customer = customer_scene.instantiate() as PharmacyCustomer
	if not order_sequence.is_empty():
		var requested_item := order_sequence[_next_order_index % order_sequence.size()]
		active_customer.configure_order(requested_item)
		_next_order_index += 1
	active_customer.setup(counter_target.global_position, exit_target.global_position)
	get_parent().add_child(active_customer)
	active_customer.global_position = global_position
	active_customer.departed.connect(_on_customer_departed)
	customer_spawned.emit(active_customer)
	active_customer_changed.emit(active_customer)


func _on_customer_departed(customer: PharmacyCustomer) -> void:
	if customer != active_customer:
		return
	active_customer = null
	_spawn_timer = respawn_delay
	active_customer_changed.emit(null)
