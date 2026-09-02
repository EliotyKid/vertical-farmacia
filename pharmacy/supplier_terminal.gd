class_name SupplierTerminal
extends StaticBody3D

signal item_purchased(item_data: ItemData, price: int)
signal delivery_status_changed(status: String)
signal delivery_arrived(item_data: ItemData, quantity: int)

@export var delivery_box_scene: PackedScene
@export var catalog: Array[ItemData] = []
@export_range(1, 10, 1) var purchase_quantity: int = 2
@export_range(1.0, 120.0, 1.0) var delivery_time: float = 20.0
@export_range(1, 8, 1) var delivery_area_capacity: int = 3

@onready var menu: Control = %SupplierMenu
@onready var feedback_label: Label = %FeedbackLabel
@onready var money_label: Label = %TerminalMoneyLabel
@onready var catalog_buttons: VBoxContainer = %CatalogButtons

var _active_player: PharmacyPlayer
var _wallet: Wallet
var _purchase_count: int = 0
var _emergency_grant_used: bool = false
var _pending_deliveries: Array[Dictionary] = []
var _last_delivery_status: String = ""


func _ready() -> void:
	add_to_group("supplier_terminal")
	$Interactable.interacted.connect(_on_interacted)
	%CloseButton.pressed.connect(close_menu)
	%EmergencyButton.pressed.connect(_request_emergency_grant)
	_configure_catalog_ui()
	menu.visible = false
	_update_delivery_status()


func _process(delta: float) -> void:
	for delivery: Dictionary in _pending_deliveries:
		delivery.remaining = maxf(float(delivery.remaining) - delta, 0.0)
	_try_complete_deliveries()
	_update_delivery_status()


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
	var total_price := item_data.buy_price * purchase_quantity
	if not _wallet.try_spend(total_price):
		feedback_label.text = "Dinheiro insuficiente."
		return
	_queue_delivery(item_data)
	feedback_label.text = "Pedido confirmado. Chega em %.0fs." % delivery_time
	item_purchased.emit(item_data, total_price)


func _queue_delivery(item_data: ItemData) -> void:
	_pending_deliveries.append({
		"item_data": item_data,
		"quantity": purchase_quantity,
		"remaining": delivery_time,
	})
	_update_delivery_status()


func _try_complete_deliveries() -> void:
	while not _pending_deliveries.is_empty():
		var delivery: Dictionary = _pending_deliveries[0]
		if float(delivery.remaining) > 0.0 or _delivered_box_count() >= delivery_area_capacity:
			return
		var item_data := delivery.item_data as ItemData
		var quantity := int(delivery.quantity)
		if not _spawn_delivery(item_data, quantity):
			return
		_pending_deliveries.pop_front()
		delivery_arrived.emit(item_data, quantity)


func _spawn_delivery(item_data: ItemData, quantity: int) -> bool:
	var delivery_marker := get_tree().get_first_node_in_group("delivery_spawn") as Marker3D
	if delivery_marker == null or delivery_box_scene == null:
		return false
	var box := delivery_box_scene.instantiate() as DeliveryBox
	box.configure(item_data, quantity)
	delivery_marker.get_parent().add_child(box)
	var column := _purchase_count % 4
	var row := _purchase_count / 4
	box.global_position = delivery_marker.global_position + Vector3(column * 1.0, row * 0.72, 0.0)
	box.mark_current_transform_safe()
	_purchase_count += 1
	return true


func _delivered_box_count() -> int:
	return get_tree().get_nodes_in_group("delivered_box").size()


func _update_delivery_status() -> void:
	var status := "Entregas: nenhuma pendente"
	if not _pending_deliveries.is_empty():
		var next: Dictionary = _pending_deliveries[0]
		if float(next.remaining) <= 0.0 and _delivered_box_count() >= delivery_area_capacity:
			status = "ENTREGA AGUARDANDO ESPAÇO!"
		else:
			var item := next.item_data as ItemData
			status = "Entrega: %dx %s em %.0fs" % [int(next.quantity), item.display_name, float(next.remaining)]
			if _pending_deliveries.size() > 1:
				status += " • %d pedidos" % _pending_deliveries.size()
	%DeliveryStatusLabel.text = status
	if status != _last_delivery_status:
		_last_delivery_status = status
		delivery_status_changed.emit(status)


func _configure_catalog_ui() -> void:
	for child: Node in catalog_buttons.get_children():
		child.queue_free()
	for index: int in range(catalog.size()):
		var item_data := catalog[index]
		var button := Button.new()
		button.text = "%dx %s  —  $%d" % [purchase_quantity, item_data.display_name, item_data.buy_price * purchase_quantity]
		button.pressed.connect(_request_purchase.bind(index))
		catalog_buttons.add_child(button)


func _on_money_changed(new_amount: int, _difference: int) -> void:
	money_label.text = "Saldo: $%d" % new_amount
	%EmergencyButton.visible = not _emergency_grant_used and new_amount < get_cheapest_lot_price()


func _request_emergency_grant() -> void:
	var minimum_lot_price := get_cheapest_lot_price()
	if _wallet == null or _emergency_grant_used or _wallet.money >= minimum_lot_price:
		return
	_emergency_grant_used = true
	var grant := minimum_lot_price - _wallet.money
	_wallet.add_money(grant)
	feedback_label.text = "Auxílio emergencial recebido: $%d" % grant


func get_cheapest_lot_price() -> int:
	var cheapest := 0
	for item: ItemData in catalog:
		if item == null or item.buy_price <= 0 or item.category != ItemData.Category.MEDICINE:
			continue
		var lot_price := item.buy_price * purchase_quantity
		if cheapest == 0 or lot_price < cheapest:
			cheapest = lot_price
	return cheapest


func has_used_emergency_grant() -> bool:
	return _emergency_grant_used


func restore_emergency_grant_used(was_used: bool) -> void:
	_emergency_grant_used = was_used
	if _wallet != null:
		_on_money_changed(_wallet.money, 0)
