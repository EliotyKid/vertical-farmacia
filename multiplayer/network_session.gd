extends Node

signal session_state_changed(status: String)
signal peer_list_changed(peer_ids: Array[int])
signal rpc_probe_received(peer_id: int, persona_name: String)
signal session_started(local_peer_id: int, host: bool)
signal session_ended
signal peer_identity_changed(peer_id: int, persona_name: String)
signal player_state_received(peer_id: int, position: Vector3, yaw: float, head_pitch: float)

const PROTOCOL_VERSION := "farmacia-coop-mp10-4p"

var status_message: String = "Rede inativa • modo solo"
var is_session_host: bool = false
var connected_peer_ids: Array[int] = []
var peer_names: Dictionary = {}

var _lobby_manager: Node
var _steam_bootstrap: Node
var _steam_peer: MultiplayerPeer
var _open_menu_after_recovery: bool = false
var _latency_accumulator: float = 0.0
var _peer_rtt_ms: Dictionary = {}
var _request_timestamps: Dictionary = {}
var _accepted_requests: int = 0
var _rejected_requests: int = 0

func _process(delta: float) -> void:
	if _steam_peer == null:
		return
	_latency_accumulator += delta
	if _latency_accumulator < 1.0:
		return
	_latency_accumulator = 0.0
	var sent_at := Time.get_ticks_msec()
	for peer_id: int in connected_peer_ids:
		_latency_ping.rpc_id(peer_id, sent_at)

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_lobby_manager = get_node_or_null("/root/SteamLobbyManager")
	_steam_bootstrap = get_node_or_null("/root/SteamBootstrap")
	if _lobby_manager == null:
		_set_status("SteamLobbyManager ausente • modo solo")
		return
	_lobby_manager.lobby_connection_ready.connect(_on_lobby_connection_ready)
	_lobby_manager.lobby_left.connect(_on_lobby_left)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_from_lobby(lobby_id: int, host: bool) -> bool:
	shutdown(false)
	_accepted_requests = 0
	_rejected_requests = 0
	_latency_accumulator = 0.0
	if lobby_id <= 0:
		_set_status("Lobby inválido • conexão não iniciada")
		return false
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		_set_status("SteamMultiplayerPeer indisponível • modo solo")
		return false
	var peer_object: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if not peer_object is MultiplayerPeer:
		_set_status("SteamMultiplayerPeer incompatível • modo solo")
		return false
	_steam_peer = peer_object as MultiplayerPeer
	var result: int
	if host:
		result = int(peer_object.call("host_with_lobby", lobby_id))
	else:
		result = int(peer_object.call("connect_to_lobby", lobby_id))
	if result != OK:
		_steam_peer = null
		_set_status("Falha ao abrir transporte Steam • erro %d" % result)
		return false
	is_session_host = host
	multiplayer.multiplayer_peer = _steam_peer
	peer_names[multiplayer.get_unique_id()] = _get_persona_name()
	session_started.emit(multiplayer.get_unique_id(), host)
	if host:
		_set_status("Host P2P ativo • aguardando conexão do convidado")
	else:
		_set_status("Conectando ao host pela Steam...")
	return true

func shutdown(update_status: bool = true) -> void:
	var had_session := _steam_peer != null
	var was_host := is_session_host
	if had_session and was_host:
		var world_state := get_node_or_null("/root/NetworkWorldState")
		if world_state != null:
			world_state.prepare_host_shutdown()
	if _steam_peer != null:
		_steam_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_steam_peer = null
	is_session_host = false
	connected_peer_ids.clear()
	peer_names.clear()
	_peer_rtt_ms.clear()
	_request_timestamps.clear()
	peer_list_changed.emit(connected_peer_ids)
	if had_session:
		session_ended.emit()
		if not was_host:
			get_tree().call_deferred("reload_current_scene")
	if update_status:
		_set_status("Rede encerrada • modo solo")

func get_debug_summary() -> String:
	var role := "host" if is_session_host else "cliente"
	if _steam_peer == null:
		return status_message
	return "%s • peer %d • %s • remotos %d\n%s" % [
		status_message,
		multiplayer.get_unique_id(),
		role,
		connected_peer_ids.size(),
		get_quality_summary(),
	]

func get_quality_summary() -> String:
	var samples: Array[int] = []
	for value: Variant in _peer_rtt_ms.values():
		samples.append(int(value))
	var average := 0
	var maximum := 0
	for sample: int in samples:
		average += sample
		maximum = maxi(maximum, sample)
	if not samples.is_empty():
		average /= samples.size()
	return "RTT %s • RPC aceitos %d • limitados %d" % [
		("%dms média / %dms máx" % [average, maximum]) if not samples.is_empty() else "aguardando",
		_accepted_requests,
		_rejected_requests,
	]

