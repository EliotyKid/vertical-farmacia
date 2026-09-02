class_name PharmacySaveManager
extends Node

const SAVE_PATH := "user://pharmacy_save.json"
const SAVE_VERSION := 1

@export_range(0.1, 5.0, 0.1) var autosave_delay: float = 0.5

var _wallet: Wallet
var _progression: GameProgression
var _upgrade_terminal: UpgradeTerminal
var _supplier_terminal: SupplierTerminal
var _save_timer: Timer
var _is_loading: bool = true

func _ready() -> void:
	add_to_group("save_manager")
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = autosave_delay
	_save_timer.timeout.connect(save_game)
	add_child(_save_timer)
	call_deferred("_initialize")

func _initialize() -> void:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	_wallet = player.get_node_or_null("Wallet") as Wallet if player != null else null
	_progression = get_tree().get_first_node_in_group("game_progression") as GameProgression
	_upgrade_terminal = get_tree().get_first_node_in_group("upgrade_terminal") as UpgradeTerminal
	_supplier_terminal = get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if _wallet == null or _progression == null or _upgrade_terminal == null or _supplier_terminal == null:
		push_warning("SaveManager não encontrou todos os sistemas persistentes.")
		_is_loading = false
		return
	load_game()
	_wallet.money_changed.connect(_on_persistent_state_changed.unbind(2))
	_progression.progress_changed.connect(_on_persistent_state_changed.unbind(3))
	_upgrade_terminal.upgrade_purchased.connect(_on_persistent_state_changed.unbind(1))
	_is_loading = false

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível abrir o save da farmácia.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save da farmácia inválido; começando com os valores padrão.")
		return
	var data := parsed as Dictionary
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Versão de save incompatível; começando com os valores padrão.")
		return
	_wallet.set_money(int(data.get("money", _wallet.money)))
	_progression.restore_progress(
		int(data.get("completed_orders", 0)),
		int(data.get("abandoned_orders", 0)),
		int(data.get("total_revenue", 0))
	)
	var saved_upgrades: Array[StringName] = []
	for upgrade_id: Variant in data.get("upgrades", []):
		saved_upgrades.append(StringName(str(upgrade_id)))
	_upgrade_terminal.restore_upgrades(saved_upgrades)
	_supplier_terminal.restore_emergency_grant_used(bool(data.get("emergency_grant_used", false)))

func save_game() -> void:
	if _is_loading or _wallet == null or _progression == null or _upgrade_terminal == null:
		return
	var data := {
		"version": SAVE_VERSION,
		"money": _wallet.money,
		"completed_orders": _progression.completed_orders,
		"abandoned_orders": _progression.abandoned_orders,
		"total_revenue": _progression.total_revenue,
		"upgrades": _upgrade_terminal.get_purchased_upgrade_ids(),
		"emergency_grant_used": _supplier_terminal.has_used_emergency_grant(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar a progressão da farmácia.")
		return
	file.store_string(JSON.stringify(data, "\t"))

func _on_persistent_state_changed() -> void:
	if not _is_loading:
		_save_timer.start()

func reset_progress() -> void:
	_is_loading = true
	_save_timer.stop()
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			_is_loading = false
			push_error("Não foi possível apagar o save da farmácia: erro %d." % error)
			return
	get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
