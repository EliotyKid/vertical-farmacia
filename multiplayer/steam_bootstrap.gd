extends Node

signal steam_state_changed(available: bool, status: String)

const TEST_APP_ID := 480

var steam_available: bool = false
var steam_id: int = 0
var persona_name: String = "Jogador local"
var status_message: String = "Steam não inicializada"

var _steam: Object

func _init() -> void:
	if OS.get_environment("SteamAppId").is_empty():
		OS.set_environment("SteamAppId", str(TEST_APP_ID))
	if OS.get_environment("SteamGameId").is_empty():
		OS.set_environment("SteamGameId", str(TEST_APP_ID))

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	if steam_available and _steam != null and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")

func _initialize_steam() -> void:
	if not Engine.has_singleton("Steam"):
		_set_state(false, "Steam indisponível • modo solo")
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null or not _steam.has_method("steamInitEx"):
		_set_state(false, "GodotSteam incompatível • modo solo")
		return
	var initialization: Variant = _steam.call("steamInitEx")
	if not initialization is Dictionary:
		_set_state(false, "Resposta inválida da Steam • modo solo")
		return
	var result := initialization as Dictionary
	var status := int(result.get("status", -1))
	if status != 0:
		var detail := str(result.get("verbal", result.get("message", "erro %d" % status)))
		_set_state(false, "Steam offline • modo solo (%s)" % detail)
		return
	steam_id = int(_steam.call("getSteamID")) if _steam.has_method("getSteamID") else 0
	persona_name = str(_steam.call("getPersonaName")) if _steam.has_method("getPersonaName") else "Jogador Steam"
	_set_state(true, "Steam conectada • %s" % persona_name)

func _set_state(available: bool, message: String) -> void:
	steam_available = available
	status_message = message
	steam_state_changed.emit(steam_available, status_message)

func get_debug_summary() -> String:
	if not steam_available:
		return status_message
	return "%s • ID %d • App %d" % [status_message, steam_id, TEST_APP_ID]

func is_online_available() -> bool:
	return steam_available

func get_steam_interface() -> Object:
	return _steam