func allow_authority_request(peer_id: int, channel: StringName, minimum_interval_ms: int = 75) -> bool:
	if not is_session_host or peer_id <= 0 or not connected_peer_ids.has(peer_id):
		_rejected_requests += 1
		return false
	var key := "%d:%s" % [peer_id, channel]
	var now := Time.get_ticks_msec()
	var previous := int(_request_timestamps.get(key, 0))
	if previous > 0 and now - previous < minimum_interval_ms:
		_rejected_requests += 1
		return false
	_request_timestamps[key] = now
	_accepted_requests += 1
	return true

func consume_recovery_menu_request() -> bool:
	var requested := _open_menu_after_recovery
	_open_menu_after_recovery = false
	return requested

func _on_lobby_connection_ready(lobby_id: int, host: bool) -> void:
	start_from_lobby(lobby_id, host)

func _on_lobby_left() -> void:
	shutdown()

func _on_peer_connected(peer_id: int) -> void:
	if not connected_peer_ids.has(peer_id):
		connected_peer_ids.append(peer_id)
	peer_list_changed.emit(connected_peer_ids)
	_set_status("Peer conectado • RPC de teste enviado")
	_send_probe.rpc_id(peer_id, PROTOCOL_VERSION, _get_persona_name())

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peer_ids.erase(peer_id)
	peer_names.erase(peer_id)
	_peer_rtt_ms.erase(peer_id)
	for key: Variant in _request_timestamps.keys():
		if str(key).begins_with("%d:" % peer_id):
			_request_timestamps.erase(key)
	peer_list_changed.emit(connected_peer_ids)
	_set_status("Peer %d desconectou" % peer_id)

func _on_connected_to_server() -> void:
	_set_status("Transporte Steam conectado ao host")

func _on_connection_failed() -> void:
	if _lobby_manager != null:
		_lobby_manager.handle_transport_disconnected("Falha ao conectar ao host")
	shutdown(false)
	_set_status("Falha ao conectar ao host • modo solo restaurado")

func _on_server_disconnected() -> void:
	_open_menu_after_recovery = true
	if _lobby_manager != null:
		_lobby_manager.handle_transport_disconnected("Host desconectou")
	shutdown(false)
	_set_status("Host desconectou • modo solo restaurado")

@rpc("any_peer", "call_remote", "unreliable")
func _latency_ping(sent_at: int) -> void:
	_latency_pong.rpc_id(multiplayer.get_remote_sender_id(), sent_at)

@rpc("any_peer", "call_remote", "unreliable")
func _latency_pong(sent_at: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if connected_peer_ids.has(sender_id):
		_peer_rtt_ms[sender_id] = clampi(Time.get_ticks_msec() - sent_at, 0, 9999)

@rpc("any_peer", "call_remote", "reliable")
func _send_probe(protocol: String, persona_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		_set_status("RPC recusado • protocolo incompatível")
		return
	rpc_probe_received.emit(sender_id, persona_name)
	peer_names[sender_id] = persona_name
	peer_identity_changed.emit(sender_id, persona_name)
	_set_status("RPC recebido de %s • conexão confirmada" % persona_name)
	_confirm_probe.rpc_id(sender_id, PROTOCOL_VERSION, _get_persona_name())

@rpc("any_peer", "call_remote", "reliable")
func _confirm_probe(protocol: String, persona_name: String) -> void:
	if protocol != PROTOCOL_VERSION:
		_set_status("Resposta RPC incompatível")
		return
	var sender_id := multiplayer.get_remote_sender_id()
	rpc_probe_received.emit(sender_id, persona_name)
	peer_names[sender_id] = persona_name
	peer_identity_changed.emit(sender_id, persona_name)
	_set_status("RPC confirmado com %s" % persona_name)

func submit_local_player_state(position: Vector3, yaw: float, head_pitch: float) -> void:
	if _steam_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if is_session_host:
		player_state_received.emit(local_peer_id, position, yaw, head_pitch)
		_receive_player_state.rpc(local_peer_id, position, yaw, head_pitch)
	else:
		_submit_player_state.rpc_id(1, position, yaw, head_pitch)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_player_state(position: Vector3, yaw: float, head_pitch: float) -> void:
	if not is_session_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	player_state_received.emit(sender_id, position, yaw, head_pitch)
	_receive_player_state.rpc(sender_id, position, yaw, head_pitch)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_player_state(peer_id: int, position: Vector3, yaw: float, head_pitch: float) -> void:
	if is_session_host:
		return
	player_state_received.emit(peer_id, position, yaw, head_pitch)

func _get_persona_name() -> String:
	if _steam_bootstrap != null:
		return str(_steam_bootstrap.persona_name)
	return "Jogador"

func _set_status(status: String) -> void:
	status_message = status
	session_state_changed.emit(status_message)
