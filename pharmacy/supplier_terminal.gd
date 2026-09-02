class_name SupplierTerminal
extends StaticBody3D

signal item_purchased(item_data: ItemData, price: int)

@export var world_item_scene: PackedScene
@export var catalog: Array[ItemData] = []

@onready var menu: Control = %SupplierMenu
@onready var feedback_label: Label = %FeedbackLabel
@onready var money_label: Label = %TerminalMoneyLabel
@onready var item_buttons: Array[Button] = [%ItemButton1, %ItemButton2, %ItemButton3]

var _active_player: PharmacyPlayer
var _wallet: Wallet
var _purchase_count: int = 0
var _emergency_grant_used: bool = false


func _ready() -> void:
	add_to_group("supplier_terminal")
	$Interactable.interacted.connect(_on_interacted)
	%CloseButton.pressed.connect(close_menu)
	%EmergencyButton.pressed.connect(_request_emergency_grant)
	for index: int in range(item_buttons.size()):
		item_buttons[index].pressed.connect(_request_purchase.bind(index))
	_configure_catalog_ui()
	menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()


func _on_interacted(player: PharmacyPlayer) -> void:
	_active_player = player
	_wallet = player.get_node_or_null("Wallet") as Wallet
	if _wallet == null:
		return
	if not _wallet.money_changed.is_connected(_on_money_changed):
		_wallet.money_changed.connect(_on_money_changed)
	_active_player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	feedback_label.text = "Selecione uma mercadoria."
	_on_money_changed(_wallet.money, 0)
	menu.visible = true


func close_menu() -> void:
	menu.visible = false
	if _active_player != null:
		_active_player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_active_player = null
	_wallet = null


func _request_purchase(catalog_index: int) -> void:
	if _wallet == null or catalog_index < 0 or catalog_index >= catalog.size():
		return
	var item_data := catalog[catalog_index]
	if not _wallet.try_spend(item_data.buy_price):
		feedback_label.text = "Dinheiro insuficiente."
		return
	if not _spawn_delivery(item_data):
		_wallet.add_money(item_data.buy_price)
		feedback_label.text = "Área de entrega indisponível."
		return
	feedback_label.text = "%s entregue!" % item_data.display_name
	item_purchased.emit(item_data, item_data.buy_price)


func _spawn_delivery(item_data: ItemData) -> bool:
	var delivery_marker := get_tree().get_first_node_in_group("delivery_spawn") as Marker3D
	if delivery_marker == null or world_item_scene == null:
		return false
	var item := world_item_scene.instantiate() as WorldItem
	item.item_data = item_data
	delivery_marker.get_parent().add_child(item)
	var column := _purchase_count % 4
	var row := _purchase_count / 4
	item.global_position = delivery_marker.global_position + Vector3(column * 0.58, row * 0.42, 0.0)
	item.mark_current_transform_safe()
	_purchase_count += 1
	return true


func _configure_catalog_ui() -> void:
	for index: int in range(item_buttons.size()):
		var button := item_buttons[index]
		if index < catalog.size():
			var item_data := catalog[index]
			button.text = "%s  —  $%d" % [item_data.display_name, item_data.buy_price]
			button.visible = true
		else:
			button.visible = false


func _on_money_changed(new_amount: int, _difference: int) -> void:
	money_label.text = "Saldo: $%d" % new_amount
	%EmergencyButton.visible = not _emergency_grant_used and new_amount < 12


func _request_emergency_grant() -> void:
	if _wallet == null or _emergency_grant_used or _wallet.money >= 12:
		return
	_emergency_grant_used = true
	_wallet.add_money(12)
	feedback_label.text = "Auxílio emergencial recebido: $12"
