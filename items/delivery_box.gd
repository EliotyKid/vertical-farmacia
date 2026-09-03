class_name DeliveryBox
extends WorldItem

signal unpacked(content: ItemData, quantity: int)

@export var world_item_scene: PackedScene

var content_data: ItemData
var quantity: int = 0
var _has_been_carried: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("delivered_box")

func configure(content: ItemData, amount: int) -> void:
	content_data = content
	quantity = maxi(amount, 1)
	var box_data := ItemData.new()
	box_data.id = StringName("delivery_box_%s" % content.id)
	box_data.display_name = "Caixa de %s (%dx)" % [content.display_name, quantity]
	box_data.category = ItemData.Category.MISC
	box_data.placeholder_color = Color("b9824d")
	item_data = box_data

func set_carried(is_carried: bool) -> void:
	super.set_carried(is_carried)
	if is_carried:
		_has_been_carried = true

func _on_interacted(player: PharmacyPlayer) -> void:
	var carry := player.get_node_or_null("CarryController") as CarryController
	if carry == null:
		return
	if not _has_been_carried:
		carry.try_pick_up(self)
		return
	var network_state := get_node_or_null("/root/NetworkWorldState")
	if network_state != null and network_state.is_network_active():
		network_state.request_unpack(self, player)
		return
	_unpack()

func has_been_carried() -> bool:
	return _has_been_carried

func set_has_been_carried(value: bool) -> void:
	_has_been_carried = value

func authority_unpack() -> void:
	_unpack()

func get_display_name() -> String:
	if content_data == null:
		return "Caixa de entrega"
	return "Caixa de %s (%dx)" % [content_data.display_name, quantity]

func _unpack() -> void:
	if content_data == null or world_item_scene == null or quantity <= 0:
		return
	var world_parent := get_parent()
	for index: int in range(quantity):
		var item := world_item_scene.instantiate() as WorldItem
		item.item_data = content_data
		world_parent.add_child(item)
		var column := index % 3
		var row := index / 3
		item.global_position = global_position + Vector3((column - 1) * 0.55, 0.25 + row * 0.4, 0.65)
		item.mark_current_transform_safe()
	unpacked.emit(content_data, quantity)
	queue_free()
