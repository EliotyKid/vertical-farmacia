extends Node

var _session: Node
var _world_state: Node
var _sync_accumulator: float = 0.0

func _ready() -> void:
	_session = get_node_or_null("/root/NetworkSession")
	_world_state = get_node_or_null("/root/NetworkWorldState")
	if _session == null:
		return
	_session.session_started.connect(_on_session_started)
	_session.session_ended.connect(_on_session_ended)

func _process(delta: float) -> void:
	if not _is_active() or not _is_host():
		return
	_sync_accumulator += delta
	if _sync_accumulator < 0.05:
		return
	_sync_accumulator = 0.0
	var cauldron := _get_cauldron()
	if cauldron != null:
		_apply_cauldron_snapshot.rpc(cauldron.get_network_snapshot())
	var press := _get_press()
	if press != null:
		_apply_press_snapshot.rpc(press.get_network_snapshot())
	var door := _get_door()
	if door != null:
		_apply_door_snapshot.rpc(door.get_network_snapshot())

func request_cauldron_interaction() -> bool:
	return _request_action(&"cauldron_interact", 0)

func request_stir(direction: int) -> bool:
	return _request_action(&"cauldron_stir", direction)

func request_press_interaction() -> bool:
	return _request_action(&"press_interact", 0)

func request_door_toggle() -> bool:
	return _request_action(&"door_toggle", 0)

func _request_action(action: StringName, value: int) -> bool:
	if not _is_active():
		return false
	if _is_host():
		_authority_action(multiplayer.get_unique_id(), action, value)
	else:
		_request_lab_action.rpc_id(1, action, value)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_lab_action(action: StringName, value: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_host() and _session.allow_authority_request(sender, action, 60):
		_authority_action(sender, action, value)

func _authority_action(peer_id: int, action: StringName, value: int) -> void:
	var player := _find_player(peer_id)
	if player == null:
		return
	match action:
		&"cauldron_interact":
			var cauldron := _get_cauldron()
			if cauldron != null and player.global_position.distance_to(cauldron.global_position) <= cauldron.operation_distance:
				cauldron.network_authority_interact(peer_id, _world_state)
		&"cauldron_stir":
			var cauldron := _get_cauldron()
			if cauldron != null and player.global_position.distance_to(cauldron.global_position) <= cauldron.operation_distance:
				cauldron.network_authority_stir(value)
		&"press_interact":
			var press := _get_press()
			if press != null and player.global_position.distance_to(press.global_position) <= 3.5:
				press.network_authority_interact(peer_id, _world_state)
		&"door_toggle":
			var door := _get_door()
			if door != null and player.global_position.distance_to(door.global_position) <= 4.0:
				door.network_authority_toggle()

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_cauldron_snapshot(data: Dictionary) -> void:
	var cauldron := _get_cauldron()
	if cauldron != null:
		cauldron.apply_network_snapshot(data, _world_state)

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_press_snapshot(data: Dictionary) -> void:
	var press := _get_press()
	if press != null:
		press.apply_network_snapshot(data, _world_state)

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_door_snapshot(data: Dictionary) -> void:
	var door := _get_door()
	if door != null:
		door.apply_network_snapshot(data)

func _on_session_started(_peer_id: int, host: bool) -> void:
	var cauldron := _get_cauldron()
	if cauldron != null:
		cauldron.set_network_proxy(not host)
		if host and not cauldron.explosion_triggered.is_connected(_on_host_explosion):
			cauldron.explosion_triggered.connect(_on_host_explosion)
		if host and not cauldron.stir_performed.is_connected(_on_host_stir):
			cauldron.stir_performed.connect(_on_host_stir)
	var press := _get_press()
	if press != null:
		press.set_process(true)
		if host and not press.press_performed.is_connected(_on_host_press):
			press.press_performed.connect(_on_host_press)

func _on_session_ended() -> void:
	var cauldron := _get_cauldron()
	if cauldron != null:
		cauldron.set_network_proxy(false)
		if cauldron.explosion_triggered.is_connected(_on_host_explosion):
			cauldron.explosion_triggered.disconnect(_on_host_explosion)
		if cauldron.stir_performed.is_connected(_on_host_stir):
			cauldron.stir_performed.disconnect(_on_host_stir)
	var press := _get_press()
	if press != null:
		press.set_process(true)
		if press.press_performed.is_connected(_on_host_press):
			press.press_performed.disconnect(_on_host_press)

func _on_host_explosion(_explosion: CraftingExplosion) -> void:
	_spawn_remote_explosion.rpc()

func _on_host_stir(correct: bool, _stability: float) -> void:
	_apply_remote_stir_feedback.rpc(correct)

@rpc("authority", "call_remote", "reliable")
func _apply_remote_stir_feedback(correct: bool) -> void:
	var cauldron := _get_cauldron()
	if cauldron != null:
		cauldron.apply_network_stir_feedback(correct)

func _on_host_press(current: int, required: int) -> void:
	_apply_remote_press_feedback.rpc(current, required)

@rpc("authority", "call_remote", "reliable")
func _apply_remote_press_feedback(current: int, required: int) -> void:
	var press := _get_press()
	if press != null:
		press.apply_network_press_feedback(current, required)

@rpc("authority", "call_remote", "reliable")
func _spawn_remote_explosion() -> void:
	var cauldron := _get_cauldron()
	if cauldron != null:
		cauldron.spawn_network_explosion()

func _get_cauldron() -> StationInput:
	return get_tree().get_first_node_in_group("crafting_station") as StationInput

func _get_press() -> PressStation:
	return get_tree().get_first_node_in_group("secondary_station") as PressStation

func _get_door() -> LabDoor:
	return get_tree().get_first_node_in_group("lab_door") as LabDoor

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
