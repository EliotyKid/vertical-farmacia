class_name PharmacyShelf
extends StaticBody3D

signal item_placed(item: WorldItem, slot_index: int)
signal item_retrieved(item: WorldItem, slot_index: int)

@export var accepts_categories: Array[ItemData.Category] = [ItemData.Category.MEDICINE, ItemData.Category.CRAFTED_PRODUCT]
@export var storage_name: String = "prateleira"
@export var network_shelf_id: StringName

@onready var status_label: Label3D = %StatusLabel

var slots: Array[ShelfSlot] = []

func _ready() -> void:
	add_to_group("storage_feedback")
	add_to_group("network_shelf")
	for child: Node in %Slots.get_children():
		var slot := child as ShelfSlot
		if slot != null:
			slot.setup(self, slots.size())
			slots.append(slot)
	_update_status()

func accepts_item(item: WorldItem) -> bool:
	return item != null and item.item_data != null and item.item_data.category in accepts_categories

func store_in_slot(slot: ShelfSlot, carry: CarryController) -> bool:
	if slot == null or slot.stored_item != null or not accepts_item(carry.current_item):
		return false
	var item := carry.place_current_item(self, slot.item_marker.global_transform)
	if item == null:
		return false
	slot.stored_item = item
	item_placed.emit(item, slot.slot_index)
	_update_status()
	return true

func retrieve_from_slot(slot: ShelfSlot, carry: CarryController) -> bool:
	if slot == null or slot.stored_item == null or carry.current_item != null:
		return false
	var item := slot.stored_item
	slot.stored_item = null
	item.set_stored(false)
	if not carry.try_pick_up(item):
		slot.stored_item = item
		item.set_stored(true)
		return false
	item_retrieved.emit(item, slot.slot_index)
	_update_status()
	return true

func count_category(category: ItemData.Category) -> int:
	var count := 0
	for slot: ShelfSlot in slots:
		if slot.stored_item != null and slot.stored_item.item_data != null and slot.stored_item.item_data.category == category:
			count += 1
	return count

func confiscate_category(category: ItemData.Category, maximum: int) -> int:
	var removed := 0
	for slot: ShelfSlot in slots:
		if removed >= maximum:
			break
		if slot.stored_item != null and slot.stored_item.item_data != null and slot.stored_item.item_data.category == category:
			slot.stored_item.queue_free()
			slot.stored_item = null
			removed += 1
	_update_status()
	return removed

func _update_status() -> void:
	var occupied := 0
	for slot: ShelfSlot in slots:
		if slot.stored_item != null:
			occupied += 1
	status_label.text = "%s\n%d / %d" % [storage_name.to_upper(), occupied, slots.size()]

func refresh_status() -> void:
	_update_status()
