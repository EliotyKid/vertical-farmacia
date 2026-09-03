extends Node

signal game_state_changed(summary: String)

const CUSTOMER_SCENE := preload("res://customers/customer.tscn")

var _session: Node
var _world_state: Node
var _host_wallet: Wallet
var _spawner: CustomerSpawner
var _terminal: SupplierTerminal
var _progression: GameProgression
var _next_customer_id: int = 1
var _customers: Dictionary = {}
var _sync_accumulator: float = 0.0
var _was_host: bool = false

func _ready() -> void:
	_session = get_node_or_null("/root/NetworkSession")
	_world_state = get_node_or_null("/root/NetworkWorldState")
	if _session == null:
		return
	_session.session_started.connect(_on_session_started)
	_session.session_ended.connect(_on_session_ended)
	_session.peer_list_changed.connect(_on_peer_list_changed)

func _process(delta: float) -> void:
	if not _is_active() or not _is_host():
		return
	_sync_accumulator += delta
	if _sync_accumulator < 0.05:
		return
	_sync_accumulator = 0.0
	for customer: PharmacyCustomer in _customers.values():
		_sync_customer.rpc(_serialize_customer(customer))

func request_purchase(catalog_index: int) -> bool:
	if not _is_active():
		return false
	if _is_host():
		_authority_purchase(multiplayer.get_unique_id(), catalog_index)
	else:
		_request_purchase.rpc_id(1, catalog_index)
	return true

func request_customer_delivery(customer_id: int) -> bool:
	if not _is_active() or customer_id <= 0:
		return false
	if _is_host():
		_authority_customer_delivery(multiplayer.get_unique_id(), customer_id)
	else:
		_request_customer_delivery.rpc_id(1, customer_id)
	return true

func get_debug_summary() -> String:
	if not _is_active():
		return "jogo solo"
	var money := _host_wallet.money if _host_wallet != null else 0
	return "estado %s • $%d • clientes %d" % ["host" if _is_host() else "replicado", money, _customers.size()]

