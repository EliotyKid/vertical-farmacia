extends Node

signal lobby_state_changed(status: String)
signal lobby_members_changed(member_names: Array[String])
signal lobby_connection_ready(lobby_id: int, is_host: bool)
signal lobby_left

const LOBBY_TYPE_FRIENDS_ONLY := 1
const LOBBY_LIMIT := 4
const RESULT_OK := 1
const CHAT_ROOM_ENTER_SUCCESS := 1
const PROTOCOL_VERSION := "farmacia-coop-mp10-4p"

var lobby_id: int = 0
var is_host: bool = false
var status_message: String = "Steam não verificada"
var member_names: Array[String] = []
var pending_lobby_id: int = 0

var _steam: Object
var _bootstrap: Node

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_bootstrap = get_node_or_null("/root/SteamBootstrap")
	if _bootstrap == null:
		_set_status("SteamBootstrap ausente • somente solo")
		return
	_bootstrap.steam_state_changed.connect(_on_steam_state_changed)
	_on_steam_state_changed(_bootstrap.is_online_available(), _bootstrap.status_message)

func _on_steam_state_changed(available: bool, status: String) -> void:
	if not available:
		_set_status(status)
		return
	_steam = _bootstrap.get_steam_interface()
	_connect_steam_signals()
	_set_status("Online disponível • crie um lobby privado")

func _connect_steam_signals() -> void:
	_connect_signal("lobby_created", _on_lobby_created)
	_connect_signal("lobby_joined", _on_lobby_joined)
	_connect_signal("lobby_chat_update", _on_lobby_chat_update)
	_connect_signal("join_requested", _on_join_requested)

func _connect_signal(signal_name: StringName, callback: Callable) -> void:
	if _steam != null and _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, callback):
		_steam.connect(signal_name, callback)

func create_lobby() -> bool:
	if not is_steam_available() or lobby_id != 0:
		return false
	_set_status("Criando lobby privado...")
	_steam.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, LOBBY_LIMIT)
	return true

func invite_friend() -> bool:
	if not is_steam_available() or lobby_id == 0:
		_set_status("Crie ou entre em um lobby antes de convidar")
		return false
	if _steam.has_method("isOverlayEnabled") and not bool(_steam.call("isOverlayEnabled")):
		_set_status("Overlay indisponível • envie o código do lobby")
		return false
	_steam.call("activateGameOverlayInviteDialog", lobby_id)
	_set_status("Overlay de convite solicitado")
	return true

func join_lobby_by_id(requested_lobby_id: int) -> bool:
	if not is_steam_available():
		_set_status("Steam indisponível • não foi possível entrar")
		return false
	if requested_lobby_id <= 0:
		_set_status("Código de lobby inválido")
		return false
	if lobby_id != 0:
		leave_lobby()
	_set_status("Entrando no lobby %d..." % requested_lobby_id)
	_steam.call("joinLobby", requested_lobby_id)
	return true

func queue_join_after_game_load(requested_lobby_id: int) -> bool:
	if requested_lobby_id <= 0:
		return false
	pending_lobby_id = requested_lobby_id
	return true

func consume_pending_lobby_id() -> int:
	var requested_lobby_id := pending_lobby_id
	pending_lobby_id = 0
	return requested_lobby_id

func leave_lobby() -> void:
	lobby_left.emit()
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	is_host = false
	member_names.clear()
	lobby_members_changed.emit(member_names)
	_set_status("Lobby encerrado • modo solo")

func handle_transport_disconnected(reason: String) -> void:
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	is_host = false
	member_names.clear()
	lobby_members_changed.emit(member_names)
	_set_status("%s • lobby limpo" % reason)

func is_steam_available() -> bool:
	return _bootstrap != null and _bootstrap.is_online_available() and _steam != null

func _on_lobby_created(connect_result: int, created_lobby_id: int) -> void:
	if connect_result != RESULT_OK:
		_set_status("Falha ao criar lobby • código %d" % connect_result)
		return
	lobby_id = created_lobby_id
	is_host = true
	_steam.call("setLobbyData", lobby_id, "game", "farmacia_frenetica")
	_steam.call("setLobbyData", lobby_id, "protocol", PROTOCOL_VERSION)
	_steam.call("setLobbyData", lobby_id, "state", "waiting")
	_steam.call("setLobbyData", lobby_id, "host_name", _bootstrap.persona_name)
	_refresh_members()
	_set_status("Lobby criado • aguardando amigo")
	lobby_connection_ready.emit(lobby_id, true)

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != CHAT_ROOM_ENTER_SUCCESS:
		_set_status("Não foi possível entrar • código %d" % response)
		return
	lobby_id = joined_lobby_id
	var owner_id := int(_steam.call("getLobbyOwner", lobby_id))
	is_host = owner_id == _bootstrap.steam_id
	var protocol := str(_steam.call("getLobbyData", lobby_id, "protocol"))
	if not is_host and protocol != PROTOCOL_VERSION:
		_steam.call("leaveLobby", lobby_id)
		lobby_id = 0
		_set_status("Lobby usa outra versão do protocolo")
		return
	_refresh_members()
	_set_status("Lobby conectado • %d/%d jogadores" % [member_names.size(), LOBBY_LIMIT])
	lobby_connection_ready.emit(lobby_id, is_host)

func _on_lobby_chat_update(changed_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	if changed_lobby_id == lobby_id:
		_refresh_members()
		_set_status("Lobby conectado • %d/%d jogadores" % [member_names.size(), LOBBY_LIMIT])

func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	join_lobby_by_id(requested_lobby_id)

func _refresh_members() -> void:
	member_names.clear()
	if _steam == null or lobby_id == 0:
		lobby_members_changed.emit(member_names)
		return
	var member_count := int(_steam.call("getNumLobbyMembers", lobby_id))
	for index: int in range(member_count):
		var member_id := int(_steam.call("getLobbyMemberByIndex", lobby_id, index))
		var member_name := str(member_id)
		if member_id == _bootstrap.steam_id:
			member_name = _bootstrap.persona_name
		elif _steam.has_method("getFriendPersonaName"):
			member_name = str(_steam.call("getFriendPersonaName", member_id))
		member_names.append(member_name)
	lobby_members_changed.emit(member_names)


func _set_status(status: String) -> void:
	status_message = status
	lobby_state_changed.emit(status_message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and lobby_id != 0:
		leave_lobby()
