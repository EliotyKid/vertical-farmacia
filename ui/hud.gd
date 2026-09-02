class_name PharmacyHUD
extends CanvasLayer

@onready var money_label: Label = %MoneyLabel
@onready var orders_label: Label = %OrdersLabel
@onready var demand_label: Label = %DemandLabel
@onready var order_label: Label = %OrderLabel
@onready var delivery_label: Label = %DeliveryLabel
@onready var inspection_label: Label = %InspectionLabel
@onready var money_popup: Label = %MoneyPopup
@onready var explosion_flash: ColorRect = %ExplosionFlash

func _ready() -> void:
	money_popup.modulate.a = 0.0
	explosion_flash.modulate.a = 0.0
	call_deferred("_connect_wallet")
	call_deferred("_connect_customer_spawner")
	call_deferred("_connect_progression")
	call_deferred("_connect_crafting_station")
	call_deferred("_connect_supplier")
	call_deferred("_connect_inspection_manager")

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
	spawner.customer_spawned.connect(_on_customer_spawned)
	spawner.opening_countdown_changed.connect(_on_opening_countdown_changed)
	spawner.active_customer_changed.connect(_on_active_customer_changed)
	_on_opening_countdown_changed(spawner.get_opening_countdown())
	for customer: PharmacyCustomer in spawner.active_customers:
		_on_customer_spawned(customer)

func _on_active_customer_changed(customer: PharmacyCustomer) -> void:
	if customer == null:
		order_label.text = "Aguardando cliente"

func _on_customer_spawned(customer: PharmacyCustomer) -> void:
	customer.order_created.connect(_on_order_created)
	customer.order_completed.connect(_on_order_completed)
	customer.delivery_rejected.connect(_on_delivery_rejected)
	customer.order_abandoned.connect(_on_order_abandoned)

func _on_opening_countdown_changed(seconds: int) -> void:
	if seconds > 0:
		order_label.text = "ABERTURA: primeiro cliente em %ds" % seconds

func _on_order_created(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	order_label.text = "PEDIDO: 1x %s • $%d" % [order.requested_item.display_name, order.reward]
	_pulse_label(order_label, Color("ffe080"))

func _on_order_completed(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	order_label.text = "Pedido entregue! +$%d" % order.reward
	_pulse_label(order_label, Color("65e698"))

func _on_delivery_rejected(_customer: PharmacyCustomer, item: ItemData) -> void:
	order_label.text = "Item errado: %s" % item.display_name
	_pulse_label(order_label, Color("ff786c"))

func _on_order_abandoned(_customer: PharmacyCustomer, order: CustomerOrder) -> void:
	order_label.text = "Cliente desistiu: %s" % order.requested_item.display_name
	_pulse_label(order_label, Color("ff786c"))

func _connect_progression() -> void:
	var progression := get_tree().get_first_node_in_group("game_progression") as GameProgression
	if progression == null: return
	progression.progress_changed.connect(_on_progress_changed)
	progression.demand_level_changed.connect(_on_demand_level_changed)
	_on_progress_changed(progression.completed_orders, progression.abandoned_orders, progression.total_revenue)
	_on_demand_level_changed(progression.get_demand_level(), progression.get_demand_label())

func _on_progress_changed(completed: int, abandoned: int, _revenue: int) -> void:
	orders_label.text = "Atendidos: %d • Perdidos: %d" % [completed, abandoned]

func _on_demand_level_changed(level: int, label: String) -> void:
	demand_label.text = "Ritmo %d: %s" % [level, label]
	match level:
		1: demand_label.modulate = Color("8de5aa")
		2: demand_label.modulate = Color("ffd36a")
		3: demand_label.modulate = Color("ff6969")

func _connect_crafting_station() -> void:
	var station := get_tree().get_first_node_in_group("crafting_station") as StationInput
	if station != null: station.explosion_triggered.connect(_on_explosion_triggered)

func _connect_supplier() -> void:
	var supplier := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
	if supplier != null:
		supplier.delivery_status_changed.connect(_on_delivery_status_changed)
		_on_delivery_status_changed("Entregas: nenhuma pendente")

func _on_delivery_status_changed(status: String) -> void:
	delivery_label.text = status
	delivery_label.modulate = Color("ffba66") if "AGUARDANDO" in status else Color.WHITE

func _connect_inspection_manager() -> void:
	var manager := get_tree().get_first_node_in_group("inspection_manager") as InspectionManager
	if manager != null:
		manager.inspection_status_changed.connect(_on_inspection_status_changed)
		_on_inspection_status_changed("Fiscalização tranquila", false)

func _on_inspection_status_changed(status: String, urgent: bool) -> void:
	inspection_label.text = status
	inspection_label.modulate = Color("ff665e") if urgent else Color("8de5aa")
	if urgent:
		_pulse_label(inspection_label, Color("ff665e"))

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
