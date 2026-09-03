extends Node

const POLICE_SCENE := preload("res://customers/police_inspector.tscn")

var _session: Node
var _world_state: Node
var _inspection: InspectionManager
var _upgrades: UpgradeTerminal
var _wallet: Wallet
var _remote_inspector: PoliceInspector
var _sync_accumulator: float = 0.0
var _local_upgrade_ids: Array[StringName] = []
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
	if not _is_active() or not _is_host() or _inspection == null:
		return
	_sync_accumulator += delta
	if _sync_accumulator < 0.05:
		return
	_sync_accumulator = 0.0
	_apply_inspection_snapshot.rpc(_inspection.get_network_snapshot())

func request_upgrade(upgrade_id: StringName) -> bool:
	if not _is_active():
		return false
	if _is_host():
		_authority_upgrade(multiplayer.get_unique_id(), upgrade_id)
	else:
		_request_upgrade.rpc_id(1, upgrade_id)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_upgrade(upgrade_id: StringName) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_host() and _session.allow_authority_request(sender, &"upgrade", 250):
		_authority_upgrade(sender, upgrade_id)

func _authority_upgrade(peer_id: int, upgrade_id: StringName) -> void:
	var player := _find_player(peer_id)
	if player == null or _upgrades == null or _wallet == null:
		return
	if player.global_position.distance_to(_upgrades.global_position) > 4.0:
		return
	var accepted := _upgrades.authority_purchase_upgrade(upgrade_id, _wallet)
	if accepted:
		_broadcast_upgrades()
	if peer_id != multiplayer.get_unique_id():
		_upgrade_result.rpc_id(peer_id, accepted)

@rpc("authority", "call_remote", "reliable")
func _upgrade_result(accepted: bool) -> void:
	if _upgrades != null:
		_upgrades.show_network_upgrade_result(accepted)

func _broadcast_upgrades(peer_id: int = 0) -> void:
	if _upgrades == null:
		return
	var ids: Array[StringName] = []
	for value: String in _upgrades.get_purchased_upgrade_ids():
		ids.append(StringName(value))
	if peer_id > 0:
		_apply_upgrade_snapshot.rpc_id(peer_id, ids)
	else:
		_apply_upgrade_snapshot.rpc(ids)

@rpc("authority", "call_remote", "reliable")
func _apply_upgrade_snapshot(ids: Array[StringName]) -> void:
	if _upgrades != null:
		_upgrades.apply_network_upgrades(ids)

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_inspection_snapshot(data: Dictionary) -> void:
	if _inspection == null:
		return
	_inspection.apply_network_snapshot(data)
	var inspector_data := data.get("inspector", {}) as Dictionary
	if inspector_data.is_empty():
		if is_instance_valid(_remote_inspector):
			_remote_inspector.queue_free()
		_remote_inspector = null
		_inspection.set_network_inspector(null)
		return
	if not is_instance_valid(_remote_inspector):
		_remote_inspector = POLICE_SCENE.instantiate() as PoliceInspector
		_remote_inspector.remote_proxy = true
		get_tree().current_scene.add_child(_remote_inspector)
		_inspection.set_network_inspector(_remote_inspector)
	_remote_inspector.apply_network_snapshot(inspector_data)

func _on_session_started(_peer_id: int, host: bool) -> void:
	_was_host = host
	_inspection = get_tree().get_first_node_in_group("inspection_manager") as InspectionManager
	_upgrades = get_tree().get_first_node_in_group("upgrade_terminal") as UpgradeTerminal
	_local_upgrade_ids.clear()
	if _upgrades != null:
		for value: String in _upgrades.get_purchased_upgrade_ids():
			_local_upgrade_ids.append(StringName(value))
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	_wallet = player.get_node_or_null("Wallet") as Wallet if player != null else null
	if _inspection != null:
		_inspection.set_process(host)
	if host and _upgrades != null and not _upgrades.upgrade_purchased.is_connected(_on_host_upgrade_purchased):
		_upgrades.upgrade_purchased.connect(_on_host_upgrade_purchased)

func _on_session_ended() -> void:
	if _inspection != null:
		_inspection.set_process(true)
		if not _is_host() and is_instance_valid(_remote_inspector):
			_remote_inspector.queue_free()
	if _upgrades != null and _upgrades.upgrade_purchased.is_connected(_on_host_upgrade_purchased):
		_upgrades.upgrade_purchased.disconnect(_on_host_upgrade_purchased)
	if _upgrades != null and not _was_host:
		_upgrades.set_exact_upgrades(_local_upgrade_ids)
		var save_manager := get_tree().get_first_node_in_group("save_manager") as PharmacySaveManager
		if save_manager != null:
			save_manager.restore_local_save_after_network()
	_remote_inspector = null
	_inspection = null
	_upgrades = null
	_wallet = null
	_local_upgrade_ids.clear()
	_was_host = false

func _on_host_upgrade_purchased(_upgrade_id: StringName) -> void:
	_broadcast_upgrades()

func _on_peer_list_changed(peer_ids: Array[int]) -> void:
	if not _is_host():
		return
	for peer_id: int in peer_ids:
		_broadcast_upgrades(peer_id)
		if _inspection != null:
			_apply_inspection_snapshot.rpc_id(peer_id, _inspection.get_network_snapshot())

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
