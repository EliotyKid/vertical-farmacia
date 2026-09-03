class_name MainMenu
extends Control

const GAME_SCENE := "res://levels/pharmacy_test.tscn"

@onready var main_buttons: VBoxContainer = %MainButtons
@onready var connect_panel: VBoxContainer = %ConnectPanel
@onready var lobby_code_input: LineEdit = %LobbyCodeInput
@onready var status_label: Label = %StatusLabel
@onready var connect_button: Button = %ConnectButton

var _lobby_manager: Node

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%PlayButton.pressed.connect(_on_play_pressed)
	%ShowConnectButton.pressed.connect(_show_connect_panel)
	connect_button.pressed.connect(_on_connect_pressed)
	%BackButton.pressed.connect(_show_main_buttons)
	lobby_code_input.text_submitted.connect(_on_code_submitted)
	_lobby_manager = get_node_or_null("/root/SteamLobbyManager")
	if _lobby_manager != null:
		_lobby_manager.lobby_state_changed.connect(_on_lobby_state_changed)
		_on_lobby_state_changed(_lobby_manager.status_message)
	else:
		status_label.text = "Steam indisponível"
		connect_button.disabled = true

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _show_connect_panel() -> void:
	main_buttons.visible = false
	connect_panel.visible = true
	lobby_code_input.grab_focus()

func _show_main_buttons() -> void:
	connect_panel.visible = false
	main_buttons.visible = true
	status_label.text = _lobby_manager.status_message if _lobby_manager != null else "Steam indisponível"

func _on_code_submitted(_code: String) -> void:
	_on_connect_pressed()

func _on_connect_pressed() -> void:
	if _lobby_manager == null:
		status_label.text = "Steam indisponível"
		return
	var code := lobby_code_input.text.strip_edges()
	if not code.is_valid_int() or code.to_int() <= 0:
		status_label.text = "Digite o código numérico enviado pelo host"
		return
	if not bool(_lobby_manager.is_steam_available()):
		status_label.text = "Abra a Steam antes de conectar"
		return
	if not bool(_lobby_manager.queue_join_after_game_load(code.to_int())):
		status_label.text = "Código de sala inválido"
		return
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_lobby_state_changed(status: String) -> void:
	status_label.text = status
	connect_button.disabled = not bool(_lobby_manager.is_steam_available())
