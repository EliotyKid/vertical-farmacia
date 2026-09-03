class_name CoopLobbyUI
extends CanvasLayer

@onready var menu: Control = %LobbyMenu
@onready var status_label: Label = %StatusLabel
@onready var members_label: Label = %MembersLabel
@onready var create_button: Button = %CreateButton
@onready var invite_button: Button = %InviteButton
@onready var leave_button: Button = %LeaveButton
@onready var lobby_id_label: Button = %LobbyIdLabel
@onready var join_code_input: LineEdit = %JoinCodeInput
@onready var join_button: Button = %JoinButton
@onready var copy_button: Button = %CopyButton
@onready var network_status_label: Label = %NetworkStatusLabel

var _manager: Node
var _network_session: Node
var _active_player: PharmacyPlayer

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	invite_button.pressed.connect(_on_invite_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	join_button.pressed.connect(_on_join_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	lobby_id_label.pressed.connect(_on_copy_pressed)
	%CloseButton.pressed.connect(close_menu)
	menu.visible = false
	call_deferred("_connect_manager")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("coop_menu"):
		if menu.visible:
			close_menu()
		else:
			open_menu()

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()

func _connect_manager() -> void:
	_manager = get_node_or_null("/root/SteamLobbyManager")
	if _manager == null:
		status_label.text = "Gerenciador de lobby indisponível"
		_update_buttons()
		return
	_manager.lobby_state_changed.connect(_on_lobby_state_changed)
	_manager.lobby_members_changed.connect(_on_lobby_members_changed)
	_on_lobby_state_changed(_manager.status_message)
	_on_lobby_members_changed(_manager.member_names)
	_network_session = get_node_or_null("/root/NetworkSession")
	if _network_session != null:
		_network_session.session_state_changed.connect(_on_network_state_changed)
		_on_network_state_changed(_network_session.status_message)
		if _network_session.consume_recovery_menu_request():
			open_menu()
	else:
		network_status_label.text = "Rede: NetworkSession indisponível"
	var pending_lobby_id := int(_manager.consume_pending_lobby_id())
	if pending_lobby_id > 0:
		open_menu()
		join_code_input.text = str(pending_lobby_id)
		_manager.join_lobby_by_id(pending_lobby_id)

func open_menu() -> void:
	_active_player = get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if _active_player != null:
		_active_player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true
	_update_buttons()

func close_menu() -> void:
	menu.visible = false
	if _active_player != null:
		_active_player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_active_player = null

func _on_create_pressed() -> void:
	if _manager != null:
		_manager.create_lobby()
	_update_buttons()

func _on_invite_pressed() -> void:
	if _manager != null:
		_manager.invite_friend()

func _on_leave_pressed() -> void:
	if _manager != null:
		_manager.leave_lobby()
	_update_buttons()

func _on_join_pressed() -> void:
	if _manager == null:
		return
	var code := join_code_input.text.strip_edges()
	if not code.is_valid_int():
		status_label.text = "Código inválido: use somente o número enviado pelo host"
		return
	_manager.join_lobby_by_id(code.to_int())

func _on_copy_pressed() -> void:
	if _manager == null or int(_manager.lobby_id) == 0:
		return
	DisplayServer.clipboard_set(str(_manager.lobby_id))
	status_label.text = "Código copiado • envie ao seu amigo"

func _on_lobby_state_changed(status: String) -> void:
	status_label.text = status
	_update_buttons()

func _on_lobby_members_changed(names: Array[String]) -> void:
	members_label.text = "Jogadores:\n" + ("\n".join(names) if not names.is_empty() else "—")
	_update_buttons()

func _on_network_state_changed(status: String) -> void:
	network_status_label.text = "Rede: %s" % status

func _update_buttons() -> void:
	var available: bool = _manager != null and bool(_manager.is_steam_available())
	var in_lobby: bool = _manager != null and int(_manager.lobby_id) != 0
	lobby_id_label.text = ("Código da sala: %s  •  clique para copiar" % str(_manager.lobby_id)) if in_lobby else "Código da sala: —"
	lobby_id_label.disabled = not in_lobby
	create_button.disabled = not available or in_lobby
	invite_button.disabled = not available or not in_lobby
	leave_button.disabled = not in_lobby
	join_button.disabled = not available or in_lobby
	copy_button.disabled = not in_lobby
