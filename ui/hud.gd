class_name PharmacyHUD
extends CanvasLayer

@onready var money_label: Label = %MoneyLabel
@onready var orders_label: Label = %OrdersLabel
@onready var order_label: Label = %OrderLabel
@onready var money_popup: Label = %MoneyPopup
@onready var explosion_flash: ColorRect = %ExplosionFlash

func _ready() -> void:
	money_popup.modulate.a = 0.0
	explosion_flash.modulate.a = 0.0
	call_deferred("_connect_wallet")
	call_deferred("_connect_customer_spawner")
	call_deferred("_connect_progression")
	call_deferred("_connect_crafting_station")

func _connect_wallet() -> void:
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player == null: return
	var wallet := player.get_node_or_null("Wallet") as Wallet
	if wallet != null:
		wallet.money_changed.connect(_on_money_changed)
		_on_money_changed(wallet.money, 0)

func _on_money_changed(new_amount: int, difference: int) -> void:
	money_label.text = "$%d" % new_amount
	if difference != 0:
		_show_money_popup(difference)
		_pulse_label(money_label, Color("65e698") if difference > 0 else Color("ff786c"))

func _show_money_popup(difference: int) -> void:
	money_popup.text = "%s$%d" % ["+" if difference > 0 else "-", absi(difference)]
	money_popup.modulate = Color("65e698") if difference > 0 else Color("ff786c")
	money_popup.position.y = 70.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(money_popup, "position:y", 100.0, 0.7)
	tween.tween_property(money_popup, "modulate:a", 0.0, 0.7).set_delay(0.25)

func _connect_customer_spawner() -> void:
	var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
	if spawner == null: return
	spawner.active_customer_changed.connect(_on_active_customer_changed)
	_on_active_customer_changed(spawner.active_customer)

func _on_active_customer_changed(customer: PharmacyCustomer) -> void:
	if customer == null:
		order_label.text = "Aguardando cliente"
		return
	customer.order_created.connect(_on_order_created)
	customer.order_completed.connect(_on_order_completed)
	customer.delivery_rejected.connect(_on_delivery_rejected)

func _on_order_created(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	order_label.text = "PEDIDO: 1x %s • $%d" % [order.requested_item.display_name, order.reward]
	_pulse_label(order_label, Color("ffe080"))

func _on_order_completed(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	order_label.text = "Pedido entregue! +$%d" % order.reward
	_pulse_label(order_label, Color("65e698"))

func _on_delivery_rejected(_customer: PharmacyCustomer, item: ItemData) -> void:
	order_label.text = "Item errado: %s" % item.display_name
	_pulse_label(order_label, Color("ff786c"))

func _connect_progression() -> void:
	var progression := get_tree().get_first_node_in_group("game_progression") as GameProgression
	if progression == null: return
	progression.progress_changed.connect(_on_progress_changed)
	_on_progress_changed(progression.completed_orders, progression.total_revenue)

func _on_progress_changed(completed: int, _revenue: int) -> void:
	orders_label.text = "Atendidos: %d" % completed

func _connect_crafting_station() -> void:
	var station := get_tree().get_first_node_in_group("crafting_station") as StationInput
	if station != null: station.explosion_triggered.connect(_on_explosion_triggered)

func _on_explosion_triggered(_explosion: CraftingExplosion) -> void:
	explosion_flash.modulate = Color(1.0, 0.22, 0.08, 0.78)
	create_tween().tween_property(explosion_flash, "modulate:a", 0.0, 0.48)
	var player := get_tree().get_first_node_in_group("player") as PharmacyPlayer
	if player != null: player.add_camera_shake(1.0)

func _pulse_label(label: Label, color: Color) -> void:
	label.modulate = color
	label.scale = Vector2(1.06, 1.06)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate", Color.WHITE, 0.4)
	tween.tween_property(label, "scale", Vector2.ONE, 0.4)