@rpc("any_peer", "call_remote", "reliable")
func _request_purchase(catalog_index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_host() and _session.allow_authority_request(sender, &"purchase", 250):
		_authority_purchase(sender, catalog_index)

@rpc("any_peer", "call_remote", "reliable")
func _request_customer_delivery(customer_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_host() and _session.allow_authority_request(sender, &"customer_delivery", 150):
		_authority_customer_delivery(sender, customer_id)

func _authority_purchase(peer_id: int, catalog_index: int) -> void:
	var terminal := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	var player := _find_player(peer_id)
	if terminal == null or player == null or _host_wallet == null:
		return
	if player.global_position.distance_to(terminal.global_position) > 4.0:
		return
	var accepted := terminal.authority_purchase(catalog_index, _host_wallet)
	if peer_id != multiplayer.get_unique_id():
		_purchase_result.rpc_id(peer_id, accepted)

@rpc("authority", "call_remote", "reliable")
func _purchase_result(accepted: bool) -> void:
	var terminal := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if terminal != null:
		terminal.show_network_purchase_result(accepted)

func _authority_customer_delivery(peer_id: int, customer_id: int) -> void:
	var customer := _customers.get(customer_id) as PharmacyCustomer
	var player := _find_player(peer_id)
	if customer == null or player == null or _host_wallet == null:
		return
	if player.global_position.distance_to(customer.global_position) > 3.5:
		return
	var carried := _world_state.get_carried_item(peer_id) as WorldItem if _world_state != null else null
	if carried == null:
		return
	if customer.current_order == null or not customer.current_order.matches(carried):
		customer.authority_reject_item(carried.item_data)
		_customer_rejected.rpc(customer_id, carried.item_data.resource_path)
		return
	if _world_state.authority_consume_carried(peer_id) == null:
		return
	customer.authority_complete_order(_host_wallet)

func _on_session_started(_local_peer_id: int, host: bool) -> void:
	_was_host = host
	_next_customer_id = 1
	_customers.clear()
	_spawner = get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	_terminal = get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	_progression = get_tree().get_first_node_in_group("game_progression") as GameProgression
	var local_player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	_host_wallet = local_player.get_node_or_null("Wallet") as Wallet if local_player != null else null
	if _spawner != null:
		_spawner.set_process(host)
	if host:
		if _host_wallet != null:
			if not _host_wallet.money_changed.is_connected(_on_host_money_changed):
				_host_wallet.money_changed.connect(_on_host_money_changed)
			_broadcast_money(_host_wallet.money, 0)
		if _spawner != null:
			if not _spawner.customer_spawned.is_connected(_on_host_customer_spawned):
				_spawner.customer_spawned.connect(_on_host_customer_spawned)
			for customer: PharmacyCustomer in _spawner.active_customers:
				_on_host_customer_spawned(customer)
		if _terminal != null:
			if not _terminal.delivery_status_changed.is_connected(_on_host_delivery_status_changed):
				_terminal.delivery_status_changed.connect(_on_host_delivery_status_changed)
			_on_host_delivery_status_changed(_terminal.get_delivery_status())
		if _progression != null:
			if not _progression.progress_changed.is_connected(_on_host_progress_changed):
				_progression.progress_changed.connect(_on_host_progress_changed)
			_on_host_progress_changed(_progression.completed_orders, _progression.abandoned_orders, _progression.total_revenue)
	else:
		_clear_client_customers()

func _on_session_ended() -> void:
	if not _was_host:
		_clear_client_customers()
	if _host_wallet != null and _host_wallet.money_changed.is_connected(_on_host_money_changed):
		_host_wallet.money_changed.disconnect(_on_host_money_changed)
	if _spawner != null:
		if _spawner.customer_spawned.is_connected(_on_host_customer_spawned):
			_spawner.customer_spawned.disconnect(_on_host_customer_spawned)
		_spawner.set_process(true)
	if _terminal != null and _terminal.delivery_status_changed.is_connected(_on_host_delivery_status_changed):
		_terminal.delivery_status_changed.disconnect(_on_host_delivery_status_changed)
	if _progression != null and _progression.progress_changed.is_connected(_on_host_progress_changed):
		_progression.progress_changed.disconnect(_on_host_progress_changed)
	_customers.clear()
	_host_wallet = null
	_terminal = null
	_progression = null
	_was_host = false

func _on_host_money_changed(amount: int, difference: int) -> void:
	_broadcast_money(amount, difference)

func _broadcast_money(amount: int, difference: int) -> void:
	_apply_money.rpc(amount, difference)
	game_state_changed.emit("Saldo compartilhado: $%d" % amount)

@rpc("authority", "call_remote", "reliable")
func _apply_money(amount: int, _difference: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var wallet := player.get_node_or_null("Wallet") as Wallet if player != null else null
	if wallet != null:
		wallet.set_money(amount)
	game_state_changed.emit("Saldo compartilhado: $%d" % amount)

func _on_host_delivery_status_changed(status: String) -> void:
	_apply_delivery_status.rpc(status)

@rpc("authority", "call_remote", "reliable")
func _apply_delivery_status(status: String) -> void:
	var terminal := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if terminal != null:
		terminal.apply_network_delivery_status(status)

func _on_host_progress_changed(completed: int, abandoned: int, revenue: int) -> void:
	_apply_progress.rpc(completed, abandoned, revenue)

@rpc("authority", "call_remote", "reliable")
func _apply_progress(completed: int, abandoned: int, revenue: int) -> void:
	var progression := get_tree().get_first_node_in_group("game_progression") as GameProgression
	if progression != null:
		progression.apply_network_progress(completed, abandoned, revenue)

func _on_host_customer_spawned(customer: PharmacyCustomer) -> void:
	if customer.network_customer_id <= 0:
		customer.network_customer_id = _next_customer_id
		_next_customer_id += 1
	_customers[customer.network_customer_id] = customer
	customer.tree_exiting.connect(_on_host_customer_exiting.bind(customer.network_customer_id), CONNECT_ONE_SHOT)
	_spawn_customer.rpc(_serialize_customer(customer))

func _serialize_customer(customer: PharmacyCustomer) -> Dictionary:
	return {
		"id": customer.network_customer_id,
		"item_path": customer.requested_item.resource_path if customer.requested_item != null else "",
		"reward": customer.order_reward,
		"patience_duration": customer.patience_duration,
		"patience_remaining": customer.get_patience_remaining(),
		"archetype": int(customer.archetype),
		"state": int(customer.current_state),
		"position": customer.global_position,
		"yaw": customer.rotation.y,
	}

@rpc("authority", "call_remote", "reliable")
func _spawn_customer(data: Dictionary) -> void:
	var customer_id := int(data.get("id", 0))
	if customer_id <= 0 or _customers.has(customer_id) or _spawner == null:
		return
	var customer := CUSTOMER_SCENE.instantiate() as PharmacyCustomer
	customer.remote_proxy = true
	customer.network_customer_id = customer_id
	var item := load(str(data.get("item_path", ""))) as ItemData
	if item != null:
		customer.configure_order(item)
	customer.order_reward = int(data.get("reward", customer.order_reward))
	customer.configure_archetype(int(data.get("archetype", 0)) as PharmacyCustomer.Archetype, float(data.get("patience_duration", 45.0)))
	get_tree().current_scene.add_child(customer)
	_customers[customer_id] = customer
	_spawner.add_network_customer(customer)
	customer.apply_network_snapshot(data)

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_customer(data: Dictionary) -> void:
	var customer := _customers.get(int(data.get("id", 0))) as PharmacyCustomer
	if customer != null:
		customer.apply_network_snapshot(data)

func _on_host_customer_exiting(customer_id: int) -> void:
	_customers.erase(customer_id)
	if _is_host():
		_despawn_customer.rpc(customer_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_customer(customer_id: int) -> void:
	var customer := _customers.get(customer_id) as PharmacyCustomer
	_customers.erase(customer_id)
	if customer != null:
		_spawner.remove_network_customer(customer)
		customer.queue_free()

@rpc("authority", "call_remote", "reliable")
func _customer_rejected(customer_id: int, item_path: String) -> void:
	var customer := _customers.get(customer_id) as PharmacyCustomer
	var item := load(item_path) as ItemData
	if customer != null and item != null:
		customer.authority_reject_item(item)

func _on_peer_list_changed(peer_ids: Array[int]) -> void:
	if not _is_host():
		return
	for peer_id: int in peer_ids:
		if _host_wallet != null:
			_apply_money.rpc_id(peer_id, _host_wallet.money, 0)
		if _terminal != null:
			_apply_delivery_status.rpc_id(peer_id, _terminal.get_delivery_status())
		if _progression != null:
			_apply_progress.rpc_id(peer_id, _progression.completed_orders, _progression.abandoned_orders, _progression.total_revenue)
		var snapshot: Array[Dictionary] = []
		for customer: PharmacyCustomer in _customers.values():
			snapshot.append(_serialize_customer(customer))
		_receive_customer_snapshot.rpc_id(peer_id, snapshot)

@rpc("authority", "call_remote", "reliable")
func _receive_customer_snapshot(snapshot: Array[Dictionary]) -> void:
	_clear_client_customers()
	for data: Dictionary in snapshot:
		_spawn_customer(data)

func _clear_client_customers() -> void:
	if _spawner == null:
		return
	for customer: PharmacyCustomer in _spawner.active_customers.duplicate():
		_spawner.remove_network_customer(customer)
		customer.queue_free()
	_customers.clear()

func _find_player(peer_id: int) -> PharmacyPlayer:
	for node: Node in get_tree().get_nodes_in_group("network_player"):
		var player := node as PharmacyPlayer
		if player != null and player.network_peer_id == peer_id:
			return player
	return null

func _is_active() -> bool:
	return _session != null and _session._steam_peer != null

func _is_host() -> bool:
	return _is_active() and bool(_session.is_session_host)
