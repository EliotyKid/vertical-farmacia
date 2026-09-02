class_name UpgradeTerminal
extends StaticBody3D

signal upgrade_purchased(upgrade_id: StringName)

@export var shelf_scene: PackedScene
@export var press_scene: PackedScene
@export var press_product: ItemData
@export_range(0, 10000, 1) var shelf_price: int = 80
@export_range(0, 10000, 1) var press_price: int = 120
@export_range(0, 10000, 1) var express_price: int = 90
@export_range(1.0, 120.0, 1.0) var express_delivery_time: float = 12.0

@onready var menu: Control = %UpgradeMenu
@onready var feedback_label: Label = %FeedbackLabel
@onready var money_label: Label = %MoneyLabel

var purchased_upgrades: Dictionary = {}
var _active_player: PharmacyPlayer
var _wallet: Wallet

func _ready() -> void:
	add_to_group("upgrade_terminal")
	%Interactable.interacted.connect(_on_interacted)
	%ShelfButton.pressed.connect(_purchase_upgrade.bind(&"extra_shelf"))
	%PressButton.pressed.connect(_purchase_upgrade.bind(&"manual_press"))
	%ExpressButton.pressed.connect(_purchase_upgrade.bind(&"express_delivery"))
	%CloseButton.pressed.connect(close_menu)
	menu.visible = false
	_update_buttons()

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
	feedback_label.text = "Escolha como melhorar a farmácia."
	_on_money_changed(_wallet.money, 0)
	_update_buttons()
	menu.visible = true

func close_menu() -> void:
	menu.visible = false
	if _active_player != null:
		_active_player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_active_player = null
	_wallet = null

func _purchase_upgrade(upgrade_id: StringName) -> void:
	if _wallet == null or purchased_upgrades.has(upgrade_id):
		return
	var price := _get_price(upgrade_id)
	if not _wallet.try_spend(price):
		feedback_label.text = "Dinheiro insuficiente: faltam $%d." % maxi(price - _wallet.money, 0)
		return
	if not _apply_upgrade(upgrade_id):
		_wallet.add_money(price)
		feedback_label.text = "Não foi possível instalar esta melhoria."
		return
	purchased_upgrades[upgrade_id] = true
	feedback_label.text = "Melhoria instalada!"
	upgrade_purchased.emit(upgrade_id)
	_update_buttons()

func _apply_upgrade(upgrade_id: StringName) -> bool:
	match upgrade_id:
		&"extra_shelf":
			return _spawn_at_marker(shelf_scene, "upgrade_shelf_spawn")
		&"manual_press":
			var installed := _spawn_at_marker(press_scene, "upgrade_press_spawn")
			if installed and press_product != null:
				var spawner := get_tree().get_first_node_in_group("customer_spawner") as CustomerSpawner
				if spawner != null and press_product not in spawner.order_sequence:
					spawner.order_sequence.append(press_product)
			return installed
		&"express_delivery":
			var supplier := get_tree().get_first_node_in_group("supplier_terminal") as SupplierTerminal
			if supplier == null:
				return false
			supplier.delivery_time = express_delivery_time
			return true
	return false

func restore_upgrades(upgrade_ids: Array[StringName]) -> void:
	for upgrade_id: StringName in upgrade_ids:
		if purchased_upgrades.has(upgrade_id):
			continue
		if _get_price(upgrade_id) <= 0:
			continue
		if _apply_upgrade(upgrade_id):
			purchased_upgrades[upgrade_id] = true
	_update_buttons()

func get_purchased_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for upgrade_id: Variant in purchased_upgrades.keys():
		result.append(String(upgrade_id))
	result.sort()
	return result

func _spawn_at_marker(scene: PackedScene, group_name: StringName) -> bool:
	var marker := get_tree().get_first_node_in_group(group_name) as Marker3D
	if scene == null or marker == null:
		return false
	var instance := scene.instantiate() as Node3D
	marker.get_parent().add_child(instance)
	instance.global_transform = marker.global_transform
	return true

func _get_price(upgrade_id: StringName) -> int:
	match upgrade_id:
		&"extra_shelf": return shelf_price
		&"manual_press": return press_price
		&"express_delivery": return express_price
	return 0

func _update_buttons() -> void:
	%ShelfButton.text = _button_text(&"extra_shelf", "Prateleira adicional", shelf_price)
	%PressButton.text = _button_text(&"manual_press", "Prensa manual", press_price)
	%ExpressButton.text = _button_text(&"express_delivery", "Entrega expressa (12s)", express_price)
	%ShelfButton.disabled = purchased_upgrades.has(&"extra_shelf")
	%PressButton.disabled = purchased_upgrades.has(&"manual_press")
	%ExpressButton.disabled = purchased_upgrades.has(&"express_delivery")

func _button_text(upgrade_id: StringName, title: String, price: int) -> String:
	return "%s — INSTALADO" % title if purchased_upgrades.has(upgrade_id) else "%s — $%d" % [title, price]

func _on_money_changed(new_amount: int, _difference: int) -> void:
	money_label.text = "Saldo: $%d" % new_amount
