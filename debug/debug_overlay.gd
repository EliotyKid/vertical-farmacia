extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var fps_label: Label = %FPSLabel
@onready var carried_item_label: Label = %CarriedItemLabel
@onready var target_label: Label = %TargetLabel
@onready var metrics_label: Label = %MetricsLabel
@onready var steam_label: Label = %SteamLabel
@onready var network_label: Label = %NetworkLabel

var _metrics: PlaytestMetrics
var _network_session: Node
var _network_world_state: Node
var _network_game_state: Node

func _ready() -> void:
	panel.visible = false
	call_deferred("_connect_sources")

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if Input.is_action_just_pressed("debug_toggle"):
		panel.visible = not panel.visible
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_reset_progress"):
		var save_manager := get_tree().get_first_node_in_group("save_manager") as PharmacySaveManager
		if save_manager != null:
			save_manager.reset_progress()
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_add_money"):
		_debug_add_money()
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_spawn_customer"):
		_debug_spawn_customer()
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_inspection"):
		_debug_schedule_inspection()
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_explosion"):
		_debug_trigger_explosion()
	if _metrics != null:
		metrics_label.text = _metrics.get_debug_summary()
	if _network_session != null:
		var world_summary: String = str(_network_world_state.get_debug_summary()) if _network_world_state != null else "mundo indisponível"
		var game_summary: String = str(_network_game_state.get_debug_summary()) if _network_game_state != null else "jogo indisponível"
		network_label.text = "%s\n%s\n%s" % [_network_session.get_debug_summary(), world_summary, game_summary]

func _connect_sources() -> void:
	_metrics = get_tree().get_first_node_in_group("playtest_metrics") as PlaytestMetrics
	var steam_bootstrap := get_node_or_null("/root/SteamBootstrap")
	if steam_bootstrap != null:
		steam_label.text = steam_bootstrap.get_debug_summary()
		steam_bootstrap.steam_state_changed.connect(_on_steam_state_changed)
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null:
		_network_session = network_session
		_network_world_state = get_node_or_null("/root/NetworkWorldState")
		_network_game_state = get_node_or_null("/root/NetworkGameState")
		network_session.session_state_changed.connect(_on_network_state_changed.bind(network_session))
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player != null:
		var carry := player.get_node_or_null("CarryController") as CarryController
		if carry != null:
			carry.carried_item_changed.connect(_on_carried_item_changed)
			_on_carried_item_changed(carry.current_item)
	var controller := get_tree().get_first_node_in_group("interaction_controller") as InteractionController
	if controller != null:
		controller.target_changed.connect(_on_target_changed)

func _on_carried_item_changed(item: WorldItem) -> void:
	carried_item_label.text = "Carregando: %s" % (item.get_display_name() if item != null else "nada")

func _on_target_changed(target: Node) -> void:
	target_label.text = "Alvo: %s" % (target.get_parent().name if target != null else "nenhum")


func _on_steam_state_changed(_available: bool, status: String) -> void:
	steam_label.text = status

func _on_network_state_changed(_status: String, network_session: Node) -> void:
	network_label.text = network_session.get_debug_summary()


func _debug_add_money() -> void:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	var wallet := player.get_node_or_null("Wallet") as Wallet if player != null else null
	if wallet != null:
		wallet.add_money(100)


func _debug_spawn_customer() -> void:
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner != null:
		spawner.debug_spawn_customer()


func _debug_schedule_inspection() -> void:
	var manager := get_tree().get_first_node_in_group("inspection_manager") as InspectionManager
	if manager != null:
		manager.debug_schedule_inspection()


func _debug_trigger_explosion() -> void:
	var station := get_tree().get_first_node_in_group("crafting_station") as StationInput
	if station != null:
		station.debug_trigger_explosion()
